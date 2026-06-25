import 'package:sqflite/sqflite.dart' hide Transaction;
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
      version: 8,
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
        createdAt TEXT NOT NULL,
        images TEXT DEFAULT '',
        remoteId TEXT DEFAULT NULL,
        updatedAt TEXT DEFAULT NULL,
        syncStatus INTEGER DEFAULT 0
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
    await db.execute('''
      CREATE TABLE deleted_remote_ids(
        remoteId TEXT PRIMARY KEY,
        deletedAt TEXT NOT NULL
      )
    ''');
    await db.insert('accounts', {
      'name': '默认',
      'icon': 'wallet',
      'balance': 0.0,
      'type': 'asset',
    });

    // 唯一索引：防止同一条云端数据重复插入
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_remoteId ON transactions(remoteId) WHERE remoteId IS NOT NULL AND remoteId != ""');

    // 自定义分类表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT DEFAULT 'more_horiz',
        type TEXT NOT NULL,
        sortOrder INTEGER DEFAULT 0,
        UNIQUE(name, type)
      )
    ''');
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
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN images TEXT DEFAULT \'\'');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN remoteId TEXT DEFAULT NULL');
        await db.execute('ALTER TABLE transactions ADD COLUMN updatedAt TEXT DEFAULT NULL');
        await db.execute('ALTER TABLE transactions ADD COLUMN syncStatus INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN remoteId TEXT DEFAULT NULL');
        await db.execute('ALTER TABLE transactions ADD COLUMN updatedAt TEXT DEFAULT NULL');
        await db.execute('ALTER TABLE transactions ADD COLUMN syncStatus INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(transactions)');
      final columns = tableInfo.map((r) => r['name'] as String).toSet();
      if (!columns.contains('remoteId')) {
        await db.execute('ALTER TABLE transactions ADD COLUMN remoteId TEXT DEFAULT NULL');
      }
      if (!columns.contains('updatedAt')) {
        await db.execute('ALTER TABLE transactions ADD COLUMN updatedAt TEXT DEFAULT NULL');
      }
      if (!columns.contains('syncStatus')) {
        await db.execute('ALTER TABLE transactions ADD COLUMN syncStatus INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 7) {
      await db.execute('CREATE TABLE IF NOT EXISTS deleted_remote_ids(remoteId TEXT PRIMARY KEY, deletedAt TEXT NOT NULL)');
    }
    if (oldVersion < 8) {
      // 清除已有的重复数据：按 remoteId 分组，只保留 id 最小的一条
      await db.execute('''
        DELETE FROM transactions WHERE id NOT IN (
          SELECT MIN(id) FROM transactions WHERE remoteId IS NOT NULL AND remoteId != "" GROUP BY remoteId
        ) AND remoteId IS NOT NULL AND remoteId != ""
      ''');
      // 创建唯一索引——仅对非空 remoteId 生效，本地未同步的数据不受影响
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_remoteId ON transactions(remoteId) WHERE remoteId IS NOT NULL AND remoteId != ""');
    }
  }

  // === Transaction CRUD ===
  Future<int> insertTransaction(Transaction tx) async {
    final db = await database;
    return await db.insert('transactions', tx.toMap());
  }

  /// 安全插入：如果有 remoteId 冲突则跳过（防止重复）
  Future<int> insertTransactionOrIgnore(Transaction tx) async {
    final db = await database;
    if (tx.remoteId != null && tx.remoteId!.isNotEmpty) {
      try {
        return await db.insert('transactions', tx.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {
        return 0;
      }
    }
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
    // 先查 remoteId，如果有的话记录到已删表
    final maps = await db.query('transactions',
        columns: ['remoteId'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isNotEmpty && maps.first['remoteId'] != null) {
      final remoteId = maps.first['remoteId'] as String;
      if (remoteId.isNotEmpty) {
        try {
          await db.insert('deleted_remote_ids', {
            'remoteId': remoteId,
            'deletedAt': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
    }
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

  Future<Map<String, double>> getCategoryIncome(String month) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE date LIKE ? AND type = 'income'
      GROUP BY category
      ORDER BY total DESC
    ''', ['$month%']);
    Map<String, double> result = {};
    for (var m in maps) {
      result[m['category'] as String] = (m['total'] as num).toDouble();
    }
    return result;
  }

  /// Year summary
  Future<Map<String, double>> getYearSummary(String year) async {
    final db = await database;
    final maps = await db.query('transactions',
        where: "date LIKE ?", whereArgs: ['$year%']);
    double income = 0.0, expense = 0.0;
    for (var m in maps) {
      if (m['type'] == 'income') income += m['amount'] as double;
      else expense += m['amount'] as double;
    }
    return {'income': income, 'expense': expense, 'balance': income - expense};
  }

  Future<Map<String, double>> getYearCategoryExpense(String year) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE date LIKE ? AND type = 'expense'
      GROUP BY category
      ORDER BY total DESC
    ''', ['$year%']);
    Map<String, double> result = {};
    for (var m in maps) {
      result[m['category'] as String] = (m['total'] as num).toDouble();
    }
    return result;
  }

  Future<Map<String, double>> getYearCategoryIncome(String year) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE date LIKE ? AND type = 'income'
      GROUP BY category
      ORDER BY total DESC
    ''', ['$year%']);
    Map<String, double> result = {};
    for (var m in maps) {
      result[m['category'] as String] = (m['total'] as num).toDouble();
    }
    return result;
  }

  /// Monthly expense list for year bar chart
  Future<Map<int, double>> getMonthlyExpense(String year) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT substr(date, 6, 2) as month, SUM(amount) as total
      FROM transactions
      WHERE date LIKE ? AND type = 'expense'
      GROUP BY month
      ORDER BY month
    ''', ['$year%']);
    Map<int, double> result = {};
    for (int m = 1; m <= 12; m++) result[m] = 0;
    for (var m in maps) {
      final mon = int.tryParse(m['month'] as String) ?? 0;
      if (mon > 0) result[mon] = (m['total'] as num).toDouble();
    }
    return result;
  }

  Future<Map<int, double>> getMonthlyIncome(String year) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT substr(date, 6, 2) as month, SUM(amount) as total
      FROM transactions
      WHERE date LIKE ? AND type = 'income'
      GROUP BY month
      ORDER BY month
    ''', ['$year%']);
    Map<int, double> result = {};
    for (int m = 1; m <= 12; m++) result[m] = 0;
    for (var m in maps) {
      final mon = int.tryParse(m['month'] as String) ?? 0;
      if (mon > 0) result[mon] = (m['total'] as num).toDouble();
    }
    return result;
  }

  Future<List<Transaction>> searchTransactions(String keyword) async {
    final db = await database;
    final maps = await db.query('transactions',
        where: 'category LIKE ? OR note LIKE ?',
        whereArgs: ['%$keyword%', '%$keyword%'],
        orderBy: 'date DESC');
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  /// 日期区间搜索：支持关键词 + 起止日期筛选
  /// [startDate]/[endDate] 为 null 时表示不限制该边界
  Future<List<Transaction>> searchTransactionsByDateRange({
    String keyword = '',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <String>[];

    if (keyword.isNotEmpty) {
      conditions.add('(category LIKE ? OR note LIKE ?)');
      args.addAll(['%$keyword%', '%$keyword%']);
    }

    if (startDate != null) {
      conditions.add('date >= ?');
      args.add(startDate.toIso8601String().substring(0, 10));
    }

    if (endDate != null) {
      conditions.add('date <= ?');
      args.add(endDate.toIso8601String().substring(0, 10));
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final whereArgs = args.isNotEmpty ? args : null;

    final maps = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC, createdAt DESC',
    );
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<int> getTransactionCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM transactions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Transaction>> getAllTransactionsWithoutLimit() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'date DESC, createdAt DESC');
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<List<Budget>> getAllBudgets() async {
    final db = await database;
    final maps = await db.query('budgets', orderBy: 'month ASC');
    return maps.map((m) => Budget.fromMap(m)).toList();
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

  // === 同步相关 ===

  /// 获取未同步或待上传的交易
  Future<List<Transaction>> getUnsyncedTransactions() async {
    final db = await database;
    final maps = await db.query('transactions',
        where: 'syncStatus IS NULL OR syncStatus < 1',
        orderBy: 'updatedAt ASC');
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  /// 通过 remoteId 获取交易
  Future<Transaction?> getTransactionByRemoteId(String remoteId) async {
    final db = await database;
    final maps = await db.query('transactions',
        where: 'remoteId = ?', whereArgs: [remoteId], limit: 1);
    if (maps.isEmpty) return null;
    return Transaction.fromMap(maps.first);
  }

  /// 更新 remoteId 和同步状态
  Future<void> updateRemoteId(int localId, String remoteId, int syncStatus) async {
    final db = await database;
    await db.update('transactions',
        {'remoteId': remoteId, 'syncStatus': syncStatus, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [localId]);
  }

  /// 标记为已同步
  Future<void> markSynced(int? localId, int syncStatus) async {
    if (localId == null) return;
    final db = await database;
    await db.update('transactions',
        {'syncStatus': syncStatus},
        where: 'id = ?',
        whereArgs: [localId]);
  }

  /// 获取已删除的 remoteId 列表
  Future<Set<String>> getDeletedRemoteIds() async {
    final db = await database;
    final maps = await db.query('deleted_remote_ids');
    return maps.map((m) => m['remoteId'] as String).toSet();
  }

  /// 获取待同步删除的 remoteId
  Future<List<String>> getPendingDeleteRemoteIds() async {
    final db = await database;
    final maps = await db.query('deleted_remote_ids');
    return maps.map((m) => m['remoteId'] as String).toList();
  }

  /// 删除成功后清理本地记录
  Future<void> removeDeletedRemoteId(String remoteId) async {
    final db = await database;
    await db.delete('deleted_remote_ids',
        where: 'remoteId = ?', whereArgs: [remoteId]);
  }

  /// 获取所有已有 remoteId 的列表（用于去重）
  Future<Set<String>> getSyncedRemoteIds() async {
    final db = await database;
    final maps = await db.query('transactions',
        columns: ['remoteId'],
        where: 'remoteId IS NOT NULL AND remoteId != ""');
    return maps.where((m) => m['remoteId'] != null).map((m) => m['remoteId'] as String).toSet();
  }

  // ── 自定义分类 ──

  Future<List<Map<String, dynamic>>> getCustomCategories(String type) async {
    final db = await database;
    return await db.query('categories',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'sortOrder ASC, id ASC');
  }

  Future<int> addCustomCategory(String name, String icon, String type) async {
    final db = await database;
    return await db.insert('categories', {
      'name': name,
      'icon': icon,
      'type': type,
      'sortOrder': 0,
    });
  }

  Future<int> deleteCustomCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
