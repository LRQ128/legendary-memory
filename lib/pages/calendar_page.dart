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
    final txs = provider.transactions;
    _dayTransactions = {};
    for (var tx in txs) {
      final day = DateFormat('yyyy-MM-dd').format(tx.date);
      _dayTransactions.putIfAbsent(day, () => []);
      _dayTransactions[day]!.add(tx);
    }
  }

  void _showDatePickerDialog() {
    int selectedYear = _currentMonth.year;
    int selectedMonth = _currentMonth.month;
    int selectedDay = _selectedDay?.day ?? DateTime.now().day;
    int maxDay = DateTime(selectedYear, selectedMonth + 1, 0).day;
    if (selectedDay > maxDay) selectedDay = maxDay;

    final years = List.generate(11, (i) => DateTime.now().year - 5 + i);
    final months = List.generate(12, (i) => i + 1);
    final days = List.generate(31, (i) => i + 1);

    final yearController = FixedExtentScrollController(
        initialItem: years.indexOf(selectedYear));
    final monthController = FixedExtentScrollController(
        initialItem: months.indexOf(selectedMonth));
    final dayController = FixedExtentScrollController(
        initialItem: days.indexOf(selectedDay));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          int currentMaxDay =
              DateTime(selectedYear, selectedMonth + 1, 0).day;
          if (selectedDay > currentMaxDay) selectedDay = currentMaxDay;

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 8),
                    child: Text(
                      '$selectedYear年${selectedMonth.toString().padLeft(2, '0')}月${selectedDay.toString().padLeft(2, '0')}日 ${_weekdayText(DateTime(selectedYear, selectedMonth, selectedDay).weekday)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  // Wheel columns
                  SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        // Year column
                        Expanded(
                          child: _buildWheelColumn(
                            items: years,
                            label: '年',
                            controller: yearController,
                            onChanged: (i) {
                              setDialogState(() {
                                selectedYear = years[i];
                              });
                            },
                          ),
                        ),
                        // Month column
                        Expanded(
                          child: _buildWheelColumn(
                            items: months,
                            label: '月',
                            controller: monthController,
                            onChanged: (i) {
                              setDialogState(() {
                                selectedMonth = months[i];
                              });
                            },
                          ),
                        ),
                        // Day column
                        Expanded(
                          child: _buildWheelColumn(
                            items: days,
                            label: '日',
                            controller: dayController,
                            onChanged: (i) {
                              setDialogState(() {
                                selectedDay = days[i];
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Color(0xFFE0E0E0))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: const BoxDecoration(
                                border: Border(
                                    right: BorderSide(
                                        color: Color(0xFFE0E0E0))),
                              ),
                              child: const Center(
                                child: Text('取消',
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey)),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                final dt = DateTime(
                                    selectedYear, selectedMonth, selectedDay);
                                _currentMonth =
                                    DateTime(selectedYear, selectedMonth, 1);
                                _selectedDay = dt;
                                final provider =
                                    Provider.of<AccountingProvider>(context,
                                        listen: false);
                                provider.setSelectedMonth(
                                    DateFormat('yyyy-MM')
                                        .format(_currentMonth));
                                provider.setSelectedDate(dt);
                                provider.loadTransactions();
                                provider.loadCurrentDayTransactions();
                              });
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              child: const Center(
                                child: Text('确定',
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF009688),
                                        fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  String _weekdayText(int weekday) {
    const w = ['', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return w[weekday];
  }

  Widget _buildWheelColumn({
    required List<dynamic> items,
    required String label,
    required FixedExtentScrollController controller,
    required void Function(int) onChanged,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 44,
          diameterRatio: 6,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: items.length,
            builder: (ctx, index) => Center(
              child: Text(
                '${items[index]}$label',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
        // Top and bottom highlight lines
        Positioned(
          top: 78,
          left: 0,
          right: 0,
          child: Container(height: 1, color: Colors.grey[300]),
        ),
        Positioned(
          top: 120,
          left: 0,
          right: 0,
          child: Container(height: 1, color: Colors.grey[300]),
        ),
      ],
    );
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
        // Header with tappable year-month
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _showDatePickerDialog,
                    child: Row(
                      children: [
                        Text(monthStr,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const Icon(Icons.arrow_drop_down,
                            color: Colors.grey, size: 22),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentMonth =
                            DateTime(DateTime.now().year, DateTime.now().month, 1);
                        _selectedDay = DateTime.now();
                        provider.setSelectedMonth(
                            DateFormat('yyyy-MM').format(_currentMonth));
                        provider.setSelectedDate(DateTime.now());
                        provider.loadTransactions();
                        provider.loadCurrentDayTransactions();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('今',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '收 ${summary['income']?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFFF9800)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '支 ${summary['expense']?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFEF5350)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '余 ${summary['balance']?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: ['日', '一', '二', '三', '四', '五', '六']
                .map((d) => Expanded(
                      child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey))),
                    ))
                .toList(),
          ),
        ),

        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.85,
            children: [
              ...List.generate(firstWeekday, (_) => const SizedBox()),
              ...List.generate(daysInMonth, (i) {
                final day = i + 1;
                final dateStr =
                    '${DateFormat('yyyy-MM').format(_currentMonth)}-${day.toString().padLeft(2, '0')}';
                final isToday = DateTime.now().day == day &&
                    DateTime.now().month == _currentMonth.month &&
                    DateTime.now().year == _currentMonth.year;
                final isSelected = _selectedDay != null &&
                    _selectedDay!.day == day &&
                    _selectedDay!.month == _currentMonth.month;

                // Calculate day income/expense
                double dayIncome = 0, dayExpense = 0;
                final dayTxs = _dayTransactions[dateStr];
                if (dayTxs != null) {
                  for (final tx in dayTxs) {
                    if (tx.type == 'income') {
                      dayIncome += tx.amount;
                    } else {
                      dayExpense += tx.amount;
                    }
                  }
                }
                final hasTx = dayIncome > 0 || dayExpense > 0;

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
                    margin: const EdgeInsets.all(1.5),
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
                        // Day number
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isToday || isSelected ? FontWeight.bold : null,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? AppTheme.primaryGreen
                                    : Colors.black87,
                          ),
                        ),
                        // Income amount (green)
                        if (dayIncome > 0)
                          Text(
                            '¥${dayIncome.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Color(0xFF4CAF50),
                              height: 1.1,
                            ),
                          ),
                        // Expense amount (red)
                        if (dayExpense > 0)
                          Text(
                            '¥${dayExpense.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Color(0xFFE53935),
                              height: 1.1,
                            ),
                          ),
                        // Empty space if no tx
                        if (!hasTx)
                          const SizedBox(height: 14),
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
          onDismissed: (_) {
            if (tx.id != null) provider.deleteTransaction(tx.id!);
          },
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
                  ? Text(tx.note,
                      style: const TextStyle(fontSize: 12), maxLines: 1)
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
