import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'import_export_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final count = Provider.of<AccountingProvider>(context).totalTransactionCount;
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // User info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.primaryGreen,
                  child: const Text('L&W',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Text(
                  auth.email ?? '未登录',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('已记录 $count 条账单',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sync status
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    sync.status == SyncStatus.syncing
                        ? Icons.sync
                        : sync.lastSyncTime != null
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                    color: sync.status == SyncStatus.syncing
                        ? Colors.orange
                        : sync.lastSyncTime != null
                            ? AppTheme.primaryGreen
                            : Colors.grey,
                  ),
                  title: Text(
                    sync.status == SyncStatus.syncing
                        ? '同步中...'
                        : sync.lastSyncTime != null
                            ? '已同步'
                            : '未同步',
                  ),
                  subtitle: sync.lastSyncTime != null
                      ? Text(
                          '上次同步: ${sync.lastSyncTime!.substring(0, 19).replaceAll('T', ' ')}',
                          style: const TextStyle(fontSize: 12))
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Data management
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync, color: Colors.blue),
                  title: const Text('手动同步'),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () async {
                    final svc = context.read<SyncService>();
                    await svc.incrementalSync();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(svc.lastSyncTime != null
                              ? '同步成功'
                              : '同步失败'),
                          backgroundColor: svc.lastSyncTime != null
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.import_export, color: Colors.grey),
                  title: const Text('导入导出'),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ImportExportPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.grey),
                  title: const Text('账号管理'),
                  trailing: Text(
                    auth.email ?? '未登录',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('退出登录',
                      style: TextStyle(color: Colors.red)),
                  onTap: () => _showLogoutDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text(
            '退出后本地数据仍然保留，下次登录会自动同步。确定退出？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final sync = context.read<SyncService>();
              sync.stopAutoSync();
              sync.clearAuth();
              final auth = context.read<AuthService>();
              await auth.logout();
            },
            child:
                const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
