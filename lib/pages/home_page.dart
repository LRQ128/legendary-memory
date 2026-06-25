import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/transaction.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 多选模式
  bool _isSelecting = false;
  final Set<int> _selectedIds = {};

  void _toggleSelectMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      if (!_isSelecting) _selectedIds.clear();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelecting = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final allIds = provider.transactions.map((tx) => tx.id!).toSet();
    setState(() {
      if (_selectedIds.length == allIds.length && allIds.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除选中的 ${_selectedIds.length} 条记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final provider = Provider.of<AccountingProvider>(context, listen: false);
    for (final id in _selectedIds) {
      await provider.deleteTransaction(id);
    }
    setState(() {
      _selectedIds.clear();
      _isSelecting = false;
    });
  }

  Future<void> _deleteSingle(BuildContext context, Transaction tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除「${tx.category} ${tx.type == 'income' ? '+' : '-'}${tx.amount.toStringAsFixed(2)}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Provider.of<AccountingProvider>(context, listen: false).deleteTransaction(tx.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountingProvider>(
      builder: (context, provider, _) {
        final allTxs = provider.transactions;

        // Group transactions by date descending
        final dateGroups = <String, List<Transaction>>{};
        for (final tx in allTxs) {
          final key = DateFormat('yyyy-MM-dd').format(tx.date);
          dateGroups.putIfAbsent(key, () => []);
          dateGroups[key]!.add(tx);
        }
        final sortedDates = dateGroups.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        return Scaffold(
          appBar: _isSelecting
              ? AppBar(
                  backgroundColor: const Color(0xFFE0F2F1),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSelectMode,
                  ),
                  title: Text('已选 ${_selectedIds.length} 项'),
                  actions: [
                    TextButton(
                      onPressed: _selectAll,
                      child: Text('全选',
                          style: TextStyle(color: _selectedIds.length < provider.transactions.length
                              ? const Color(0xFF009688) : Colors.grey)),
                    ),
                    if (_selectedIds.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: _deleteSelected,
                        tooltip: '删除选中',
                      ),
                  ],
                )
              : null,
          body: RefreshIndicator(
            onRefresh: () => provider.refreshAll(),
            child: ListView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
              children: [
                // Month summary card
                _buildSummaryCard(context, provider),
                const SizedBox(height: 16),
                // Quick add button
                _buildQuickAddButton(context),
                const SizedBox(height: 20),
                // Transaction list grouped by date
                if (sortedDates.isEmpty)
                  _buildEmptyState()
                else
                  ...sortedDates.map((dateStr) {
                    final txs = dateGroups[dateStr]!;
                    final isToday = dateStr == todayStr;
                    final date = DateTime.parse(dateStr);
                    final weekday = date.weekday;
                    const weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
                    final dateLabel = isToday
                        ? '今天 ${weekdayNames[weekday]}'
                        : '${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日 ${weekdayNames[weekday]}';

                    double dayIncome = 0, dayExpense = 0;
                    for (final tx in txs) {
                      if (tx.type == 'income') dayIncome += tx.amount;
                      else dayExpense += tx.amount;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Text(dateLabel,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              const Spacer(),
                              if (dayIncome > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text('收 ${dayIncome.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50))),
                                ),
                              if (dayExpense > 0)
                                Text('支 ${dayExpense.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFE53935))),
                              if (dayIncome > 0 || dayExpense > 0) const SizedBox(width: 4),
                            ],
                          ),
                        ),
                        // Transaction items
                        ...txs.map((tx) => _buildTransactionItem(context, provider, tx)),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
              ],
            ),
          ),
          // 多选模式下不显示 FAB
          floatingActionButton: _isSelecting ? null : null,
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context, AccountingProvider provider) {
    final income = provider.monthIncome;
    final expense = provider.monthExpense;
    final balance = provider.monthBalance;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('本月收入', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 2),
                        Text('¥${income.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('本月结余', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 2),
                        Text('¥${balance.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                                color: balance >= 0 ? Colors.black87 : const Color(0xFFE53935))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('本月支出', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text('¥${expense.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00897B))),
                ],
              ),
            ],
          ),
          Positioned(
            right: -10, top: -10,
            child: Opacity(opacity: 0.15,
              child: Icon(Icons.forest, size: 120, color: const Color(0xFF009688))),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/add'),
        icon: const Padding(
          padding: EdgeInsets.only(right: 4),
          child: Icon(Icons.add_box_outlined, size: 22, color: Colors.white),
        ),
        label: const Text('添加一条新记账', style: TextStyle(fontSize: 16, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF009688),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('你还没有任何记账', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            const SizedBox(height: 4),
            Text('点击上方按钮添加第一笔账单', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, AccountingProvider provider, Transaction tx) {
    final icon = AccountingProvider.categoryIcons[tx.category] ?? Icons.more_horiz;

    if (_isSelecting) {
      // 多选模式：显示 checkbox
      return Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: _selectedIds.contains(tx.id) ? const Color(0xFFE0F2F1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          dense: true,
          leading: Checkbox(
            value: _selectedIds.contains(tx.id),
            activeColor: const Color(0xFF009688),
            onChanged: (_) => _toggleSelection(tx.id!),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                child: Icon(icon, color: Colors.black54, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  if (tx.note.isNotEmpty)
                    Text(tx.note, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
          trailing: Text(
            '${tx.type == 'income' ? '+' : '-'}${tx.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: tx.type == 'income' ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
            ),
          ),
          onTap: () => _toggleSelection(tx.id!),
        ),
      );
    }

    // 普通模式：Dismissible 滑动删除 + 长按进入多选
    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        await _deleteSingle(context, tx);
        return false; // 我们已经手动删了，不让Dismissible自动移除
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          // 点击进入编辑
          Navigator.pushNamed(context, '/edit', arguments: tx);
        },
        onLongPress: () {
          setState(() {
            _isSelecting = true;
            _selectedIds.add(tx.id!);
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              child: Icon(icon, color: Colors.black54, size: 18),
            ),
            title: Row(
              children: [
                Text(tx.category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                if (tx.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(tx.note, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ),
              ],
            ),
            trailing: Text(
              '${tx.type == 'income' ? '+' : '-'}${tx.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: tx.type == 'income' ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
              ),
            ),
          ),
        ),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final amt = double.tryParse(controller.text);
              if (amt != null && amt > 0) provider.setBudget(amt);
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
