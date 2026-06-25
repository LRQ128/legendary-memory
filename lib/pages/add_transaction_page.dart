import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/accounting_provider.dart';
import '../models/database.dart';
import '../models/transaction.dart';


class AddTransactionPage extends StatefulWidget {
  final String? type;
  final DateTime? initialDate;
  final Transaction? editTransaction; // 编辑模式：传入已有记录
  const AddTransactionPage({super.key, this.type, this.initialDate, this.editTransaction});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  String _type = 'expense';
  String _category = '其他';
  String _amountDisplay = '0.00';
  String _note = '';
  late DateTime _date;
  Transaction? _editing; // 编辑模式下的原始记录
  final List<String> _images = []; // 附件图片路径

  // 自定义分类（从数据库加载）
  List<String> _customExpenseCats = [];
  List<String> _customIncomeCats = [];
  final Map<String, IconData> _customIcons = {}; // 自定义分类名 → IconData

  // 计算器模式状态
  double? _firstOperand;
  String? _pendingOperator;
  bool _hasResult = false;

  /// 完整表达式显示（如 "10 + 8"）
  String get _displayText {
    if (_hasResult) {
      return '= $_amountDisplay';
    }
    if (_pendingOperator != null) {
      final first = _firstOperand?.toStringAsFixed(2) ?? '?';
      final second = _amountDisplay.isEmpty ? '?' : _amountDisplay;
      return '$first $_pendingOperator $second';
    }
    return _amountDisplay;
  }

  static const List<String> _expenseCategories = [
    '其他', '购物消费', '食品餐饮', '出行交通', '休闲娱乐',
  ];
  static const List<String> _expenseSecondRow = [
    '居家生活', '文化教育', '送礼人情', '健康医疗',
  ];

  static const List<String> _incomeCategories = [
    '其他', '中奖', '理财盈利', '礼金人情', '借入',
    '奖金', '兼职外快', '工资', '二手闲置', '补贴',
    '报销',
  ];

  static const Map<String, IconData> _iconMap = {
    // 支出分类
    '餐饮': Icons.restaurant_menu_outlined,
    '交通': Icons.directions_car_outlined,
    '购物': Icons.shopping_bag_outlined,
    '娱乐': Icons.sports_esports_outlined,
    '居住': Icons.home_outlined,
    '通讯': Icons.phone_android_outlined,
    '医疗': Icons.medical_services_outlined,
    '教育': Icons.menu_book_outlined,
    '人情': Icons.card_giftcard_outlined,
    '服饰': Icons.checkroom_outlined,
    '日用品': Icons.inventory_2_outlined,
    // 收入分类
    '工资': Icons.work_outlined,
    '奖金': Icons.card_giftcard_outlined,
    '理财': Icons.account_balance_wallet_outlined,
    '兼职': Icons.build_outlined,
    // 兜底
    '其他': Icons.apps_outlined,
    // 旧版长分类名兼容（已有数据）
    '购物消费': Icons.shopping_bag_outlined,
    '食品餐饮': Icons.restaurant_menu_outlined,
    '出行交通': Icons.directions_car_outlined,
    '休闲娱乐': Icons.sports_esports_outlined,
    '居家生活': Icons.home_outlined,
    '文化教育': Icons.menu_book_outlined,
    '送礼人情': Icons.card_giftcard_outlined,
    '健康医疗': Icons.medical_services_outlined,
    '中奖': Icons.emoji_events_outlined,
    '理财盈利': Icons.account_balance_wallet_outlined,
    '礼金人情': Icons.favorite_outlined,
    '借入': Icons.handshake_outlined,
    '兼职外快': Icons.build_outlined,
    '二手闲置': Icons.inventory_2_outlined,
    '补贴': Icons.volunteer_activism_outlined,
    '报销': Icons.receipt_long_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
    _editing = widget.editTransaction;
    if (_editing != null) {
      // 编辑模式：预填已有数据
      _type = _editing!.type;
      _category = _editing!.category;
      _amountDisplay = _editing!.amount.toStringAsFixed(2);
      _note = _editing!.note;
      _date = _editing!.date;
      _images.addAll(_editing!.images);
    } else {
      _date = widget.initialDate ?? DateTime.now();
      if (widget.type != null) {
        _type = widget.type!;
      }
    }
  }

