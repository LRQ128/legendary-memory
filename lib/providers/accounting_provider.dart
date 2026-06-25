import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/database.dart';
import 'package:intl/intl.dart';

class AccountingProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  DatabaseHelper get database => _db;

  List<Transaction> _transactions = [];
  List<Transaction> _currentDayTransactions = [];
  Map<String, double> _categoryExpense = {};
  Map<String, double> _categoryIncome = {};
  Map<String, double> _monthSummary = {'income': 0, 'expense': 0, 'balance': 0};

  // Year data
  String _selectedYear = DateFormat('yyyy').format(DateTime.now());
  Map<String, double> _yearSummary = {'income': 0, 'expense': 0, 'balance': 0};
  Map<String, double> _yearCategoryExpense = {};
  Map<String, double> _yearCategoryIncome = {};
  Map<int, double> _monthlyExpense = {};
  Map<int, double> _monthlyIncome = {};
  Budget? _currentBudget;
  List<AccountModel> _accounts = [];
  DateTime _selectedDate = DateTime.now();
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  List<Transaction> get transactions => _transactions;
  List<Transaction> get currentDayTransactions => _currentDayTransactions;
  Map<String, double> get categoryExpense => _categoryExpense;
  Map<String, double> get categoryIncome => _categoryIncome;
  Map<String, double> get monthSummary => _monthSummary;

  String get selectedYear => _selectedYear;
  Map<String, double> get yearSummary => _yearSummary;
  Map<String, double> get yearCategoryExpense => _yearCategoryExpense;
  Map<String, double> get yearCategoryIncome => _yearCategoryIncome;
  Map<int, double> get monthlyExpense => _monthlyExpense;
  Map<int, double> get monthlyIncome => _monthlyIncome;
  Budget? get currentBudget => _currentBudget;
  int _totalTransactionCount = 0;
  int get totalTransactionCount => _totalTransactionCount;

  List<AccountModel> get accounts => _accounts;
  DateTime get selectedDate => _selectedDate;
  String get selectedMonth => _selectedMonth;

  double get monthExpense => _monthSummary['expense'] ?? 0.0;
  double get monthIncome => _monthSummary['income'] ?? 0.0;
  double get monthBalance => _monthSummary['balance'] ?? 0.0;
  double get budgetRemaining =>
      (_currentBudget?.amount ?? double.infinity) - monthExpense;

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setSelectedMonth(String month) {
    _selectedMonth = month;
    notifyListeners();
  }

  void setSelectedYear(String year) {
    _selectedYear = year;
    notifyListeners();
  }

  /// 自定义分类图标缓存（从数据库加载）
  Map<String, IconData> customCategoryIcons = {};

  /// 获取某个分类的图标（含自定义分类）
  IconData getIconForCategory(String category) {
    return categoryIcons[category] ?? customCategoryIcons[category] ?? Icons.more_horiz;
  }

  /// 加载自定义分类图标到缓存
  Future<void> loadCustomCategoryIcons() async {
    final cats = await _db.getAllCustomCategories();
    final icons = <String, IconData>{};
    for (final row in cats) {
      final name = row['name'] as String;
      final iconStr = row['icon'] as String? ?? 'more_horiz';
      icons[name] = _iconNameToIcon(iconStr);
    }
    customCategoryIcons = icons;
    notifyListeners();
  }

  /// 图标字符串 → IconData
  static IconData _iconNameToIcon(String name) {
    switch (name) {
      case 'restaurant': return Icons.restaurant_menu_outlined;
      case 'directions_car': return Icons.directions_car_outlined;
      case 'shopping_bag': return Icons.shopping_bag_outlined;
      case 'sports_esports': return Icons.sports_esports_outlined;
      case 'home': return Icons.home_outlined;
      case 'phone_android': return Icons.phone_android_outlined;
      case 'medical_services': return Icons.medical_services_outlined;
      case 'menu_book': return Icons.menu_book_outlined;
      case 'card_giftcard': return Icons.card_giftcard_outlined;
      case 'checkroom': return Icons.checkroom_outlined;
      case 'inventory_2': return Icons.inventory_2_outlined;
      case 'work': return Icons.work_outlined;
      case 'account_balance_wallet': return Icons.account_balance_wallet_outlined;
      case 'build': return Icons.build_outlined;
      case 'emoji_events': return Icons.emoji_events_outlined;
      case 'favorite': return Icons.favorite_outlined;
      case 'handshake': return Icons.handshake_outlined;
      case 'volunteer_activism': return Icons.volunteer_activism_outlined;
      case 'receipt_long': return Icons.receipt_long_outlined;
      case 'pets': return Icons.pets_outlined;
      case 'flight': return Icons.flight_outlined;
      case 'local_gas_station': return Icons.local_gas_station_outlined;
      case 'coffee': return Icons.coffee_outlined;
      case 'child_care': return Icons.child_care_outlined;
      case 'fitness_center': return Icons.fitness_center_outlined;
      default: return Icons.more_horiz;
    }
  }

  Future<void> loadTransactions() async {
    _transactions = await _db.getTransactions(month: _selectedMonth);
    notifyListeners();
  }

  Future<void> loadCurrentDayTransactions() async {
    _currentDayTransactions =
        await _db.getTransactionsByDate(_selectedDate);
    notifyListeners();
  }

  Future<void> loadMonthSummary() async {
    _monthSummary = await _db.getMonthSummary(_selectedMonth);
    notifyListeners();
  }

  Future<void> loadCategoryExpense() async {
    _categoryExpense = await _db.getCategoryExpense(_selectedMonth);
    notifyListeners();
  }

  Future<void> loadCategoryIncome() async {
    _categoryIncome = await _db.getCategoryIncome(_selectedMonth);
    notifyListeners();
  }

  // Year data loading
  Future<void> loadYearSummary() async {
    _yearSummary = await _db.getYearSummary(_selectedYear);
    notifyListeners();
  }

  Future<void> loadYearCategoryExpense() async {
    _yearCategoryExpense = await _db.getYearCategoryExpense(_selectedYear);
    notifyListeners();
  }

  Future<void> loadYearCategoryIncome() async {
    _yearCategoryIncome = await _db.getYearCategoryIncome(_selectedYear);
    notifyListeners();
  }

  Future<void> loadMonthlyExpense() async {
    _monthlyExpense = await _db.getMonthlyExpense(_selectedYear);
    notifyListeners();
  }

  Future<void> loadMonthlyIncome() async {
    _monthlyIncome = await _db.getMonthlyIncome(_selectedYear);
    notifyListeners();
  }

  Future<void> loadAllYearData() async {
    await Future.wait([
      loadYearSummary(),
      loadYearCategoryExpense(),
      loadYearCategoryIncome(),
      loadMonthlyExpense(),
      loadMonthlyIncome(),
    ]);
  }

  Future<void> loadBudget() async {
    _currentBudget = await _db.getBudget(_selectedMonth);
    notifyListeners();
  }

  Future<List<Transaction>> searchTransactions(String keyword) async {
    return await _db.searchTransactions(keyword);
  }

  /// 日期区间搜索
  Future<List<Transaction>> searchTransactionsByDateRange({
    String keyword = '',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _db.searchTransactionsByDateRange(
      keyword: keyword,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> loadTotalCount() async {
    _totalTransactionCount = await _db.getTransactionCount();
    notifyListeners();
  }

  Future<void> loadAccounts() async {
    _accounts = await _db.getAccounts();
    notifyListeners();
  }

  Future<void> addTransaction(Transaction tx) async {
    final id = await _db.insertTransaction(tx);
    print('[DEBUG] TX saved with id=$id');
    await refreshAll();
    print('[DEBUG] TX refreshAll done, count=${_transactions.length}');
  }

  Future<void> updateTransaction(Transaction tx) async {
    await _db.updateTransaction(tx);
    await refreshAll();
  }

  Future<void> deleteTransaction(int id) async {
    await _db.deleteTransaction(id);
    await refreshAll();
  }

  Future<void> setBudget(double amount) async {
    await _db.setBudget(Budget(amount: amount, month: _selectedMonth));
    await loadBudget();
  }

  // ── Full Data Export / Import ──

  Future<Map<String, dynamic>> exportAllData() async {
    final allTxs = await _db.getAllTransactionsWithoutLimit();
    final allBudgets = await _db.getAllBudgets();
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': allTxs.map((tx) => tx.toMap()).toList(),
      'budgets': allBudgets.map((b) => b.toMap()).toList(),
    };
  }

  Future<int> importAllData(Map<String, dynamic> data) async {
    int count = 0;
    final txs = data['transactions'] as List<dynamic>? ?? [];
    for (final m in txs) {
      final tx = Transaction.fromMap(Map<String, dynamic>.from(m));
      final txWithoutId = tx.copyWith(id: null);
      await _db.insertTransaction(txWithoutId);
      count++;
    }
    final budgets = data['budgets'] as List<dynamic>? ?? [];
    for (final m in budgets) {
      final b = Budget.fromMap(Map<String, dynamic>.from(m));
      await _db.setBudget(b);
    }
    return count;
  }

  Future<void> refreshAll() async {
    try {
      await loadCustomCategoryIcons();
      await loadTransactions();
      await loadCurrentDayTransactions();
      await loadMonthSummary();
      await loadCategoryExpense();
      await loadBudget();
      await loadTotalCount();
      await loadAccounts();
    } catch (e) {
      print('[DEBUG] refreshAll error: $e');
    }
  }

  // Category icons & colors
  static const Map<String, IconData> categoryIcons = {
    // 支出分类
    '餐饮': Icons.restaurant,
    '交通': Icons.directions_bus,
    '购物': Icons.shopping_bag,
    '娱乐': Icons.movie,
    '居住': Icons.home,
    '通讯': Icons.phone_android,
    '医疗': Icons.local_hospital,
    '教育': Icons.school,
    '人情': Icons.favorite,
    '服饰': Icons.checkroom,
    '日用品': Icons.inventory_2,
    // 收入分类
    '工资': Icons.work,
    '奖金': Icons.card_giftcard,
    '理财': Icons.trending_up,
    '兼职': Icons.handyman,
    // 兜底
    '其他': Icons.more_horiz,
    // 旧版长分类名兼容（用户数据库中已存的旧记录）
    '食品餐饮': Icons.restaurant,
    '购物消费': Icons.shopping_bag,
    '出行交通': Icons.directions_bus,
    '休闲娱乐': Icons.movie,
    '居家生活': Icons.home,
    '通讯缴费': Icons.phone_android,
    '健康医疗': Icons.local_hospital,
    '文化教育': Icons.school,
  };

  static const List<String> expenseCategories = [
    '餐饮', '交通', '购物', '娱乐', '居住',
    '通讯', '医疗', '教育', '人情', '服饰',
    '日用品', '其他',
  ];

  static const List<String> incomeCategories = [
    '工资', '奖金', '理财', '兼职', '其他',
  ];
}
