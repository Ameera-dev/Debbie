import 'dart:convert';

class TransactionItemModel {
  const TransactionItemModel({
    required this.id,
    required this.transactionId,
    required this.description,
    required this.amount,
    this.tags = const [],
    this.valueId,
    this.goalId,
    required this.createdAt,
  });

  final String id;
  final String transactionId;
  final String description;
  final int amount; // IDR integer
  final List<String> tags;
  final String? valueId;
  final String? goalId;
  final DateTime createdAt;

  bool get hasTags => tags.isNotEmpty;

  TransactionItemModel copyWith({
    String? id,
    String? transactionId,
    String? description,
    int? amount,
    List<String>? tags,
    String? valueId,
    String? goalId,
    DateTime? createdAt,
    bool clearValueId = false,
    bool clearGoalId = false,
  }) {
    return TransactionItemModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      tags: tags ?? this.tags,
      valueId: clearValueId ? null : (valueId ?? this.valueId),
      goalId: clearGoalId ? null : (goalId ?? this.goalId),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'description': description,
      'amount': amount,
      'tags': tags.isEmpty ? null : jsonEncode(tags),
      'value_id': valueId,
      'goal_id': goalId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionItemModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = const [];
    final rawTags = map['tags'];
    if (rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) parsedTags = decoded.whereType<String>().toList();
      } catch (_) {
        parsedTags = [rawTags];
      }
    }
    return TransactionItemModel(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      description: map['description'] as String,
      amount: map['amount'] as int,
      tags: parsedTags,
      valueId: map['value_id'] as String?,
      goalId: map['goal_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TransactionItemModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
