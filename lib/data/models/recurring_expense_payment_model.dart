class RecurringExpensePaymentModel {
  const RecurringExpensePaymentModel({
    required this.id,
    required this.recurringExpenseId,
    required this.month,
    this.transactionId,
    required this.paidAt,
  });

  final String id;
  final String recurringExpenseId;
  final String month; // "2026-04"
  final String? transactionId;
  final DateTime paidAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recurring_expense_id': recurringExpenseId,
      'month': month,
      'transaction_id': transactionId,
      'paid_at': paidAt.toIso8601String(),
    };
  }

  factory RecurringExpensePaymentModel.fromMap(Map<String, dynamic> map) {
    return RecurringExpensePaymentModel(
      id: map['id'] as String,
      recurringExpenseId: map['recurring_expense_id'] as String,
      month: map['month'] as String,
      transactionId: map['transaction_id'] as String?,
      paidAt: DateTime.parse(map['paid_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringExpensePaymentModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
