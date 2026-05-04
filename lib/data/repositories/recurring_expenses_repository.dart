import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/recurring_expense_model.dart';
import '../models/recurring_expense_payment_model.dart';
import '../models/transaction_item_model.dart';
import '../models/transaction_model.dart';

class RecurringExpensesRepository {
  const RecurringExpensesRepository(this._db);

  final DatabaseHelper _db;

  // ---------------------------------------------------------------------------
  // Recurring expense CRUD
  // ---------------------------------------------------------------------------

  Future<List<RecurringExpenseModel>> getAll({bool activeOnly = true}) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.recurringExpenses,
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'due_day ASC, name ASC',
    );
    return rows.map(RecurringExpenseModel.fromMap).toList();
  }

  Future<RecurringExpenseModel?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.recurringExpenses,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RecurringExpenseModel.fromMap(rows.first);
  }

  Future<void> insert(RecurringExpenseModel expense) async {
    final db = await _db.database;
    await db.insert(
      Tables.recurringExpenses,
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(RecurringExpenseModel expense) async {
    final db = await _db.database;
    await db.update(
      Tables.recurringExpenses,
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    // Payments cascade-delete via FK ON DELETE CASCADE
    await db.delete(
      Tables.recurringExpenses,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Payment operations
  // ---------------------------------------------------------------------------

  Future<List<RecurringExpensePaymentModel>> getPaymentsForMonth(
    String month,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.recurringExpensePayments,
      where: 'month = ?',
      whereArgs: [month],
    );
    return rows.map(RecurringExpensePaymentModel.fromMap).toList();
  }

  Future<RecurringExpensePaymentModel?> getPaymentForMonth(
    String expenseId,
    String month,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.recurringExpensePayments,
      where: 'recurring_expense_id = ? AND month = ?',
      whereArgs: [expenseId, month],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RecurringExpensePaymentModel.fromMap(rows.first);
  }

  /// Records a payment AND inserts a real transaction atomically.
  Future<void> markAsPaid({
    required RecurringExpensePaymentModel payment,
    required TransactionModel transaction,
    required TransactionItemModel item,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        Tables.transactions,
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        Tables.transactionItems,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        Tables.recurringExpensePayments,
        payment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deletePayment(String expenseId, String month) async {
    final db = await _db.database;
    await db.delete(
      Tables.recurringExpensePayments,
      where: 'recurring_expense_id = ? AND month = ?',
      whereArgs: [expenseId, month],
    );
  }

  // ---------------------------------------------------------------------------
  // Aggregates
  // ---------------------------------------------------------------------------

  /// Sum of all active recurring expense amounts (monthly commitment total).
  Future<int> getTotalCommitment() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM ${Tables.recurringExpenses} WHERE is_active = 1',
    );
    return rows.first['total'] as int? ?? 0;
  }

  /// Sum of amounts for expenses paid in the given month.
  Future<int> getPaidTotalForMonth(String month) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(re.amount), 0) AS total
      FROM ${Tables.recurringExpensePayments} rep
      JOIN ${Tables.recurringExpenses} re ON re.id = rep.recurring_expense_id
      WHERE rep.month = ?
      ''',
      [month],
    );
    return rows.first['total'] as int? ?? 0;
  }

  /// All recurring expenses + their payment status for a given month.
  Future<List<(RecurringExpenseModel, RecurringExpensePaymentModel?)>>
  getWithPaymentStatus(String month) async {
    final expenses = await getAll();
    final payments = await getPaymentsForMonth(month);
    final paymentMap = {for (final p in payments) p.recurringExpenseId: p};
    return expenses.map((e) => (e, paymentMap[e.id])).toList();
  }

  // ---------------------------------------------------------------------------
  // Backup helpers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> exportExpenses() async {
    final db = await _db.database;
    return db.query(Tables.recurringExpenses);
  }

  Future<List<Map<String, dynamic>>> exportPayments() async {
    final db = await _db.database;
    return db.query(Tables.recurringExpensePayments);
  }

  Future<void> importExpenses(List<Map<String, dynamic>> rows) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        Tables.recurringExpenses,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> importPayments(List<Map<String, dynamic>> rows) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        Tables.recurringExpensePayments,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
