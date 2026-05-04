class WeeklyBudgetPlanModel {
  const WeeklyBudgetPlanModel({
    required this.id,
    required this.date,
    required this.plannedAmount,
    this.actualAmount,
    this.notes,
    this.actualizedAt,
    required this.createdAt,
  });

  final String id;
  final DateTime date;
  final int plannedAmount;
  final int? actualAmount;
  final String? notes;
  final DateTime? actualizedAt;
  final DateTime createdAt;

  bool get isActualized => actualAmount != null;

  int? get difference =>
      actualAmount == null ? null : plannedAmount - actualAmount!;

  double? get performancePercent {
    if (plannedAmount <= 0 || actualAmount == null) return null;
    return ((plannedAmount - actualAmount!) / plannedAmount) * 100;
  }

  WeeklyBudgetPlanModel copyWith({
    String? id,
    DateTime? date,
    int? plannedAmount,
    int? actualAmount,
    String? notes,
    DateTime? actualizedAt,
    DateTime? createdAt,
    bool clearActual = false,
    bool clearNotes = false,
  }) {
    return WeeklyBudgetPlanModel(
      id: id ?? this.id,
      date: date ?? this.date,
      plannedAmount: plannedAmount ?? this.plannedAmount,
      actualAmount: clearActual ? null : (actualAmount ?? this.actualAmount),
      notes: clearNotes ? null : (notes ?? this.notes),
      actualizedAt: clearActual ? null : (actualizedAt ?? this.actualizedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plan_date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'planned_amount': plannedAmount,
      'actual_amount': actualAmount,
      'notes': notes,
      'actualized_at': actualizedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WeeklyBudgetPlanModel.fromMap(Map<String, dynamic> map) {
    return WeeklyBudgetPlanModel(
      id: map['id'] as String,
      date: DateTime.parse(map['plan_date'] as String),
      plannedAmount: map['planned_amount'] as int,
      actualAmount: map['actual_amount'] as int?,
      notes: map['notes'] as String?,
      actualizedAt: (map['actualized_at'] as String?) != null
          ? DateTime.parse(map['actualized_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
