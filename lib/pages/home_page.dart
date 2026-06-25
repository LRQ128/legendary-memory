import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/transaction.dart';
import '../services/sync_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await Provider.of<AccountingProvider>(context, listen: false).deleteTransaction(tx.id!);
    }
  }

  Widget _buildSyncIcon(int syncStatus) {
    if (syncStatus == 1) {
      return const Tooltip(
        message: '已同步到云端',
        child: Icon(Icons.cloud_done, size: 14, color: Color(0xFF4CAF50)),
      );
    } else {
      return const Tooltip(
        message: '未同步',
        child: Icon(Icons.cloud_off, size: 14, color: Colors.grey),
      );
    }
  }

  Widget _buildTrailing(Transaction tx) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSyncIcon(tx.syncStatus),
        const SizedBox(width: 4),
        Text(
          '${tx.type == 'income' ? '+' : '-'}${tx.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: tx.type == 'income' ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountingProvider>(
      builder: (context, provider, _) {
        final allTxs = provider.transactions;
        final dateGroups = <String, List<Transaction>>{};
        for (final tx in allTxs) {
          final key = DateFormat('yyyy-MM-dd').format(tx.date);
          dateGroups.putIfAbsent(key, () => []);
          dateGroups[key]!.add(tx);
        }
        final sortedDates = dateGroups.keys.toList()..sort((a, b) => b.compareTo(a));
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

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
                      child: Text('全选', style: TextStyle(color: _selectedIds.length < provider.transactions.length ? const Color(0xFF009688) : Colors.grey)),
                    ),
                    if (_selectedIds.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: _deleteSelected,
                      ),
                  ],
                )
              : null,
          body: allTxs.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => provider.refreshAll(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                    children: [
                      _buildMonthSummary(provider),
                      const SizedBox(height: 8),
                      _buildAddButton(),
                      const SizedBox(height: 8),
                      for (final dateKey in sortedDates) ...[
                        _buildDateHeader(dateKey, dateGroups[dateKey]!, todayStr),
                        ...dateGroups[dateKey]!.map((tx) => _buildTransactionItem(context, provider, tx)),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildMonthSummary(AccountingProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('本月支出', provider.monthExpense),
          _buildSummaryItem('本月收入', provider.monthIncome),
          _buildSummaryItem('结余', provider.monthIncome - provider.monthExpense),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount) {
    final isBalance = label == '结余';
    final Color numberColor = isBalance && amount < 0
        ? const Color(0xFFFF5252)
        : Colors.black;
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text('¥${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: numberColor)),
      ],
    );
  }

  Widget _buildDateHeader(String dateKey, List<Transaction> txs, String todayStr) {
    final date = DateTime.parse(dateKey);
    String label;
    if (dateKey == todayStr) {
      label = '今天';
    } else if (dateKey == DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)))) {
      label = '昨天';
    } else {
      label = '${date.month}月${date.day}日';
    }
    double total = 0;
    for (final tx in txs) {
      if (tx.type == 'expense') total += tx.amount; else total -= tx.amount;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4, right: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('${txs.length}笔', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const Spacer(),
          Text(total >= 0 ? '支出 ¥${total.toStringAsFixed(2)}' : '结余 ¥${(-total).toStringAsFixed(2)}',
              style: TextStyle(fontSize: 11, color: total >= 0 ? const Color(0xFFE53935) : const Color(0xFF4CAF50))),
        ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, AccountingProvider provider, Transaction tx) {
    final icon = AccountingProvider.categoryIcons[tx.category] ?? Icons.more_horiz;

    if (_isSelecting) {
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
              CircleAvatar(radius: 18, backgroundColor: Colors.grey[200], child: Icon(icon, color: Colors.black54, size: 18)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tx.category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                if (tx.note.isNotEmpty) Text(tx.note, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ],
          ),
          trailing: _buildTrailing(tx),
          onTap: () => _toggleSelection(tx.id!),
        ),
      );
    }

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        await _deleteSingle(context, tx);
        return false;
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.pushNamed(context, '/edit', arguments: tx),
        onLongPress: () => setState(() { _isSelecting = true; _selectedIds.add(tx.id!); }),
        child: Container(
          margin: const EdgeInsets.only(bottom: 1),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(radius: 18, backgroundColor: Colors.grey[200], child: Icon(icon, color: Colors.black54, size: 18)),
            title: Row(children: [
              Text(tx.category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              if (tx.note.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 6), child: Text(tx.note, style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
            ]),
            trailing: _buildTrailing(tx),
          ),
        ),
      ),
    );
  }

  /// 添加一笔新记账按钮
  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/add'),
        icon: const Icon(Icons.add_circle_outline, size: 20),
        label: const Text('添加一笔新记账', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF009688),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }
}
