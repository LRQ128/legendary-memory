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

  // ═══════════════════════════════════════════════════
  // 分类同步
  // ═══════════════════════════════════════════════════

  Future<void> _syncCategoryDeletionsToCloud() async {
    final pending = await _db.getPendingDeleteCategoryRemoteIds();
    for (final remoteId in pending) {
      try {
        final response = await http
            .delete(
              Uri.parse(
                  '$_supabaseUrl/rest/v1/categories?id=eq.$remoteId'),
              headers: {
                'apikey': _anonKey,
                if (_accessToken != null)
                  'Authorization': 'Bearer $_accessToken',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 || response.statusCode == 204) {
          await _db.removeDeletedCategoryRemoteId(remoteId);
        }
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCloudCategories() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_supabaseUrl/rest/v1/categories'
                '?user_id=eq.$_userId&order=id.asc'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (_) {}
    return [];
  }

  Future<bool> _uploadCategory(Map<String, dynamic> cat) async {
    try {
      // 只发送云端表存在的字段
      final json = <String, dynamic>{
        'user_id': _userId!,
        'name': cat['name'],
        'icon': cat['icon'] ?? 'more_horiz',
        'type': cat['type'],
        'sort_order': cat['sortOrder'] ?? 0,
      };
      final response = await http
          .post(
            Uri.parse('$_supabaseUrl/rest/v1/categories'),
            headers: _headers,
            body: jsonEncode(json),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 201) {
        final List result = jsonDecode(response.body);
        if (result.isNotEmpty) {
          final remoteId = result[0]['id'] as String;
          await _db.updateCategoryRemoteId(cat['id'] as int, remoteId);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 同步分类：首次全量 + 增量的入口
  /// 独立 try-catch，不影响账单同步
  Future<void> _syncCategories() async {
    try {
      await _syncCategoryDeletionsToCloud();

      final deletedRemoteIds = await _db.getDeletedCategoryRemoteIds();
      final existingRemoteIds = await _db.getSyncedCategoryRemoteIds();

      final unsynced = await _db.getUnsyncedCategories();
      for (final cat in unsynced) {
        final ok = await _uploadCategory(cat);
        if (!ok) {
          debugPrint('[_syncCategories] upload failed: ${cat['name']} (${cat['type']})');
        }
      }

      final currentRemoteIds = await _db.getSyncedCategoryRemoteIds();

      final cloudCats = await _fetchCloudCategories();
      for (final cat in cloudCats) {
        final remoteId = cat['id'] as String?;
        if (remoteId == null || remoteId.isEmpty) continue;
        if (deletedRemoteIds.contains(remoteId)) continue;
        if (currentRemoteIds.contains(remoteId)) continue;
        await _db.insertCategoryFromCloud(cat);
      }
    } catch (e, stack) {
      debugPrint('[_syncCategories] error: $e\n$stack');
      // 不往外抛，不影响账单同步
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

      // 5. 下载云端数据（跳过已删和本地已有的，防止重复）
      // 注：upload后本地已有remoteId已更新，但cloudTxs是在upload前拉的，所以需额外用existingRemoteIds去重
      for (final tx in cloudTxs) {
        if (tx.remoteId == null) continue;
        if (deletedRemoteIds.contains(tx.remoteId)) continue;
        if (existingRemoteIds.contains(tx.remoteId)) continue;
        await _db.insertTransactionOrIgnore(tx);
      }

      // 6. 同步分类
      await _syncCategories();

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

      // 4. 上传完成后重新获取远程ID列表（刚上传的记录已拿到 remoteId）
      final currentRemoteIds = await _db.getSyncedRemoteIds();

      // 5. 下载云端数据（跳过已删和本地已有的）
      final cloudTxs = await _fetchCloudTransactions();
      for (final tx in cloudTxs) {
        if (tx.remoteId == null) continue;
        if (deletedRemoteIds.contains(tx.remoteId)) continue;
        if (currentRemoteIds.contains(tx.remoteId)) continue;
        await _db.insertTransactionOrIgnore(tx);
      }

      // 6. 同步分类
      await _syncCategories();

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