  /// 从数据库加载自定义分类
  Future<void> _loadCustomCategories() async {
    final dbProvider = Provider.of<AccountingProvider>(context, listen: false).database;
    final expenseCats = await dbProvider.getCustomCategories('expense');
    final incomeCats = await dbProvider.getCustomCategories('income');
    final icons = <String, IconData>{};
    for (final row in [...expenseCats, ...incomeCats]) {
      final name = row['name'] as String;
      final iconStr = row['icon'] as String? ?? 'more_horiz';
      icons[name] = iconNameToIcon[iconStr] ?? Icons.more_horiz;
    }
    setState(() {
      _customExpenseCats = expenseCats.map((e) => e['name'] as String).toList();
      _customIncomeCats = incomeCats.map((e) => e['name'] as String).toList();
      _customIcons.addAll(icons);
    });
  }

  /// 获取当前类型的所有分类（含自定义）
  List<String> _getCategories(String type) {
    if (type == 'expense') {
      return [..._expenseCategories, ..._expenseSecondRow, ..._customExpenseCats];
    } else {
      return [..._incomeCategories, ..._customIncomeCats];
    }
  }

  void _onKeyPressed(String key) {
    setState(() {
      // 刚出结果时按数字→重新开始
      if (_hasResult) {
        _hasResult = false;
        if (key != 'backspace' && key != '.') {
          _amountDisplay = key;
          return;
        }
      }

      if (key == 'backspace') {
        // 在输第二个数时按退格→取消运算符回到第一个数
        if (_pendingOperator != null && _amountDisplay.isEmpty) {
          _pendingOperator = null;
          _amountDisplay = _firstOperand!.toStringAsFixed(2);
          _firstOperand = null;
        } else if (_amountDisplay.length > 1) {
          _amountDisplay = _amountDisplay.substring(0, _amountDisplay.length - 1);
        } else {
          _amountDisplay = '0';
        }
        if (_amountDisplay == '0') _amountDisplay = '0.00';
      } else if (key == '.') {
        if (!_amountDisplay.contains('.')) {
          _amountDisplay += '.';
        }
      } else {
        // 数字键
        if (_pendingOperator != null && _amountDisplay.isEmpty) {
          _amountDisplay = key;
        } else if (_amountDisplay == '0.00' || _amountDisplay == '0') {
          _amountDisplay = key;
        } else {
          _amountDisplay += key;
        }
      }
    });
  }

  void _onOperatorPressed(String op) {
    setState(() {
      if (_hasResult) {
        // 刚出结果再按运算符 → 用结果继续计算
        _firstOperand = _parsedAmount;
        _pendingOperator = op;
        _amountDisplay = '';
        _hasResult = false;
        return;
      }
      if (_pendingOperator == null) {
        _firstOperand = _parsedAmount;
        _pendingOperator = op;
        _amountDisplay = '';
      } else {
        // 已有运算符→替换
        _pendingOperator = op;
      }
    });
  }

  double? _evaluateExpression() {
    if (_firstOperand == null || _pendingOperator == null || _amountDisplay.isEmpty) {
      return null;
    }
    final second = double.tryParse(_amountDisplay);
    if (second == null) return null;

    double result;
    switch (_pendingOperator) {
      case '+':
        result = _firstOperand! + second;
        break;
      case '−':
        result = _firstOperand! - second;
        break;
      case '×':
        result = _firstOperand! * second;
        break;
      case '÷':
        result = second != 0 ? _firstOperand! / second : 0;
        break;
      default:
        return null;
    }

    _firstOperand = null;
    _pendingOperator = null;
    _hasResult = true;
    return result;
  }

  double get _parsedAmount => double.tryParse(_amountDisplay) ?? 0;

