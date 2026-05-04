class RecurringExpenseModel {
  const RecurringExpenseModel({
    required this.id,
    required this.name,
    required this.amount,
    this.category,
    this.notes,
    this.valueId,
    this.goalId,
    this.dueDay,
    this.payType = 'manual',
    this.isActive = true,
    required this.createdAt,
  });

  static const payTypeManual = 'manual';
  static const payTypeAuto = 'auto';

  final String id;
  final String name;
  final int amount;
  final String? category;
  final String? notes;
  final String? valueId;
  final String? goalId;
  final int? dueDay; // 1–31
  final String payType;
  final bool isActive;
  final DateTime createdAt;

  bool get isManual => payType == payTypeManual;
  bool get isAutoDeducted => payType == payTypeAuto;

  /// Returns how many days until due this month (negative = overdue).
  int? dueDaysFromNow() {
    if (dueDay == null) return null;
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, dueDay!);
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  RecurringExpenseModel copyWith({
    String? id,
    String? name,
    int? amount,
    String? category,
    String? notes,
    String? valueId,
    String? goalId,
    int? dueDay,
    String? payType,
    bool? isActive,
    DateTime? createdAt,
    bool clearCategory = false,
    bool clearNotes = false,
    bool clearValueId = false,
    bool clearGoalId = false,
    bool clearDueDay = false,
  }) {
    return RecurringExpenseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      category: clearCategory ? null : (category ?? this.category),
      notes: clearNotes ? null : (notes ?? this.notes),
      valueId: clearValueId ? null : (valueId ?? this.valueId),
      goalId: clearGoalId ? null : (goalId ?? this.goalId),
      dueDay: clearDueDay ? null : (dueDay ?? this.dueDay),
      payType: payType ?? this.payType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'category': category,
      'notes': notes,
      'value_id': valueId,
      'goal_id': goalId,
      'due_day': dueDay,
      'pay_type': payType,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RecurringExpenseModel.fromMap(Map<String, dynamic> map) {
    return RecurringExpenseModel(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: map['amount'] as int,
      category: map['category'] as String?,
      notes: map['notes'] as String?,
      valueId: map['value_id'] as String?,
      goalId: map['goal_id'] as String?,
      dueDay: map['due_day'] as int?,
      payType: map['pay_type'] as String? ?? payTypeManual,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringExpenseModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
