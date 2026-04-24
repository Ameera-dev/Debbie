class AiReflectionModel {
  const AiReflectionModel({
    required this.id,
    required this.type, // 'weekly' | 'monthly'
    required this.content,
    this.contextSummary,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String content;
  final String? contextSummary; // e.g. "Top value: Family, Rp 2.500.000"
  final DateTime date;
  final DateTime createdAt;

  AiReflectionModel copyWith({
    String? id,
    String? type,
    String? content,
    String? contextSummary,
    DateTime? date,
    DateTime? createdAt,
    bool clearContextSummary = false,
  }) {
    return AiReflectionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      contextSummary: clearContextSummary
          ? null
          : (contextSummary ?? this.contextSummary),
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'content': content,
      'context_summary': contextSummary,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AiReflectionModel.fromMap(Map<String, dynamic> map) {
    return AiReflectionModel(
      id: map['id'] as String,
      type: map['type'] as String,
      content: map['content'] as String,
      contextSummary: map['context_summary'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AiReflectionModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
