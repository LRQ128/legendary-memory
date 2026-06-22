import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/database.dart';
import 'package:intl/intl.dart';

class AccountingProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Transaction> _transactions = [];
  List<Transaction> _currentDayTransactions = [];
  Map<String, double> _categoryExpense = {};
  Map<String, double> _monthSummary = {'income': 0, 'expense': 0, 'balance': 0};
  Budget? _currentBudget;
  List<AccountModel> _accounts = [];
  DateTime _selectedDate = DateTime.now();
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  List<Transaction> get transactions => _transactions;
  List<Transaction> get currentDayTransactions => _currentDayTransactions;
  Map<String, double> get categoryExpense => _categoryExpense;
  Map<String, double> get monthSummary => _monthSummary;
  Budget? get currentBudget => _currentBudget;
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

  Future<void> loadBudget() async {
    _currentBudget = await _db.getBudget(_selectedMonth);
    notifyListeners();
  }

  Future<void> loadAccounts() async {
    _accounts = await _db.getAccounts();
    notifyListeners();
  }

  Future<void> addTransaction(Transaction tx) async {
    await _db.insertTransaction(tx);
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

  Future<void> refreshAll() async {
    await loadTransactions();
    await loadCurrentDayTransactions();
    await loadMonthSummary();
    await loadCategoryExpense();
    await loadBudget();
    await loadAccounts();
  }

  // Category icons & colors
  static const Map<String, IconData> categoryIcons = {
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
    '其他': Icons.more_horiz,
    '工资': Icons.work,
    '奖金': Icons.card_giftcard,
    '理财': Icons.trending_up,
    '兼职': Icons.handyman,
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
