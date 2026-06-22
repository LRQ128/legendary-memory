import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

class AddTransactionPage extends StatefulWidget {
  final String? type; // 'income' or 'expense'

  const AddTransactionPage({super.key, this.type});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  String _type = 'expense';
  double _amount = 0;
  String _category = '餐饮';
  String _note = '';
  DateTime _date = DateTime.now();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.type != null) {
      _type = widget.type!;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final categories = _type == 'expense'
        ? AccountingProvider.expenseCategories
        : AccountingProvider.incomeCategories;

    return Scaffold(
      appBar: AppBar(title: const Text('添加记账')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type switch
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = 'expense';
                        _category = '餐饮';
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _type == 'expense'
                              ? AppTheme.expenseRed
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('支出',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = 'income';
                        _category = '工资';
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _type == 'income'
                              ? AppTheme.incomeOrange
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('收入',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount input
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
                prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _type == 'expense'
                        ? AppTheme.expenseRed
                        : AppTheme.incomeOrange,
                    width: 2,
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              onChanged: (v) => _amount = double.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 20),

            // Category grid
            const Text('分类', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final icon = AccountingProvider.categoryIcons[cat] ?? Icons.more_horiz;
                final color = AppTheme.categoryColors[cat] ?? Colors.grey;
                final selected = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.15) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: selected ? Border.all(color: color, width: 2) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18, color: selected ? color : Colors.grey),
                        const SizedBox(width: 6),
                        Text(cat,
                            style: TextStyle(
                              color: selected ? color : Colors.grey[700],
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Note
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: '备注（选填）',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.edit_note),
              ),
              onChanged: (v) => _note = v,
            ),
            const SizedBox(height: 20),

            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('yyyy年MM月dd日', 'zh_CN').format(_date)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                  locale: const Locale('zh', 'CN'),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入金额')),
                    );
                    return;
                  }
                  provider.addTransaction(Transaction(
                    type: _type,
                    amount: _amount,
                    category: _category,
                    note: _note,
                    date: _date,
                  ));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_type == 'expense' ? '支出' : '收入'}已记录'),
                      backgroundColor: _type == 'expense'
                          ? AppTheme.expenseRed
                          : AppTheme.incomeOrange,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'expense'
                      ? AppTheme.expenseRed
                      : AppTheme.incomeOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('保存', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
