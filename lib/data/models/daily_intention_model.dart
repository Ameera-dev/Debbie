class DailyIntentionModel {
  const DailyIntentionModel({
    required this.id,
    required this.date,
    required this.valueId,
    this.reflection,
    required this.createdAt,
    this.reflectedAt,
  });

  final String id;
  final DateTime date;
  final String valueId;
  final String? reflection;
  final DateTime createdAt;
  final DateTime? reflectedAt;

  bool get hasReflection => reflection?.trim().isNotEmpty == true;

  DailyIntentionModel copyWith({
    String? id,
    DateTime? date,
    String? valueId,
    String? reflection,
    DateTime? createdAt,
    DateTime? reflectedAt,
    bool clearReflection = false,
    bool clearReflectedAt = false,
  }) {
    return DailyIntentionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      valueId: valueId ?? this.valueId,
      reflection: clearReflection ? null : (reflection ?? this.reflection),
      createdAt: createdAt ?? this.createdAt,
      reflectedAt: clearReflectedAt ? null : (reflectedAt ?? this.reflectedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'value_id': valueId,
      'reflection': reflection,
      'created_at': createdAt.toIso8601String(),
      'reflected_at': reflectedAt?.toIso8601String(),
    };
  }

  factory DailyIntentionModel.fromMap(Map<String, dynamic> map) {
    return DailyIntentionModel(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      valueId: map['value_id'] as String,
      reflection: map['reflection'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      reflectedAt: (map['reflected_at'] as String?) != null
          ? DateTime.parse(map['reflected_at'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DailyIntentionModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
