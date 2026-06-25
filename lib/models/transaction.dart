class Transaction {
  final int? id;
  final String type; // 'income' or 'expense'
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final String account;
  final DateTime createdAt;
  final List<String> images;

  // 同步相关字段
  final String? remoteId; // Supabase 中的记录ID
  final DateTime updatedAt; // 最后修改时间
  final int syncStatus; // 0=未同步, 1=已同步, 2=待上传

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note = '',
    required this.date,
    this.account = '默认',
    DateTime? createdAt,
    List<String>? images,
    this.remoteId,
    DateTime? updatedAt,
    this.syncStatus = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        images = images ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  /// 转成 SQLite Map
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'account': account,
        'createdAt': createdAt.toIso8601String(),
        'images': images.join('|'),
        'remoteId': remoteId,
        'updatedAt': updatedAt.toIso8601String(),
        'syncStatus': syncStatus,
      };

  /// 从 SQLite Map 恢复
  factory Transaction.fromMap(Map<String, dynamic> map) {
    final imagesStr = map['images'] as String?;
    return Transaction(
      id: map['id'] is int ? map['id'] : null,
      type: map['type'],
      amount: (map['amount'] is int) ? (map['amount'] as int).toDouble() : map['amount'],
      category: map['category'],
      note: map['note'] ?? '',
      date: DateTime.parse(map['date']),
      account: map['account'] ?? '默认',
      createdAt: DateTime.parse(map['createdAt'] ?? map['date']),
      images: (imagesStr != null && imagesStr.isNotEmpty)
          ? imagesStr.split('|').where((s) => s.isNotEmpty).toList()
          : [],
      remoteId: map['remoteId'] as String?,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.parse(map['date']),
      syncStatus: map['syncStatus'] ?? 0,
    );
  }

  /// 转成 Supabase JSON（用于上传）
  Map<String, dynamic> toRemoteJson(String userId) => {
        if (remoteId != null) 'id': remoteId,
        'user_id': userId,
        'type': type,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'account': account,
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  /// 从 Supabase JSON 恢复
  factory Transaction.fromRemoteJson(Map<String, dynamic> json) {
    final imagesStr = json['images'] as String?;
    return Transaction(
      remoteId: json['id'] as String,
      type: json['type'],
      amount: (json['amount'] as num).toDouble(),
      category: json['category'],
      note: json['note'] ?? '',
      date: DateTime.parse(json['date']),
      account: json['account'] ?? '默认',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.parse(json['date']),
      images: (imagesStr != null && imagesStr.isNotEmpty)
          ? imagesStr.split('|').where((s) => s.isNotEmpty).toList()
          : [],
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      syncStatus: 1,
    );
  }

  Transaction copyWith({
    int? id,
    String? type,
    double? amount,
    String? category,
    String? note,
    DateTime? date,
    String? account,
    List<String>? images,
    String? remoteId,
    DateTime? updatedAt,
    int? syncStatus,
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
        images: images ?? this.images,
        remoteId: remoteId ?? this.remoteId,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

class AccountModel {
  final int? id;
  final String name;
  final String icon;
  final double balance;
  final String type;

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
  final String month;

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
