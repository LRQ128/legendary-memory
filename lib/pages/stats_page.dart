import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/accounting_provider.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _isYearMode = false;
  bool _showIncomeChart = false;
  bool _showIncomeBar = false; // false=支出柱, true=收入柱

  DateTime _monthDate = DateTime.now();
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  void _refreshData() {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    provider.setSelectedMonth(DateFormat('yyyy-MM').format(_monthDate));
    provider.setSelectedYear(_year.toString());
    provider.loadTransactions();
    provider.loadMonthSummary();
    provider.loadCategoryExpense();
    provider.loadCategoryIncome();
    provider.loadAllYearData();
  }

  void _prevMonth() {
    setState(() {
      _monthDate = DateTime(_monthDate.year, _monthDate.month - 1);
    });
    _refreshData();
  }

  void _nextMonth() {
    setState(() {
      _monthDate = DateTime(_monthDate.year, _monthDate.month + 1);
    });
    _refreshData();
  }

  void _prevYear() {
    setState(() => _year--);
    _refreshData();
  }

  void _nextYear() {
    setState(() => _year++);
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountingProvider>(
      builder: (context, provider, _) {
        final summary = _isYearMode ? provider.yearSummary : provider.monthSummary;
        final income = summary['income'] ?? 0;
        final expense = summary['expense'] ?? 0;
        final balance = summary['balance'] ?? 0;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: RefreshIndicator(
            onRefresh: () async => _refreshData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeToggle(),
                  const SizedBox(height: 16),
                  _buildSummaryCards(income, expense, balance, provider),
                  const SizedBox(height: 20),
                  _buildBarChart(provider, expense, income),
                  const SizedBox(height: 20),
                  _buildPieChartToggle(),
                  const SizedBox(height: 12),
                  _buildPieChart(provider),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Mode Toggle ────────────────────────

  Widget _buildModeToggle() {
    return Row(
      children: [
        if (!_isYearMode) ...[
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 24),
            onPressed: _prevMonth,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _pickMonth(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                DateFormat('yyyy年MM月').format(_monthDate),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 24),
            onPressed: _nextMonth,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
        if (_isYearMode) ...[
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 24),
            onPressed: _prevYear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _pickYear(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_year}年',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 24),
            onPressed: _nextYear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() { _isYearMode = false; _refreshData(); }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: !_isYearMode ? const Color(0xFF009688) : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: Text('月',
                      style: TextStyle(fontSize: 13,
                          color: !_isYearMode ? Colors.white : Colors.grey[600])),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() { _isYearMode = true; _refreshData(); }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isYearMode ? const Color(0xFF009688) : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text('年',
                      style: TextStyle(fontSize: 13,
                          color: _isYearMode ? Colors.white : Colors.grey[600])),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Summary Cards ──────────────────────

  Widget _buildSummaryCards(double income, double expense, double balance, AccountingProvider provider) {
    return Row(
      children: [
        _buildCard('${_isYearMode ? "年" : "月"}支出', expense, const Color(0xFFEF5350)),
        const SizedBox(width: 10),
        _buildCard('${_isYearMode ? "年" : "月"}收入', income, const Color(0xFF4CAF50)),
        const SizedBox(width: 10),
        _buildCard('${_isYearMode ? "年" : "月"}结余', balance,
            balance >= 0 ? const Color(0xFF009688) : const Color(0xFFEF5350)),
      ],
    );
  }

  Widget _buildCard(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 6),
            Text('¥${amount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ─── Bar Chart ──────────────────────────

  Widget _buildBarChart(AccountingProvider provider, double expense, double income) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: _isYearMode ? _buildYearBarChart(provider, expense, income) : _buildDayBarChart(provider, expense, income),
    );
  }

  /// Month bar: daily bars, income/expense toggle separately
  Widget _buildDayBarChart(AccountingProvider provider, double expense, double income) {
    final daysInMonth = DateTime(_monthDate.year, _monthDate.month + 1, 0).day;
    final dailyExp = <int, double>{};
    final dailyInc = <int, double>{};
    for (int d = 1; d <= daysInMonth; d++) { dailyExp[d] = 0; dailyInc[d] = 0; }
    for (final tx in provider.transactions) {
      final d = tx.date.day;
      if (tx.type == 'expense') dailyExp[d] = (dailyExp[d] ?? 0) + tx.amount;
      else dailyInc[d] = (dailyInc[d] ?? 0) + tx.amount;
    }
    final maxVal = _showIncomeBar ? income : expense;
    final maxY = maxVal * 1.2 + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('收支统计',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700])),
            const Spacer(),
            // Toggle: 支出 / 收入
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showIncomeBar = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: !_showIncomeBar ? const Color(0xFFEF5350) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('支出',
                          style: TextStyle(fontSize: 11,
                              color: !_showIncomeBar ? Colors.white : Colors.grey[600])),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showIncomeBar = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _showIncomeBar ? const Color(0xFF4CAF50) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('收入',
                          style: TextStyle(fontSize: 11,
                              color: _showIncomeBar ? Colors.white : Colors.grey[600])),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIdx, rod, rodIdx) {
                    final day = group.x + 1;
                    return BarTooltipItem(
                      '${day}日\n¥${rod.toY.toStringAsFixed(2)}',
                      const TextStyle(color: Colors.white, fontSize: 10),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 36,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]))),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 20,
                      interval: 2,
                      getTitlesWidget: (v, _) {
                        final day = v.toInt() + 1;
                        if (day < 1 || day > daysInMonth || day % 2 == 0) {
                          return const SizedBox();
                        }
                        return Text('$day',
                            style: TextStyle(fontSize: 8, color: Colors.grey[400]));
                      }),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(daysInMonth, (i) {
                final day = i + 1;
                final val = _showIncomeBar ? (dailyInc[day] ?? 0) : (dailyExp[day] ?? 0);
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: val,
                    color: _showIncomeBar ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                    width: _showIncomeBar ? 6 : 5,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ],
    );
  }

  /// Year bar: monthly bars
  Widget _buildYearBarChart(AccountingProvider provider, double expense, double income) {
    final monthlyExp = provider.monthlyExpense;
    final monthlyInc = provider.monthlyIncome;
    final maxVal = [expense, income].reduce((a, b) => a > b ? a : b) * 1.2 + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('收支统计',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700])),
            const Spacer(),
            _legendDot('支出', const Color(0xFFEF5350)),
            const SizedBox(width: 12),
            _legendDot('收入', const Color(0xFF4CAF50)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIdx, rod, rodIdx) {
                    return BarTooltipItem(
                      '${group.x + 1}月\n${rodIdx == 0 ? "支出" : "收入"} ¥${rod.toY.toStringAsFixed(2)}',
                      const TextStyle(color: Colors.white, fontSize: 10),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 36,
                      getTitlesWidget: (v, _) => Text('${(v / 1000).toStringAsFixed(0)}k',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]))),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 20,
                      getTitlesWidget: (v, _) {
                        return Text('${v.toInt() + 1}月',
                            style: TextStyle(fontSize: 9, color: Colors.grey[400]));
                      }),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxVal / 4,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(12, (i) {
                final month = i + 1;
                final expAmt = monthlyExp[month] ?? 0;
                final incAmt = monthlyInc[month] ?? 0;
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: expAmt,
                    color: const Color(0xFFEF5350),
                    width: 8,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                  BarChartRodData(
                    toY: incAmt,
                    color: const Color(0xFF4CAF50),
                    width: 8,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  // ─── Pie Chart Toggle ───────────────────

  Widget _buildPieChartToggle() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _showIncomeChart = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: !_showIncomeChart ? const Color(0xFFEF5350) : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: Text('支出占比',
                      style: TextStyle(fontSize: 12,
                          color: !_showIncomeChart ? Colors.white : Colors.grey[600])),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showIncomeChart = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: _showIncomeChart ? const Color(0xFF4CAF50) : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text('收入占比',
                      style: TextStyle(fontSize: 12,
                          color: _showIncomeChart ? Colors.white : Colors.grey[600])),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Pie Chart ──────────────────────────

  Widget _buildPieChart(AccountingProvider provider) {
    final data = _isYearMode
        ? (_showIncomeChart ? provider.yearCategoryIncome : provider.yearCategoryExpense)
        : (_showIncomeChart ? provider.categoryIncome : provider.categoryExpense);

    if (data.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Center(
          child: Text('暂无${_showIncomeChart ? "收入" : "支出"}数据',
              style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ),
      );
    }

    final total = data.values.fold<double>(0, (a, b) => a + b);
    final sortedEntries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    const colors = [
      Color(0xFFEF5350), Color(0xFF42A5F5), Color(0xFFFFCA28),
      Color(0xFF66BB6A), Color(0xFFAB47BC), Color(0xFF26C6DA),
      Color(0xFF8D6E63), Color(0xFF78909C), Color(0xFFEC407A),
      Color(0xFF7E57C2), Color(0xFF26A69A), Color(0xFFFF7043),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_showIncomeChart ? "收入" : "支出"}分布',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700])),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: sortedEntries.asMap().entries.map((e) {
                      final i = e.key;
                      final entry = e.value;
                      final percentage = (entry.value / total * 100);
                      return PieChartSectionData(
                        value: entry.value,
                        title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                        color: colors[i % colors.length],
                        radius: 40,
                        titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedEntries.take(8).toList().asMap().entries.map((e) {
                    final i = e.key;
                    final entry = e.value;
                    final pct = entry.value / total * 100;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: colors[i % colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('${entry.key} ${pct.toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('¥${entry.value.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Date Pickers ───────────────────────

  /// 月统计：只选年月（无日）
  void _pickMonth() async {
    int pickedYear = _monthDate.year;
    int pickedMonth = _monthDate.month;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: const Text('选择月份', textAlign: TextAlign.center),
              content: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 年份切换
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setDlgState(() {
                            if (pickedYear > 2020) pickedYear--;
                          }),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                        const SizedBox(width: 12),
                        Text('$pickedYear年',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setDlgState(() {
                            if (pickedYear < DateTime.now().year) pickedYear++;
                          }),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 月份网格
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.5,
                      children: List.generate(12, (i) {
                        final month = i + 1;
                        final isSelected =
                            month == pickedMonth && pickedYear == _monthDate.year;
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx, DateTime(pickedYear, month));
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF009688)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text('${month}月',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  )),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _monthDate = result);
      _refreshData();
    }
  }

  /// 年统计：只选年（无月日）
  void _pickYear() async {
    int pickedYear = _year;
    final now = DateTime.now();

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: const Text('选择年份', textAlign: TextAlign.center),
              content: SizedBox(
                width: 280,
                height: 300,
                child: YearPicker(
                  firstDate: DateTime(2020),
                  lastDate: now,
                  initialDate: DateTime(pickedYear),
                  selectedDate: DateTime(pickedYear),
                  onChanged: (dt) {
                    Navigator.pop(ctx, dt.year);
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _year = result);
      _refreshData();
    }
  }
}
