class GoalModel {
  const GoalModel({
    required this.id,
    required this.title,
    required this.valueId,
    this.targetAmount,
    required this.currentAmount,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String valueId;
  final int? targetAmount; // IDR integer, nullable
  final int currentAmount; // IDR integer
  final String status; // 'active' | 'completed' | 'paused'
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  double? get progressPercent => targetAmount != null && targetAmount! > 0
      ? (currentAmount / targetAmount!).clamp(0.0, 1.0)
      : null;

  GoalModel copyWith({
    String? id,
    String? title,
    String? valueId,
    int? targetAmount,
    int? currentAmount,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool clearTargetAmount = false,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      valueId: valueId ?? this.valueId,
      targetAmount: clearTargetAmount
          ? null
          : (targetAmount ?? this.targetAmount),
      currentAmount: currentAmount ?? this.currentAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'value_id': valueId,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as String,
      title: map['title'] as String,
      valueId: map['value_id'] as String,
      targetAmount: map['target_amount'] as int?,
      currentAmount: (map['current_amount'] as int?) ?? 0,
      status: (map['status'] as String?) ?? 'active',
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GoalModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
