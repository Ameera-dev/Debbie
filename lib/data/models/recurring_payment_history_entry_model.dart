import 'recurring_expense_model.dart';

class RecurringPaymentHistoryEntryModel {
  const RecurringPaymentHistoryEntryModel({
    required this.paymentId,
    required this.recurringExpenseId,
    required this.expenseName,
    required this.amount,
    required this.month,
    this.transactionId,
    required this.paidAt,
    this.category,
    this.valueId,
    this.dueDay,
    this.payType = RecurringExpenseModel.payTypeManual,
  });

  final String paymentId;
  final String recurringExpenseId;
  final String expenseName;
  final int amount;
  final String month; // "2026-04"
  final String? transactionId;
  final DateTime paidAt;
  final String? category;
  final String? valueId;
  final int? dueDay;
  final String payType;

  bool get isAutoDeducted => payType == RecurringExpenseModel.payTypeAuto;

  factory RecurringPaymentHistoryEntryModel.fromMap(Map<String, dynamic> map) {
    return RecurringPaymentHistoryEntryModel(
      paymentId: map['payment_id'] as String,
      recurringExpenseId: map['recurring_expense_id'] as String,
      expenseName: map['expense_name'] as String,
      amount: map['amount'] as int,
      month: map['month'] as String,
      transactionId: map['transaction_id'] as String?,
      paidAt: DateTime.parse(map['paid_at'] as String),
      category: map['category'] as String?,
      valueId: map['value_id'] as String?,
      dueDay: map['due_day'] as int?,
      payType:
          map['pay_type'] as String? ?? RecurringExpenseModel.payTypeManual,
    );
  }
}
