class ValuesPlanModel {
  const ValuesPlanModel({
    required this.id,
    required this.valueId,
    required this.amount,
    required this.month,
  });

  final String id;
  final String valueId;
  final int amount; // IDR integer
  final String month; // "2025-07"

  ValuesPlanModel copyWith({
    String? id,
    String? valueId,
    int? amount,
    String? month,
  }) {
    return ValuesPlanModel(
      id: id ?? this.id,
      valueId: valueId ?? this.valueId,
      amount: amount ?? this.amount,
      month: month ?? this.month,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'value_id': valueId, 'amount': amount, 'month': month};
  }

  factory ValuesPlanModel.fromMap(Map<String, dynamic> map) {
    return ValuesPlanModel(
      id: map['id'] as String,
      valueId: map['value_id'] as String,
      amount: map['amount'] as int,
      month: map['month'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ValuesPlanModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
