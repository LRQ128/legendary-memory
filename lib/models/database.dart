import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'transaction.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'daily_accounting.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT DEFAULT '',
        date TEXT NOT NULL,
        account TEXT DEFAULT '默认',
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT DEFAULT 'wallet',
        balance REAL DEFAULT 0.0,
        type TEXT DEFAULT 'asset'
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        month TEXT NOT NULL UNIQUE
      )
    ''');
    // default account
    await db.insert('accounts', {
      'name': '默认',
      'icon': 'wallet',
      'balance': 0.0,
      'type': 'asset',
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          month TEXT NOT NULL UNIQUE
        )
      ''');
    }
  }

  // === Transaction CRUD ===
  Future<int> insertTransaction(Transaction tx) async {
    final db = await database;
    return await db.insert('transactions', tx.toMap());
  }

  Future<List<Transaction>> getTransactions({String? month}) async {
    final db = await database;
    String? where;
    List<String>? whereArgs;
    if (month != null) {
      where = "date LIKE ?";
      whereArgs = ['$month%'];
    }
    final maps = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<List<Transaction>> getTransactionsByDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final maps = await db.query(
      'transactions',
      where: "date LIKE ?",
      whereArgs: ['$dateStr%'],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<int> updateTransaction(Transaction tx) async {
    final db = await database;
    return await db.update('transactions', tx.toMap(),
        where: 'id = ?', whereArgs: [tx.id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getMonthSummary(String month) async {
    final db = await database;
    final maps = await db.query('transactions',
        where: "date LIKE ?", whereArgs: ['$month%']);
    double income = 0.0, expense = 0.0;
    for (var m in maps) {
      if (m['type'] == 'income') income += m['amount'] as double;
      else expense += m['amount'] as double;
    }
    return {'income': income, 'expense': expense, 'balance': income - expense};
  }

  Future<Map<String, double>> getCategoryExpense(String month) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE date LIKE ? AND type = 'expense'
      GROUP BY category
      ORDER BY total DESC
    ''', ['$month%']);
    Map<String, double> result = {};
    for (var m in maps) {
      result[m['category'] as String] = (m['total'] as num).toDouble();
    }
    return result;
  }

  // === Budget CRUD ===
  Future<int> setBudget(Budget budget) async {
    final db = await database;
    final existing =
        await db.query('budgets', where: 'month = ?', whereArgs: [budget.month]);
    if (existing.isNotEmpty) {
      return await db.update('budgets', budget.toMap(),
          where: 'month = ?', whereArgs: [budget.month]);
    }
    return await db.insert('budgets', budget.toMap());
  }

  Future<Budget?> getBudget(String month) async {
    final db = await database;
    final maps =
        await db.query('budgets', where: 'month = ?', whereArgs: [month]);
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  // === Account CRUD ===
  Future<List<AccountModel>> getAccounts() async {
    final db = await database;
    final maps = await db.query('accounts');
    return maps.map((m) => AccountModel.fromMap(m)).toList();
  }
}
