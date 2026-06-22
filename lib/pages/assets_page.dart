import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import '../theme/app_theme.dart';

class AssetsPage extends StatelessWidget {
  const AssetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.primaryGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '下拉可隐藏资产，右上角更多可按账本设置不同资产',
                    style: TextStyle(fontSize: 12, color: AppTheme.darkGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Net assets
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('净资产(元)',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                const Text('0.00',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _AssetStatItem(label: '总资产', value: '0.00'),
                    _AssetStatItem(label: '负资产', value: '0.00'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account cards
          Row(
            children: [
              Expanded(
                child: _AccountCard(
                  title: '报销',
                  icon: Icons.receipt_long,
                  color: const Color(0xFF42A5F5),
                  lines: {'可报': '0.00', '已报': '0.00'},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AccountCard(
                  title: '债务',
                  icon: Icons.account_balance,
                  color: const Color(0xFFEF5350),
                  lines: {'应付': '0.00', '应收': '0.00'},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AccountCard(
                  title: '理财',
                  icon: Icons.trending_up,
                  color: const Color(0xFFFF9800),
                  lines: {'总额': '0.00', '盈亏': '0.00'},
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Empty state
          Center(
            child: Column(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('你还没有任何账户',
                    style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                const SizedBox(height: 4),
                Text('点击右下角新增按钮添加你的第一个账户',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetStatItem extends StatelessWidget {
  final String label;
  final String value;
  const _AssetStatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Map<String, String> lines;

  const _AccountCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ...lines.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${e.key} ${e.value}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