  Future<void> _saveTransaction({bool keepPage = false}) async {
    if (_parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入金额'),
            backgroundColor: Color(0xFFEF5350), duration: Duration(seconds: 1)),
      );
      return;
    }
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final tx = Transaction(
      id: _editing?.id, // 编辑模式保留原ID
      type: _type == 'expense' ? 'expense' : 'income',
      amount: _parsedAmount,
      category: _category,
      note: _note,
      date: _date,
      images: _images,
    );
    try {
      if (_editing != null) {
        await provider.updateTransaction(tx);
      } else {
        await provider.addTransaction(tx);
      }
      if (keepPage && _editing == null) {
        setState(() {
          _amountDisplay = '0.00';
          _note = '';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已记录一笔${_type == 'expense' ? '支出' : '收入'}，继续记账'),
              backgroundColor: _type == 'expense'
                  ? const Color(0xFFEF5350)
                  : const Color(0xFF4CAF50),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountColor = _type == 'expense'
        ? const Color(0xFFEF5350)
        : const Color(0xFF4CAF50);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(children: [
                  _buildCategoryGrid(amountColor),
                  if (_images.isNotEmpty) _buildImagePreview(),
                ]))),
            _buildAmountBar(amountColor),
            _buildAuxiliaryBar(),
            _buildNumberPad(),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 16, top: 4, bottom: 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () async {
              if (_parsedAmount > 0) {
                await _saveTransaction();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          Expanded(
            child: Row(
              children: [
                _buildTab('支出', 'expense'),
                _buildTab('收入', 'income'),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.book, color: Colors.green[600], size: 18),
                const SizedBox(width: 3),
                Text('L&W',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Icon(Icons.arrow_drop_down, color: Colors.grey[400], size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String type) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: type == 'expense' || type == 'income'
            ? () => setState(() {
                  _type = type;
                  _category = '其他';
                })
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: selected
                ? const Border(
                    bottom: BorderSide(color: Color(0xFF4CAF50), width: 2.5))
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.black87 : Colors.grey[350],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Category Grid ────────────────────────────────────
  Widget _buildCategoryGrid(Color amountColor) {
    if (_type == 'expense') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildExpenseCategoryRows(),
      );
    } else {
      return Column(children: _buildIncomeCategoryRows());
    }
  }

  List<Widget> _buildExpenseCategoryRows() {
    final allCats = [
      ..._expenseCategories,
      ..._expenseSecondRow,
      ..._customExpenseCats,
    ];
    final rows = <Widget>[];
    // First row: first 5
    final row1 = allCats.take(5).toList();
    rows.add(Row(
        children: row1.map((c) => Expanded(child: _buildCategoryItem(c))).toList()));
    // Second row: next 4 + add button
    if (allCats.length > 5) {
      final row2 = allCats.sublist(5, allCats.length > 9 ? 9 : allCats.length);
      rows.add(const SizedBox(height: 14));
      final row2Widgets = <Widget>[
        ...row2.map((c) => Expanded(child: _buildCategoryItem(c))),
      ];
      while (row2Widgets.length < 4) {
        row2Widgets.add(const Expanded(child: SizedBox()));
      }
      row2Widgets.add(Expanded(child: _buildAddCategoryItem()));
      rows.add(Row(children: row2Widgets));
    } else {
      rows.add(const SizedBox(height: 14));
      rows.add(Row(children: [
        Expanded(child: SizedBox()),
        Expanded(child: SizedBox()),
        Expanded(child: SizedBox()),
        Expanded(child: SizedBox()),
        Expanded(child: _buildAddCategoryItem()),
      ]));
    }
    return rows;
  }

  List<Widget> _buildIncomeCategoryRows() {
    final allCats = [..._incomeCategories, ..._customIncomeCats];
    final rows = <Widget>[];
    int i = 0;
    while (i < allCats.length) {
      final end = (i + 5 > allCats.length) ? allCats.length : i + 5;
      final chunk = allCats.sublist(i, end);
      final rowItems = chunk.map((c) => Expanded(child: _buildCategoryItem(c))).toList();
      if (end == allCats.length) {
        rowItems.add(Expanded(child: _buildAddCategoryItem()));
      }
      while (rowItems.length < 6) {
        rowItems.add(const Expanded(child: SizedBox()));
      }
      rows.add(Row(children: rowItems));
      if (end < allCats.length) {
        rows.add(const SizedBox(height: 14));
      }
      i = end;
    }
    return rows;
  }

  /// 判断是否为自定义分类
  bool _isCustomCategory(String cat) {
    return _customExpenseCats.contains(cat) || _customIncomeCats.contains(cat);
  }

  Widget _buildCategoryItem(String category, {bool inGroup = false}) {
    final selected = _category == category;
    final icon = _iconMap[category] ?? _customIcons[category] ?? Icons.more_horiz;
    final isCustom = _isCustomCategory(category);

    return GestureDetector(
      onTap: () => setState(() => _category = category),
      onLongPress: isCustom
          ? () => _showDeleteCategoryDialog(category)
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFE0F2F1)
                  : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22,
                color: selected
                    ? const Color(0xFF00796B)
                    : (inGroup ? Colors.grey[600] : Colors.grey[600])),
          ),
          const SizedBox(height: 6),
          Text(category,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.black87 : Colors.grey[600])),
        ],
      ),
    );
  }

  /// 可用图标列表供用户选择
  static const Map<String, IconData> iconNameToIcon = {
    'restaurant': Icons.restaurant_menu_outlined,
    'directions_car': Icons.directions_car_outlined,
    'shopping_bag': Icons.shopping_bag_outlined,
    'sports_esports': Icons.sports_esports_outlined,
    'home': Icons.home_outlined,
    'phone_android': Icons.phone_android_outlined,
    'medical_services': Icons.medical_services_outlined,
    'menu_book': Icons.menu_book_outlined,
    'card_giftcard': Icons.card_giftcard_outlined,
    'checkroom': Icons.checkroom_outlined,
    'inventory_2': Icons.inventory_2_outlined,
    'work': Icons.work_outlined,
    'account_balance_wallet': Icons.account_balance_wallet_outlined,
    'build': Icons.build_outlined,
    'emoji_events': Icons.emoji_events_outlined,
    'favorite': Icons.favorite_outlined,
    'handshake': Icons.handshake_outlined,
    'volunteer_activism': Icons.volunteer_activism_outlined,
    'receipt_long': Icons.receipt_long_outlined,
    'pets': Icons.pets_outlined,
    'flight': Icons.flight_outlined,
    'local_gas_station': Icons.local_gas_station_outlined,
    'coffee': Icons.coffee_outlined,
    'child_care': Icons.child_care_outlined,
    'fitness_center': Icons.fitness_center_outlined,
  };

  Future<void> _showDeleteCategoryDialog(String category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定删除分类「$category」？已有的账单数据不会受影响。'),
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
      final db = DatabaseHelper();
      final cats = await db.getCustomCategories(_type);
      for (final cat in cats) {
        if (cat['name'] == category) {
          await db.deleteCustomCategory(cat['id'] as int);
          break;
        }
      }
      await _loadCustomCategories();
      if (_category == category) {
        setState(() => _category = '其他');
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    String selectedIcon = 'apps';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新增分类'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '分类名称',
                    border: OutlineInputBorder(),
                    hintText: '输入分类名称',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('选择图标', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: GridView.count(
                    crossAxisCount: 5,
                    childAspectRatio: 1.2,
                    children: iconNameToIcon.entries.map((entry) {
                      final isSelected = selectedIcon == entry.key;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = entry.key),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE0F2F1) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: const Color(0xFF009688), width: 1.5) : null,
                          ),
                          child: Icon(entry.value, size: 22, color: isSelected ? const Color(0xFF00796B) : Colors.grey[600]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx, {'name': name, 'icon': selectedIcon});
              },
              child: const Text('确定', style: TextStyle(color: Color(0xFF009688))),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final provider = Provider.of<AccountingProvider>(context, listen: false);
      await provider.database.addCustomCategory(result['name']!, result['icon']!, _type);
      await _loadCustomCategories();
    }
  }

  Widget _buildAddCategoryItem() {
    return GestureDetector(
      onTap: _showAddCategoryDialog,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, size: 22, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          const Text('新增',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // ─── Image Preview ────────────────────────────────────
  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _images.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            if (i == _images.length) {
              // 添加图片按钮
              return GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Icon(Icons.add_photo_alternate_outlined,
                      size: 28, color: Colors.grey[400]),
                ),
              );
            }
            // 已有图片
            return Stack(
              children: [
                GestureDetector(
                  onTap: () => _previewImage(_images[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_images[i]),
                      width: 80, height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80, height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -4, right: -4,
                  child: GestureDetector(
                    onTap: () => _removeImage(i),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Amount & Note Bar ────────────────────────────────
  Widget _buildAmountBar(Color amountColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showNoteDialog(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.label_outline, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    _note.isEmpty ? '添加备注' : _note,
                    style: TextStyle(
                        fontSize: 13,
                        color: _note.isEmpty
                            ? Colors.grey[400]
                            : Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_pendingOperator != null || _hasResult)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    _displayText,
                    style: TextStyle(
                      fontSize: _hasResult ? 20 : 16,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              Text(
                _amountDisplay,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNoteDialog() {
    final controller = TextEditingController(text: _note);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加备注'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '输入备注内容',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
              onPressed: () {
                setState(() => _note = controller.text);
                Navigator.pop(ctx);
              },
              child: const Text('确定')),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  // ─── Auxiliary Bar ────────────────────────────────────
  Widget _buildAuxiliaryBar() {
    final dayDiff = DateTime.now().difference(_date).inDays;
    String dateLabel;
    if (dayDiff == 0) {
      dateLabel = '今天';
    } else if (dayDiff == 1) {
      dateLabel = '昨天';
    } else if (dayDiff == 2) {
      dateLabel = '前天';
    } else {
      dateLabel = '${_date.month}/${_date.day}';
    }

    final items = <Widget>[
      GestureDetector(
        onTap: _pickDate,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 17, color: Colors.grey[700]),
            const SizedBox(width: 3),
            Text(dateLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
      const SizedBox(width: 14),
      GestureDetector(
        onTap: _showNoteDialog,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 17, color: Colors.grey[700]),
            const SizedBox(width: 3),
            Text('备注',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
      const SizedBox(width: 14),
      GestureDetector(
        onTap: _pickImage,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_outlined, size: 17, color: Colors.grey[700]),
            const SizedBox(width: 3),
            Text(_images.isEmpty ? '附件' : '附件${_images.length}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
      const Spacer(),
      _buildAuxItem(Icons.settings_outlined, ''),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(children: items),
    );
  }

  /// 从相册选择图片
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'tx_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destPath = '${dir.path}/$fileName';
      await File(picked.path).copy(destPath);
      setState(() => _images.add(destPath));
    }
  }

  /// 删除某张图片
  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  /// 预览图片（全屏展示）
  void _previewImage(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('图片预览'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('图片加载失败', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuxItem(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        if (label == '附件') _pickImage();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: Colors.grey[700]),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }

  // ─── Number Pad ───────────────────────────────────────
  Widget _buildNumberPad() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNumRow(['1', '2', '3'], '−'),
          _buildNumRow(['4', '5', '6'], '+'),
          _buildNumRow(['7', '8', '9'], '×'),
          _buildNumRow(['.', '0', 'backspace'], '÷'),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildNumRow(List<String> keys, String funcSymbol) {
    return Row(
      children: [
        for (final k in keys)
          Expanded(child: k == 'backspace'
              ? _buildBackspaceKey()
              : _buildNumKey(k)),
        _buildFuncKey(funcSymbol),
      ],
    );
  }

  Widget _buildNumKey(String digit) {
    return GestureDetector(
      onTap: () => _onKeyPressed(digit),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            right: BorderSide(color: Colors.grey[200]!),
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Center(
          child: Text(digit,
              style: const TextStyle(fontSize: 22, color: Colors.black87)),
        ),
      ),
    );
  }

  Widget _buildFuncKey(String symbol) {
    final operators = ['−', '+', '×', '÷'];
    final isOperator = operators.contains(symbol);
    return GestureDetector(
      onTap: isOperator ? () => _onOperatorPressed(symbol) : null,
      child: Container(
        width: MediaQuery.of(context).size.width / 4,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border(
            right: BorderSide(color: Colors.grey[200]!),
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Center(
          child: Text(symbol,
              style: TextStyle(fontSize: 20, color: Colors.grey[500])),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return GestureDetector(
      onTap: () => _onKeyPressed('backspace'),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border(
            right: BorderSide(color: Colors.grey[200]!),
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Center(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.close, size: 15, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    final bool showEquals = _pendingOperator != null && _amountDisplay.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              await _saveTransaction(keepPage: true);
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                border: Border(
                    right: BorderSide(color: Colors.grey[200]!)),
              ),
              child: const Center(
                child: Text('再记',
                    style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              if (showEquals) {
                final result = _evaluateExpression();
                if (result != null) {
                  setState(() {
                    _amountDisplay = result.toStringAsFixed(2);
                  });
                }
              } else {
                if (_parsedAmount > 0) {
                  await _saveTransaction();
                } else {
                  if (mounted) Navigator.pop(context);
                }
              }
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: showEquals
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF4CAF50),
              ),
              child: Center(
                child: Text(
                  showEquals ? '=' : '完成',
                  style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
