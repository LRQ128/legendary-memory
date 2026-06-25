import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/transaction.dart';

/// Import transactions from Excel (.xlsx/.csv) files.
/// Supports:
/// - Standard format: 类型,分类,金额,备注,日期
/// - Auto-detection of Alipay/WeChat export formats
class ExcelImportPage extends StatefulWidget {
  const ExcelImportPage({super.key});

  @override
  State<ExcelImportPage> createState() => _ExcelImportPageState();
}

class _ExcelImportPageState extends State<ExcelImportPage> {
  bool _loading = false;
  String? _error;
  String? _fileName;
  List<ParsedTransaction> _parsed = [];
  Set<int> _selectedIndexes = {};
  bool _showSuccess = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Excel账单导入'),
        actions: [
          if (_parsed.isNotEmpty)
            TextButton(
              onPressed: _selectedIndexes.isNotEmpty ? _importSelected : null,
              child: const Text('导入选中',
                  style: TextStyle(
                      color: Color(0xFF009688),
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_showSuccess) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Color(0xFF4CAF50)),
            const SizedBox(height: 16),
            Text('已成功导入 ${_selectedIndexes.length} 条账单',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('文件名: $_fileName',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('返回', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // File selection area
        if (_parsed.isEmpty && !_loading && _error == null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.table_chart_outlined,
                        size: 80, color: Color(0xFF009688)),
                    const SizedBox(height: 20),
                    const Text('选择Excel文件导入账单',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      '支持 .xlsx 格式\n\n'
                      '文件格式要求：\n'
                      '类型,分类,金额,备注,日期\n'
                      'expense,餐饮,25.00,午餐,2026-06-22\n'
                      'income,工资,8000.00,6月工资,2026-06-15',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    // Pick file button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('选择Excel文件',
                            style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009688),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Loading
        if (_loading)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在解析文件...'),
                ],
              ),
            ),
          ),

        // Error
        if (_error != null && _parsed.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 15)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新选择'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Parsed results
        if (_parsed.isNotEmpty && !_loading)
          Expanded(
            child: _buildResultsList(),
          ),

        // Bottom bar
        if (_parsed.isNotEmpty && !_loading)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickFile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[400]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('重新选择'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedIndexes.isNotEmpty
                          ? _importSelected
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                          '导入 ${_selectedIndexes.length} 条',
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultsList() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFFE0F2F1),
          child: Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: Color(0xFF009688)),
              const SizedBox(width: 8),
              Text(
                '解析到 ${_parsed.length} 条记录，点击取消勾选',
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF00796B)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  final all = <int>{for (int i = 0; i < _parsed.length; i++) i};
                  setState(() {
                    _selectedIndexes =
                        _selectedIndexes.length == _parsed.length
                            ? <int>{}
                            : all;
                  });
                },
                child: Text(
                  _selectedIndexes.length == _parsed.length
                      ? '取消全选'
                      : '全选',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF009688),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _parsed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) {
              final tx = _parsed[i];
              final selected = _selectedIndexes.contains(i);
              final dateStr = DateFormat('MM月dd日').format(tx.date);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedIndexes.remove(i);
                  } else {
                    _selectedIndexes.add(i);
                  }
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF009688)
                          : Colors.grey[200]!,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? const Color(0xFF009688)
                          : Colors.grey[400],
                      size: 22,
                    ),
                    title: Text(tx.category,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Row(
                      children: [
                        if (tx.note.isNotEmpty) ...[
                          Flexible(
                            child: Text(tx.note,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(dateStr,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                    trailing: Text(
                      '${tx.type == 'income' ? '+' : '-'}¥${tx.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: tx.type == 'income'
                            ? const Color(0xFFFF9800)
                            : const Color(0xFFE53935),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _error = null;
      _parsed = [];
      _selectedIndexes = {};
    });

    try {
      // Open file picker for Excel files
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      final filePath = file.path;
      if (filePath == null) {
        if (mounted) setState(() {
          _loading = false;
          _error = '无法读取文件路径';
        });
        return;
      }

      _fileName = file.name;
      final bytes = await File(filePath).readAsBytes();
      final transactions = _parseExcel(bytes);

      if (mounted) {
        setState(() {
          _parsed = transactions;
          _selectedIndexes =
              Set.from(List.generate(transactions.length, (i) => i));
          _loading = false;
        });
        if (transactions.isEmpty) {
          setState(() => _error = '文件中未找到有效的账单数据');
        }
      }
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = '读取文件失败: $e';
      });
    }
  }

  List<ParsedTransaction> _parseExcel(Uint8List bytes) {
    final results = <ParsedTransaction>[];

    // Try parsing as CSV first
    try {
      final text = String.fromCharCodes(bytes);
      if (text.contains('\n') && (text.contains(',') || text.contains('\t'))) {
        final csvResult = _parseCSV(text);
        if (csvResult.length >= 5) return csvResult; // Return if enough results
        // If too few, still continue to try Excel parse
      }
    } catch (_) {
      // Not CSV, try Excel
    }

    // Parse as Excel .xlsx
    try {
      final excel = Excel.decodeBytes(bytes);
      for (final sheet in excel.sheets.values) {
        final rows = sheet.rows;
        if (rows.length < 2) continue; // Header only or empty

        // Try to find header row - look for 类型/类型/type, 分类/category etc.
        int headerRow = 0;
        Map<String, int> colMap = {};

        // First, scan first few rows to find headers
        for (int r = 0; r < rows.length && r < 5; r++) {
          final row = rows[r];
          final texts = row
              .map((cell) => (cell?.value?.toString() ?? '').trim().toLowerCase())
              .toList();
          if (texts.any((t) =>
              t.contains('类型') || t.contains('分类') ||
              t.contains('金额') || t.contains('type'))) {
            headerRow = r;
            for (int c = 0; c < texts.length; c++) {
              final t = texts[c];
              if (t.contains('类型') || t.contains('type')) colMap['type'] = c;
              else if (t.contains('分类') || t.contains('category')) colMap['category'] = c;
              else if (t.contains('金额') || t.contains('amount')) colMap['amount'] = c;
              else if (t.contains('备注') || t.contains('note')) colMap['note'] = c;
              else if (t.contains('日期') || t.contains('date')) colMap['date'] = c;
            }
            break;
          }
        }

        // Parse data rows
        for (int r = headerRow + 1; r < rows.length; r++) {
          final row = rows[r];
          if (row.isEmpty) continue;
          final texts = row
              .map((cell) => (cell?.value?.toString() ?? '').trim())
              .toList();
          if (texts.isEmpty) continue;

          try {
            final parsed = _parseRow(texts, colMap);
            if (parsed != null) results.add(parsed);
          } catch (_) {
            // Skip invalid rows
          }
        }
      }
    } catch (e) {
      // If Excel parsing fails and we have no results, throw
      if (results.isEmpty) {
        // Try one more time with raw CSV
        try {
          final text = String.fromCharCodes(bytes);
          final csvResult = _parseCSV(text);
          if (csvResult.isNotEmpty) return csvResult;
        } catch (_) {}
        throw Exception('无法解析文件: $e\n\n请确保文件为有效的 .xlsx 或 .csv 格式');
      }
    }

    return results;
  }

  /// Parse CSV text
  List<ParsedTransaction> _parseCSV(String text) {
    final results = <ParsedTransaction>[];
    final lines = text.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length < 2) return results;

    // Detect separator: comma or tab
    final firstLine = lines[0];
    final sep = firstLine.contains('\t') ? '\t' : ',';

    // Parse header
    final headers = firstLine.split(sep).map((h) => h.trim().toLowerCase()).toList();
    final colMap = <String, int>{};
    for (int c = 0; c < headers.length; c++) {
      final h = headers[c];
      if (h.contains('类型') || h.contains('type')) colMap['type'] = c;
      else if (h.contains('分类') || h.contains('category')) colMap['category'] = c;
      else if (h.contains('金额') || h.contains('amount')) colMap['amount'] = c;
      else if (h.contains('备注') || h.contains('note')) colMap['note'] = c;
      else if (h.contains('日期') || h.contains('date')) colMap['date'] = c;
    }

    // If no standard headers found, try auto-detect
    if (colMap.isEmpty) {
      // Treat as raw data: try to guess columns from first data row
      // Common Alipay export: 时间, 交易对方, 金额, 收支, etc.
      // Common WeChat export: 交易时间, 交易对方, 金额, 收支, etc.
      for (int i = 1; i < lines.length; i++) {
        final cols = lines[i].split(sep).map((c) => c.trim()).toList();
        final parsed = _autoDetectRow(cols);
        if (parsed != null) results.add(parsed);
      }
      return results;
    }

    // Parse data rows with column map
    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(sep).map((c) => c.trim()).toList();
      if (cols.length < 3) continue;

      try {
        final type = colMap.containsKey('type') && cols.length > colMap['type']!
            ? cols[colMap['type']!].toLowerCase()
            : 'expense';
        final category = colMap.containsKey('category') && cols.length > colMap['category']!
            ? cols[colMap['category']!]
            : _inferCategoryFromMerchant('');
        final amountStr = colMap.containsKey('amount') && cols.length > colMap['amount']!
            ? cols[colMap['amount']!].replaceAll('¥', '').replaceAll(RegExp(r'[,\s]'), '')
            : '0';
        final note = colMap.containsKey('note') && cols.length > colMap['note']!
            ? cols[colMap['note']!]
            : '';
        final dateStr = colMap.containsKey('date') && cols.length > colMap['date']!
            ? cols[colMap['date']!]
            : DateFormat('yyyy-MM-dd').format(DateTime.now());

        final amount = double.tryParse(amountStr) ?? 0;
        if (amount <= 0) continue;

        final cleanType = (type.contains('收入') || type.contains('income')) ? 'income' : 'expense';
        final dt = _parseDate(dateStr);

        results.add(ParsedTransaction(
          type: cleanType,
          category: category.isEmpty ? '其他' : category,
          amount: amount,
          note: note,
          date: dt,
        ));
      } catch (_) {}
    }

    return results;
  }

  /// Parse a row using column map
  ParsedTransaction? _parseRow(List<String> texts, Map<String, int> colMap) {
    String type = 'expense';
    String category = '其他';
    double amount = 0;
    String note = '';
    DateTime date = DateTime.now();

    if (colMap.containsKey('type') && texts.length > colMap['type']!) {
      final t = texts[colMap['type']!].toLowerCase();
      type = (t.contains('收入') || t.contains('income')) ? 'income' : 'expense';
    }
    if (colMap.containsKey('category') && texts.length > colMap['category']!) {
      category = texts[colMap['category']!];
      if (category.isEmpty) category = '其他';
    }
    if (colMap.containsKey('amount') && texts.length > colMap['amount']!) {
      amount = double.tryParse(
          texts[colMap['amount']!].replaceAll('¥', '').replaceAll(',', '')) ?? 0;
    }
    if (colMap.containsKey('note') && texts.length > colMap['note']!) {
      note = texts[colMap['note']!];
    }
    if (colMap.containsKey('date') && texts.length > colMap['date']!) {
      date = _parseDate(texts[colMap['date']!]);
    }

    if (amount <= 0) return null;
    return ParsedTransaction(
      type: type,
      category: category.isEmpty ? '其他' : category,
      amount: amount,
      note: note,
      date: date,
    );
  }

  /// Auto-detect columns for unstructured CSV data
  ParsedTransaction? _autoDetectRow(List<String> cols) {
    // Try to find amount and other fields by pattern
    double? amount;
    String type = 'expense';
    String merchant = '';
    String dateStr = '';

    for (final c in cols) {
      // Match amount: positive/negative decimal
      final amtMatch = RegExp(r'^-?\d+(\.\d+)?$').firstMatch(c.replaceAll(',', ''));
      if (amtMatch != null) {
        final val = double.tryParse(c.replaceAll(',', ''));
        if (val != null && val != 0) {
          amount = val.abs();
          type = val < 0 ? 'expense' : 'income';
          continue;
        }
      }

      // Match date
      if (RegExp(r'^\d{4}[-/]\d{1,2}[-/]\d{1,2}$').hasMatch(c) ||
          RegExp(r'^\d{1,2}[-/]\d{1,2}$').hasMatch(c)) {
        dateStr = c;
        continue;
      }

      // Could be merchant name
      if (c.length > 1 && c.length < 50 && !c.contains('¥')) {
        merchant = c;
      }
    }

    if (amount == null || amount <= 0) return null;

    final dt = dateStr.isNotEmpty ? _parseDate(dateStr) : DateTime.now();
    return ParsedTransaction(
      type: type,
      category: _inferCategoryFromMerchant(merchant),
      amount: amount,
      note: merchant,
      date: dt,
    );
  }

  DateTime _parseDate(String dateStr) {
    try {
      // yyyy-MM-dd
      if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(dateStr)) {
        final parts = dateStr.split('-');
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
      // yyyy/MM/dd
      if (RegExp(r'^\d{4}/\d{1,2}/\d{1,2}$').hasMatch(dateStr)) {
        final parts = dateStr.split('/');
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
      // MM-dd
      if (RegExp(r'^\d{1,2}-\d{1,2}$').hasMatch(dateStr)) {
        final parts = dateStr.split('-');
        return DateTime(2026, int.parse(parts[0]), int.parse(parts[1]));
      }
      // MM/dd
      if (RegExp(r'^\d{1,2}/\d{1,2}$').hasMatch(dateStr)) {
        final parts = dateStr.split('/');
        return DateTime(2026, int.parse(parts[0]), int.parse(parts[1]));
      }
    } catch (_) {}
    return DateTime.now();
  }

  String _inferCategoryFromMerchant(String merchant) {
    final map = {
      '餐饮': ['冷食', '快餐', '餐厅', '食堂', '面包', '奶茶', '咖啡', '水果', '买菜', '外卖', '吃饭'],
      '交通': ['加油站', '加油', '公交', '地铁', '打车', '滴滴', '停车', '火车'],
      '购物': ['淘宝', '天猫', '拼多多', '京东', '闪魔', '省钱卡', '平台商户', '超市'],
      '娱乐': ['电影', '游戏', 'KTV', '旅游', '门票'],
      '居住': ['房租', '水电', '物业', '吸顶灯', '装修', '家装'],
      '通讯': ['话费', '流量', '宽带', '腾讯'],
      '医疗': ['医院', '看病', '药'],
      '充值': ['充值', '缴费', '会员', '年卡'],
    };
    for (final entry in map.entries) {
      for (final kw in entry.value) {
        if (merchant.contains(kw)) return entry.key;
      }
    }
    return '其他';
  }

  void _importSelected() {
    if (_selectedIndexes.isEmpty) return;
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    for (final idx in _selectedIndexes) {
      final tx = _parsed[idx];
      provider.addTransaction(Transaction(
        type: tx.type,
        amount: tx.amount,
        category: tx.category,
        note: tx.note,
        date: tx.date,
      ));
    }
    setState(() {
      _showSuccess = true;
    });
  }
}

class ParsedTransaction {
  final String type;
  final String category;
  final double amount;
  final String note;
  final DateTime date;

  ParsedTransaction({
    required this.type,
    required this.category,
    required this.amount,
    required this.note,
    required this.date,
  });
}
