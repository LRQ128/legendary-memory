import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _currentMonth;
  DateTime? _selectedDay;
  Map<String, List<Transaction>> _dayTransactions = {};

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _loadData() {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final month = DateFormat('yyyy-MM').format(_currentMonth);
    final txs = provider.transactions;
    _dayTransactions = {};
    for (var tx in txs) {
      final day = DateFormat('yyyy-MM-dd').format(tx.date);
      _dayTransactions.putIfAbsent(day, () => []);
      _dayTransactions[day]!.add(tx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context);
    _loadData();

    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;
    final monthStr = DateFormat('yyyy年MM月').format(_currentMonth);
    final summary = provider.monthSummary;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _currentMonth =
                      DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                  provider.setSelectedMonth(
                      DateFormat('yyyy-MM').format(_currentMonth));
                  provider.loadTransactions();
                }),
              ),
              Text(monthStr,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final next =
                      DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                  if (next.isBefore(DateTime.now().add(const Duration(days: 90)))) {
                    setState(() {
                      _currentMonth = next;
                      provider.setSelectedMonth(
                          DateFormat('yyyy-MM').format(_currentMonth));
                      provider.loadTransactions();
                    });
                  }
                },
              ),
              const Spacer(),
              Text(
                '收 ${summary['income']?.toStringAsFixed(0) ?? '0'}  支 ${summary['expense']?.toStringAsFixed(0) ?? '0'}  余 ${summary['balance']?.toStringAsFixed(0) ?? '0'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['日', '一', '二', '三', '四', '五', '六']
                .map((d) => Expanded(
                      child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey))),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),

        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1,
            children: [
              ...List.generate(firstWeekday, (_) => const SizedBox()),
              ...List.generate(daysInMonth, (i) {
                final day = i + 1;
                final dateStr =
                    '${DateFormat('yyyy-MM').format(_currentMonth)}-${day.toString().padLeft(2, '0')}';
                final hasTx = _dayTransactions.containsKey(dateStr);
                final isToday = DateTime.now().day == day &&
                    DateTime.now().month == _currentMonth.month &&
                    DateTime.now().year == _currentMonth.year;
                final isSelected = _selectedDay != null &&
                    _selectedDay!.day == day &&
                    _selectedDay!.month == _currentMonth.month;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = DateTime(
                          _currentMonth.year, _currentMonth.month, day);
                    });
                    provider.setSelectedDate(_selectedDay!);
                    provider.loadCurrentDayTransactions();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : isToday
                              ? AppTheme.lightGreen
                              : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isToday || isSelected ? FontWeight.bold : null,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? AppTheme.primaryGreen
                                    : Colors.black87,
                          ),
                        ),
                        if (hasTx)
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Selected day transactions
        if (_selectedDay != null) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  DateFormat('MM月dd日', 'zh_CN').format(_selectedDay!),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/add', arguments: {
                      'date': _selectedDay,
                    });
                  },
                  child: const Icon(Icons.add_circle_outline,
                      size: 20, color: AppTheme.primaryGreen),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedDayTransactions(context),
          ),
        ] else
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('选择日期查看账单',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _selectedDayTransactions(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final txs = provider.currentDayTransactions;
    if (txs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('这一天还没有任何记账',
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: txs.length,
      itemBuilder: (ctx, i) {
        final tx = txs[i];
        final icon =
            AccountingProvider.categoryIcons[tx.category] ?? Icons.more_horiz;
        final color =
            AppTheme.categoryColors[tx.category] ?? Colors.grey;
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
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                radius: 18,
                child: Icon(icon, color: color, size: 18),
              ),
              title: Text(tx.category, style: const TextStyle(fontSize: 14)),
              subtitle: tx.note.isNotEmpty
                  ? Text(tx.note, style: const TextStyle(fontSize: 12), maxLines: 1)
                  : null,
              trailing: Text(
                '${tx.type == 'income' ? '+' : '-'}¥${tx.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: tx.type == 'income'
                      ? AppTheme.incomeOrange
                      : AppTheme.expenseRed,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
