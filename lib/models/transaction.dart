class Transaction {
  final int? id;
  final String type; // 'income' or 'expense'
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final String account; // which account
  final DateTime createdAt;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note = '',
    required this.date,
    this.account = '默认',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'account': account,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'],
        type: map['type'],
        amount: map['amount'],
        category: map['category'],
        note: map['note'] ?? '',
        date: DateTime.parse(map['date']),
        account: map['account'] ?? '默认',
        createdAt: DateTime.parse(map['createdAt'] ?? map['date']),
      );

  Transaction copyWith({
    int? id,
    String? type,
    double? amount,
    String? category,
    String? note,
    DateTime? date,
    String? account,
  }) =>
      Transaction(
        id: id ?? this.id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        note: note ?? this.note,
        date: date ?? this.date,
        account: account ?? this.account,
        createdAt: createdAt,
      );
}

class AccountModel {
  final int? id;
  final String name;
  final String icon;
  final double balance;
  final String type; // 'asset', 'debt', 'reimbursement'

  AccountModel({
    this.id,
    required this.name,
    this.icon = 'wallet',
    this.balance = 0.0,
    this.type = 'asset',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'balance': balance,
        'type': type,
      };

  factory AccountModel.fromMap(Map<String, dynamic> map) => AccountModel(
        id: map['id'],
        name: map['name'],
        icon: map['icon'] ?? 'wallet',
        balance: (map['balance'] ?? 0.0).toDouble(),
        type: map['type'] ?? 'asset',
      );
}

class Budget {
  final int? id;
  final double amount;
  final String month; // '2026-06'

  Budget({this.id, required this.amount, required this.month});

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'month': month,
      };

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        id: map['id'],
        amount: (map['amount'] ?? 0.0).toDouble(),
        month: map['month'],
      );
}
