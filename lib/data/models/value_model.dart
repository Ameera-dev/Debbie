class ValueModel {
  const ValueModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.guardianText,
    required this.priority,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String icon;
  final String color; // hex string e.g. "#C4704B"
  final String? guardianText;
  final int priority;
  final DateTime createdAt;

  ValueModel copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    String? guardianText,
    int? priority,
    DateTime? createdAt,
    bool clearGuardianText = false,
  }) {
    return ValueModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      guardianText: clearGuardianText
          ? null
          : (guardianText ?? this.guardianText),
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'guardian_text': guardianText,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ValueModel.fromMap(Map<String, dynamic> map) {
    return ValueModel(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      guardianText: map['guardian_text'] as String?,
      priority: map['priority'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ValueModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
