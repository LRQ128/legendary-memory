import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 登录状态
enum AuthStatus { uninitialized, unauthenticated, authenticated, loading }

/// Supabase 认证服务 - 直接调用 REST API，无需原生插件
class AuthService extends ChangeNotifier {
  final String _supabaseUrl;
  final String _anonKey;

  AuthStatus _status = AuthStatus.uninitialized;
  Map<String, dynamic>? _user;
  String? _accessToken;
  String? _refreshToken;
  String? _error;
  Timer? _refreshTimer;

  static const _tokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _userKey = 'auth_user_json';
  static const _emailKey = 'auth_email';

  AuthService(this._supabaseUrl, this._anonKey) {
    _init();
  }

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;
  String? get userId => _user?['id'];
  String? get email => _user?['email'];
  String? get accessToken => _accessToken;
  bool get isLoggedIn => _status == AuthStatus.authenticated;

  Map<String, String> get _headers => {
        'apikey': _anonKey,
        'Content-Type': 'application/json',
      };

  Map<String, String> get _authHeaders => {
        'apikey': _anonKey,
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  /// 初始化：尝试从本地恢复登录状态
  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);
      final savedUserJson = prefs.getString(_userKey);
      final savedRefreshToken = prefs.getString(_refreshTokenKey);

      if (savedToken != null && savedUserJson != null) {
        _accessToken = savedToken;
        _refreshToken = savedRefreshToken;
        _user = jsonDecode(savedUserJson);

        // 尝试验证 token 是否仍然有效
        final valid = await _validateToken();
        if (valid) {
          _status = AuthStatus.authenticated;
          // 启动定时刷新（access_token 通常 1h 过期，提前刷新）
          _scheduleTokenRefresh();
          notifyListeners();
          return;
        }

        // Token 失效，尝试用 refresh_token 续期
        if (_refreshToken != null) {
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            _status = AuthStatus.authenticated;
            _scheduleTokenRefresh();
            notifyListeners();
            return;
          }
        }

        // 都失败了，清除
        await _clearSavedSession(prefs);
      }
    } catch (_) {
      // 静默失败，走未登录流程
    }

    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// 验证当前 token 是否有效
  Future<bool> _validateToken() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_supabaseUrl/auth/v1/user'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 用 refresh_token 续期
  Future<bool> _refreshAccessToken() async {
    try {
      final response = await http
          .post(
            Uri.parse('$_supabaseUrl/auth/v1/token?grant_type=refresh_token'),
            headers: _headers,
            body: jsonEncode({'refresh_token': _refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _accessToken!);
        await prefs.setString(_refreshTokenKey, _refreshToken ?? '');
        await prefs.setString(_userKey, jsonEncode(_user));
        await prefs.setString(_emailKey, _user?['email'] ?? '');

        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 定时刷新 token
  void _scheduleTokenRefresh() {
    _refreshTimer?.cancel();
    // access_token 默认 3600 秒过期，我们每 30 分钟刷新一次
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      if (_refreshToken != null) {
        await _refreshAccessToken();
      }
    });
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString(_tokenKey, _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString(_refreshTokenKey, _refreshToken ?? '');
    }
    if (_user != null) {
      await prefs.setString(_userKey, jsonEncode(_user));
      await prefs.setString(_emailKey, _user?['email'] ?? '');
    }
  }

  Future<void> _clearSavedSession([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_refreshTokenKey);
    await p.remove(_userKey);
    await p.remove(_emailKey);
    _accessToken = null;
    _refreshToken = null;
    _user = null;
  }

  /// 邮箱+密码登录
  Future<bool> loginWithEmail(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      final response = await http
          .post(
            Uri.parse('$_supabaseUrl/auth/v1/token?grant_type=password'),
            headers: _headers,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = data['user'];
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _status = AuthStatus.authenticated;
        await _saveSession();
        _scheduleTokenRefresh();
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = _parseAuthError(
            data['error_description'] ?? data['error'] ?? '登录失败');
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } on TimeoutException {
      _status = AuthStatus.unauthenticated;
      _error = '连接超时，请检查网络';
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _error = '网络连接失败，请检查网络';
      notifyListeners();
      return false;
    }
  }

  /// 邮箱注册
  Future<bool> registerWithEmail(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      final response = await http
          .post(
            Uri.parse('$_supabaseUrl/auth/v1/signup'),
            headers: _headers,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = data['user'];
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _status = AuthStatus.authenticated;
        await _saveSession();
        _scheduleTokenRefresh();
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = _parseAuthError(
            data['error_description'] ?? data['error'] ?? '注册失败');
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } on TimeoutException {
      _status = AuthStatus.unauthenticated;
      _error = '连接超时，请检查网络';
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _error = '网络连接失败，请检查网络';
      notifyListeners();
      return false;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    _refreshTimer?.cancel();
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _status = AuthStatus.unauthenticated;
    await _clearSavedSession();
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _parseAuthError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('already registered') || m.contains('already exists')) {
      return '该邮箱已注册，请直接登录';
    }
    if (m.contains('invalid email') || m.contains('email not confirmed')) {
      return '邮箱格式不正确或未验证';
    }
    if (m.contains('invalid password') || m.contains('wrong password')) {
      return '密码错误';
    }
    if (m.contains('weak password')) {
      return '密码太简单（至少6位）';
    }
    if (m.contains('invalid login credentials')) {
      return '邮箱或密码错误';
    }
    return msg.isNotEmpty ? msg : '操作失败，请重试';
  }
}
