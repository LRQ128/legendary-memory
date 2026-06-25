import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/database.dart';
import '../models/transaction.dart';

/// 同步状态
enum SyncStatus { idle, syncing, error }

/// 数据同步服务 - 通过 Supabase REST API 同步数据
class SyncService extends ChangeNotifier {
  final String _supabaseUrl;
  final String _anonKey;
  final DatabaseHelper _db = DatabaseHelper();

  SyncStatus _status = SyncStatus.idle;
  String? _lastSyncTime;
  String? _error;
  Timer? _pollTimer;
  String? _accessToken;
  String? _userId;
  bool _initialSyncDone = false;

  SyncService(this._supabaseUrl, this._anonKey);

  SyncStatus get status => _status;
  String? get lastSyncTime => _lastSyncTime;
  String? get error => _error;

  /// 设置认证信息
  void setAuth(String userId, String token) {
    _userId = userId;
    _accessToken = token;
  }

  /// 清除认证
  void clearAuth() {
    _userId = null;
    _accessToken = null;
    _initialSyncDone = false;
    stopAutoSync();
  }

  Map<String, String> get _headers => {
        'apikey': _anonKey,
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  /// 启动后台轮询（每30秒检查一次）
  void startAutoSync() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_userId != null) {
        incrementalSync();
      }
    });
  }

  void stopAutoSync() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// 推送本地已删除的记录到云端
  Future<void> _syncDeletionsToCloud() async {
    final pendingDeletes = await _db.getPendingDeleteRemoteIds();
    if (pendingDeletes.isEmpty) return;

    for (final remoteId in pendingDeletes) {
      try {
        final response = await http
            .delete(
              Uri.parse(
                  '$_supabaseUrl/rest/v1/transactions?id=eq.$remoteId'),
              headers: {
                'apikey': _anonKey,
                if (_accessToken != null)
                  'Authorization': 'Bearer $_accessToken',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 || response.statusCode == 204) {
          await _db.removeDeletedRemoteId(remoteId);
        }
      } catch (_) {}
    }
  }

  /// 首次登录：全量合并（仅执行一次，防重入）
  Future<bool> initialSync() async {
    if (_userId == null) return false;
    if (_initialSyncDone) return true;
    _initialSyncDone = true;

    try {
      _status = SyncStatus.syncing;
      _error = null;
      notifyListeners();

      // 1. 推送本地已删
      await _syncDeletionsToCloud();

      // 2. 获取已删 remoteId + 本地已有的 remoteId
      final deletedRemoteIds = await _db.getDeletedRemoteIds();
      final existingRemoteIds = await _db.getSyncedRemoteIds();

      // 3. 拉取云端数据
      final cloudTxs = await _fetchCloudTransactions();

      // 4. 上传本地新增/修改
      final localTxs = await _db.getAllTransactionsWithoutLimit();
      final cloudByRemoteId = <String, Transaction>{};
      for (final tx in cloudTxs) {
        if (tx.remoteId != null) cloudByRemoteId[tx.remoteId!] = tx;
      }

      for (final tx in localTxs) {
        if (tx.remoteId == null || tx.remoteId!.isEmpty) {
          await _uploadTransaction(tx);
        } else if (cloudByRemoteId.containsKey(tx.remoteId!)) {
          final cloud = cloudByRemoteId[tx.remoteId!]!;
          if (tx.updatedAt.isAfter(cloud.updatedAt)) {
            await _updateCloudTransaction(tx);
          }
        }
      }

      // 5. 下载云端数据（跳过已删，更新或插入）
      for (final tx in cloudTxs) {
        if (tx.remoteId == null) continue;
        if (deletedRemoteIds.contains(tx.remoteId)) continue;
        await _db.insertTransactionOrIgnore(tx);
      }

      _lastSyncTime = DateTime.now().toIso8601String();
      _status = SyncStatus.idle;
      notifyListeners();
      return true;
    } catch (e) {
      _initialSyncDone = false; // 失败允许重试
      _status = SyncStatus.error;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 增量同步
  Future<bool> incrementalSync() async {
    if (_userId == null) return false;
    try {
      _status = SyncStatus.syncing;
      notifyListeners();

      // 1. 推送本地已删
      await _syncDeletionsToCloud();

      // 2. 获取已删 remoteId + 本地已有的 remoteId
      final deletedRemoteIds = await _db.getDeletedRemoteIds();
      final existingRemoteIds = await _db.getSyncedRemoteIds();

      // 3. 上传本地新增
      final unsyncedTxs = await _db.getUnsyncedTransactions();
      for (final tx in unsyncedTxs) {
        if (tx.remoteId == null || tx.remoteId!.isEmpty) {
          await _uploadTransaction(tx);
        } else {
          await _updateCloudTransaction(tx);
        }
      }

      // 4. 上传完成后重新获取本地已有的 remoteId（刚才上传的已拿到 remoteId）
      final updatedRemoteIds = await _db.getSyncedRemoteIds();

      // 5. 下载云端数据（跳过已删和已有的）
      // 上传后重新查 remoteId，确保刚上传的数据也能跳过
      final currentRemoteIds = await _db.getSyncedRemoteIds();
      final cloudTxs = await _fetchCloudTransactions();
      for (final tx in cloudTxs) {
        if (tx.remoteId == null) continue;
        if (deletedRemoteIds.contains(tx.remoteId)) continue;
        if (currentRemoteIds.contains(tx.remoteId)) continue;
        // 用安全方式插入，即使 remoteId 已存在也不会报错或重复
        await _db.insertTransactionOrIgnore(tx);
      }

      _lastSyncTime = DateTime.now().toIso8601String();
      _status = SyncStatus.idle;
      notifyListeners();
      return true;
    } catch (e) {
      _status = SyncStatus.error;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── 内部方法 ──

  Future<List<Transaction>> _fetchCloudTransactions() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_supabaseUrl/rest/v1/transactions'
                '?user_id=eq.$_userId&order=updated_at.desc'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((json) => Transaction.fromRemoteJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> _uploadTransaction(Transaction tx) async {
    try {
      final json = tx.toRemoteJson(_userId!);
      json.remove('id');
      final response = await http
          .post(
            Uri.parse('$_supabaseUrl/rest/v1/transactions'),
            headers: _headers,
            body: jsonEncode(json),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 201) {
        final List result = jsonDecode(response.body);
        if (result.isNotEmpty) {
          final remoteId = result[0]['id'] as String;
          await _db.updateRemoteId(tx.id!, remoteId, 1);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _updateCloudTransaction(Transaction tx) async {
    try {
      final json = tx.toRemoteJson(_userId!);
      json.remove('id');
      json.remove('user_id');
      final response = await http
          .patch(
            Uri.parse(
                '$_supabaseUrl/rest/v1/transactions?id=eq.${tx.remoteId}'),
            headers: _headers,
            body: jsonEncode(json),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 204) {
        await _db.markSynced(tx.id!, 1);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
