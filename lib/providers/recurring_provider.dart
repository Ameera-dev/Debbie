import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/recurring_expense_model.dart';
import '../data/models/recurring_expense_payment_model.dart';
import '../data/models/recurring_payment_history_entry_model.dart';
import '../data/models/transaction_item_model.dart';
import '../data/models/transaction_model.dart';
import '../shared/utils/date_utils.dart';
import '../shared/utils/id_generator.dart';
import 'database_provider.dart';
import 'transactions_provider.dart';

// ---------------------------------------------------------------------------
// Recurring expenses list
// ---------------------------------------------------------------------------

final recurringExpensesProvider =
    AsyncNotifierProvider<
      RecurringExpensesNotifier,
      List<RecurringExpenseModel>
    >(RecurringExpensesNotifier.new);

class RecurringExpensesNotifier
    extends AsyncNotifier<List<RecurringExpenseModel>> {
  @override
  Future<List<RecurringExpenseModel>> build() {
    return ref.watch(recurringExpensesRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(recurringExpensesRepositoryProvider).getAll(),
    );
  }

  Future<void> add(RecurringExpenseModel expense) async {
    await ref.read(recurringExpensesRepositoryProvider).insert(expense);
    await refresh();
    // recurringMonthSummaryProvider reacts automatically via ref.watch
  }

  Future<void> edit(RecurringExpenseModel expense) async {
    await ref.read(recurringExpensesRepositoryProvider).update(expense);
    ref.invalidate(recurringPaymentHistoryProvider);
    await refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(recurringExpensesRepositoryProvider).delete(id);
    ref.invalidate(recurringPaymentsProvider);
    ref.invalidate(recurringPaymentHistoryProvider);
    await refresh();
  }

  /// Mark an expense as paid: creates a real transaction + records payment.
  Future<void> markAsPaid(RecurringExpenseModel expense) async {
    final month = AppDateUtils.currentMonthKey();
    final now = DateTime.now();
    final txId = IdGenerator.generate();
    final itemId = IdGenerator.generate();
    final paymentId = IdGenerator.generate();

    final transaction = TransactionModel(
      id: txId,
      type: 'expense',
      date: now,
      status: TransactionModel.recordedStatus,
      title: expense.name,
      notes: expense.notes,
      createdAt: now,
    );

    final item = TransactionItemModel(
      id: itemId,
      transactionId: txId,
      description: expense.name,
      amount: expense.amount,
      tags: expense.category != null ? [expense.category!] : [],
      valueId: expense.valueId,
      goalId: expense.goalId,
      createdAt: now,
    );

    final payment = RecurringExpensePaymentModel(
      id: paymentId,
      recurringExpenseId: expense.id,
      month: month,
      transactionId: txId,
      paidAt: now,
    );

    await ref
        .read(recurringExpensesRepositoryProvider)
        .markAsPaid(transaction: transaction, item: item, payment: payment);

    ref.invalidate(transactionsProvider);
    ref.invalidate(recurringPaymentsProvider);
    ref.invalidate(recurringPaymentHistoryProvider);
    // recurringMonthSummaryProvider reacts automatically via ref.watch
  }

  /// Undo a payment for the current month (does NOT delete the transaction).
  Future<void> unmarkAsPaid(String expenseId) async {
    final month = AppDateUtils.currentMonthKey();
    await ref
        .read(recurringExpensesRepositoryProvider)
        .deletePayment(expenseId, month);
    ref.invalidate(recurringPaymentsProvider);
    ref.invalidate(recurringPaymentHistoryProvider);
  }
}

// ---------------------------------------------------------------------------
// Payments for current month
// ---------------------------------------------------------------------------

final recurringPaymentsProvider =
    FutureProvider<List<RecurringExpensePaymentModel>>((ref) {
      final month = AppDateUtils.currentMonthKey();
      return ref
          .read(recurringExpensesRepositoryProvider)
          .getPaymentsForMonth(month);
    });

final recurringPaymentHistoryProvider =
    FutureProvider<List<RecurringPaymentHistoryEntryModel>>((ref) {
      return ref.read(recurringExpensesRepositoryProvider).getPaymentHistory();
    });

// ---------------------------------------------------------------------------
// Month summary: total commitment, paid total, counts
// ---------------------------------------------------------------------------

class RecurringMonthSummary {
  const RecurringMonthSummary({
    required this.totalCommitment,
    required this.paidTotal,
    required this.totalCount,
    required this.paidCount,
  });

  final int totalCommitment;
  final int paidTotal;
  final int totalCount;
  final int paidCount;

  int get remainingTotal => totalCommitment - paidTotal;
  int get unpaidCount => totalCount - paidCount;
  double get progressFraction =>
      totalCommitment == 0 ? 0 : paidTotal / totalCommitment;
}

final recurringMonthSummaryProvider = FutureProvider<RecurringMonthSummary>((
  ref,
) async {
  ref.watch(recurringExpensesProvider);
  ref.watch(recurringPaymentsProvider);

  final month = AppDateUtils.currentMonthKey();
  final repo = ref.read(recurringExpensesRepositoryProvider);

  final expenses = await repo.getAll();
  final payments = await repo.getPaymentsForMonth(month);

  final paymentSet = payments.map((p) => p.recurringExpenseId).toSet();
  final paidExpenses = expenses.where((e) => paymentSet.contains(e.id));
  final total = expenses.fold(0, (sum, e) => sum + e.amount);
  final paid = paidExpenses.fold(0, (sum, e) => sum + e.amount);

  return RecurringMonthSummary(
    totalCommitment: total,
    paidTotal: paid,
    totalCount: expenses.length,
    paidCount: paidExpenses.length,
  );
});
