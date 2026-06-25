import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Transaction> _results = [];
  bool _searched = false;

  // 日期区间筛选
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showDateFilter = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchController.addListener(_onSearchChanged);
    });
  }

  void _onSearchChanged() {
    _performSearch();
  }

  Future<void> _performSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty && _startDate == null && _endDate == null) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final results = await provider.searchTransactionsByDateRange(
      keyword: keyword,
      startDate: _startDate,
      endDate: _endDate,
    );
    setState(() {
      _results = results;
      _searched = true;
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('zh', 'CN'),
      helpText: '选择开始日期',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
      _performSearch();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('zh', 'CN'),
      helpText: '选择结束日期',
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      _performSearch();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _performSearch();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '不限';
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '搜索分类、备注...',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
              prefixIcon: Icon(Icons.search, color: Colors.grey, size: 22),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            style: const TextStyle(fontSize: 15),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showDateFilter ? Icons.date_range : Icons.date_range_outlined,
              color: (_startDate != null || _endDate != null)
                  ? AppTheme.primaryGreen
                  : null,
            ),
            tooltip: '日期筛选',
            onPressed: () {
              setState(() => _showDateFilter = !_showDateFilter);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 日期筛选栏
          if (_showDateFilter) _buildDateFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildDateFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        border: const Border(bottom: BorderSide(color: Color(0xFFB2DFDB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range, size: 16, color: Color(0xFF00796B)),
              const SizedBox(width: 6),
              const Text('日期筛选',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF00796B))),
              const Spacer(),
              if (_startDate != null || _endDate != null)
                GestureDetector(
                  onTap: _clearDateFilter,
                  child: const Text('清除',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF00796B),
                          decoration: TextDecoration.underline)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // 开始日期
              Expanded(
                child: GestureDetector(
                  onTap: _pickStartDate,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _startDate != null
                              ? const Color(0xFF009688)
                              : Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDate(_startDate),
                            style: TextStyle(
                                fontSize: 13,
                                color: _startDate != null
                                    ? Colors.black87
                                    : Colors.grey[500])),
                        const Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('至',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ),
              // 结束日期
              Expanded(
                child: GestureDetector(
                  onTap: _pickEndDate,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _endDate != null
                              ? const Color(0xFF009688)
                              : Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDate(_endDate),
                            style: TextStyle(
                                fontSize: 13,
                                color: _endDate != null
                                    ? Colors.black87
                                    : Colors.grey[500])),
                        const Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_searched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('输入关键字搜索账单',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            const SizedBox(height: 4),
            Text('点击右侧日历图标可按日期筛选',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('没有找到匹配的账单',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            Text('试试其他关键词或调整日期范围',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    // 搜索结果数量统计
    double totalAmount = 0;
    for (final tx in _results) {
      if (tx.type == 'expense') totalAmount += tx.amount;
      else totalAmount -= tx.amount;
    }

    return Column(
      children: [
        // 统计条
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[50],
          child: Row(
            children: [
              Text('共 ${_results.length} 条',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const Spacer(),
              Text(
                '净支出 ¥${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 12,
                    color: totalAmount >= 0
                        ? const Color(0xFFE53935)
                        : const Color(0xFF4CAF50)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final tx = _results[i];
              final icon = AccountingProvider.categoryIcons[tx.category] ??
                  Icons.more_horiz;
              final color =
                  AppTheme.categoryColors[tx.category] ?? Colors.grey;
              final dateText =
                  DateFormat('MM月dd日', 'zh_CN').format(tx.date);

              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(icon, color: color, size: 18),
                ),
                title: Row(
                  children: [
                    Text(tx.category,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Text(dateText,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
                subtitle: tx.note.isNotEmpty
                    ? Text(tx.note,
                        maxLines: 1, style: const TextStyle(fontSize: 12))
                    : null,
                trailing: Text(
                  '${tx.type == 'income' ? '+' : '-'}¥${tx.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: tx.type == 'income'
                        ? AppTheme.incomeOrange
                        : AppTheme.expenseRed,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
