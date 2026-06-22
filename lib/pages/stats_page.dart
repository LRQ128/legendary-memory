import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/accounting_provider.dart';
import '../theme/app_theme.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  String _period = '月统计';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context);
    final summary = provider.monthSummary;
    final categories = provider.categoryExpense;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period tabs
          Row(
            children: ['日常', '月统计', '年统计', '自定义']
                .map((p) => Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _period = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _period == p
                                ? AppTheme.primaryGreen
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(p,
                                style: TextStyle(
                                  color: _period == p ? Colors.white : Colors.black87,
                                  fontWeight: _period == p
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                )),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          // Month selector
          Row(
            children: _buildMonthSelector(provider),
          ),
          const SizedBox(height: 16),

          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                    label: '总支出',
                    value: summary['expense'] ?? 0.0,
                    color: Colors.white),
                _StatItem(
                    label: '总收入',
                    value: summary['income'] ?? 0.0,
                    color: Colors.white70),
                _StatItem(
                    label: '月结余',
                    value: summary['balance'] ?? 0.0,
                    color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Income/Expense chart
          const Text('收支统计',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _buildDailyChart(provider),
          ),
          const SizedBox(height: 20),

          // Pie chart
          Row(
            children: [
              const Text('支出占比',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text('大类/全部', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pie_chart_outline,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('暂无支出数据',
                            style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sections: _buildPieSections(categories),
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: categories.entries.take(5).map((e) {
                            final color =
                                AppTheme.categoryColors[e.key] ?? Colors.grey;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${e.key} ${e.value.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Options
          Row(
            children: [
              FilterChip(
                label: const Text('显示收支金额', style: TextStyle(fontSize: 12)),
                selected: false,
                onSelected: (_) {},
              ),
              const SizedBox(width: 8),
              FilterChip(
                label:
                    const Text('过滤占比小于1%的分类', style: TextStyle(fontSize: 12)),
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMonthSelector(AccountingProvider provider) {
    final now = DateTime.now();
    final months = [
      DateFormat('yyyy年M月').format(now),
      DateFormat('M月').format(now.subtract(const Duration(days: 30))),
      DateFormat('M月').format(now.subtract(const Duration(days: 60))),
      DateFormat('M月').format(now.subtract(const Duration(days: 90))),
    ];
    return months.map((m) {
      final selected = DateFormat('yyyy年M月').format(DateTime.now()) == m ||
          (provider.selectedMonth.endsWith(m.replaceAll('年', '-')));
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(m, style: const TextStyle(fontSize: 12)),
          selected: selected,
          onSelected: (_) {},
          selectedColor: AppTheme.lightGreen,
        ),
      );
    }).toList();
  }

  Widget _buildDailyChart(AccountingProvider provider) {
    final txs = provider.transactions;
    if (txs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('暂无数据', style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }
    // Aggregate by day
    Map<int, double> dailyExpense = {};
    Map<int, double> dailyIncome = {};
    for (var tx in txs) {
      final day = tx.date.day;
      if (tx.type == 'expense') {
        dailyExpense[day] = (dailyExpense[day] ?? 0) + tx.amount;
      } else {
        dailyIncome[day] = (dailyIncome[day] ?? 0) + tx.amount;
      }
    }
    final daysInMonth = DateTime(
            DateTime.now().year, DateTime.now().month + 1, 0)
        .day;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey[200]!,
            strokeWidth: 1,
          ),
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 5,
              getTitlesWidget: (v, _) {
                return Text('${v.toInt()}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey));
              },
            ),
          ),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(daysInMonth, (i) {
              final day = i + 1;
              return FlSpot(day.toDouble(), dailyExpense[day] ?? 0);
            }),
            color: AppTheme.expenseRed,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.expenseRed.withOpacity(0.08),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, double> data) {
    final total = data.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return [];
    return data.entries.map((e) {
      final pct = (e.value / total * 100).toStringAsFixed(0);
      final color = AppTheme.categoryColors[e.key] ?? Colors.grey;
      return PieChartSectionData(
        value: e.value,
        color: color,
        radius: 35,
        title: '$pct%',
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(0),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
