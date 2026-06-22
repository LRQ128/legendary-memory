import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../theme/app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountingProvider>(
      builder: (context, provider, _) {
        return RefreshIndicator(
          onRefresh: () => provider.refreshAll(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MonthSummaryCard(provider: provider),
              const SizedBox(height: 16),
              _QuickAddButton(context: context),
              const SizedBox(height: 16),
              _RecentTransactions(provider: provider, context: context),
            ],
          ),
        );
      },
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  final AccountingProvider provider;
  const _MonthSummaryCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final budget = provider.currentBudget;
    final budgetAmount = budget?.amount ?? 0.0;
    final expense = provider.monthExpense;
    final progress = budgetAmount > 0 ? (expense / budgetAmount).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem(
                label: '本月收入',
                amount: provider.monthIncome,
                color: Colors.white70,
              ),
              Container(height: 30, width: 1, color: Colors.white24),
              _SummaryItem(
                label: '本月支出',
                amount: provider.monthExpense,
                color: Colors.white,
              ),
              Container(height: 30, width: 1, color: Colors.white24),
              _SummaryItem(
                label: '本月结余',
                amount: provider.monthBalance,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (budgetAmount > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '预算 ${budgetAmount.toStringAsFixed(0)}元  · 已用 ${expense.toStringAsFixed(0)}元',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ] else
            GestureDetector(
              onTap: () => _showBudgetDialog(context, provider),
              child: const Text(
                '剩余预算 点击设置',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, AccountingProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置预算'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '本月预算金额',
            prefixText: '¥ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final amt = double.tryParse(controller.text);
              if (amt != null && amt > 0) {
                provider.setBudget(amt);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SummaryItem(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          amount == 0 ? '0.00' : amount.toStringAsFixed(0),
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

Widget _QuickAddButton({required BuildContext context}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () => Navigator.pushNamed(context, '/add'),
      icon: const Icon(Icons.add_circle_outline),
      label: const Text('添加一条新记账', style: TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

class _RecentTransactions extends StatelessWidget {
  final AccountingProvider provider;
  final BuildContext context;
  const _RecentTransactions(
      {required this.provider, required this.context});

  @override
  Widget build(BuildContext context) {
    final txList = provider.currentDayTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MM月dd日', 'zh_CN').format(provider.selectedDate),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (txList.isEmpty) ...[
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  '你还没有任何记账',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '点击上方按钮添加第一笔账单',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          ...txList.map((tx) => _TransactionItem(tx: tx)),
        ],
      ],
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final dynamic tx;
  const _TransactionItem({required this.tx});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final icon = AccountingProvider.categoryIcons[tx.category] ?? Icons.more_horiz;
    final color = AppTheme.categoryColors[tx.category] ?? Colors.grey;

    return Dismissible(
      key: Key(tx.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) => provider.deleteTransaction(tx.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(tx.category, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: tx.note.isNotEmpty ? Text(tx.note, maxLines: 1) : null,
          trailing: Text(
            '${tx.type == 'income' ? '+' : '-'}¥${tx.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: tx.type == 'income' ? AppTheme.incomeOrange : AppTheme.expenseRed,
            ),
          ),
        ),
      ),
    );
  }
}
