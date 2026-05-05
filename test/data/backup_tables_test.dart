import 'package:debbie/data/database/tables.dart';
import 'package:test/test.dart';

void main() {
  test('backup tables cover every persisted user-data table', () {
    expect(Tables.backupTables.toSet(), {
      Tables.userValues,
      Tables.valuesPlan,
      Tables.goals,
      Tables.transactions,
      Tables.transactionItems,
      Tables.transactionImages,
      Tables.journal,
      Tables.dailyIntentions,
      Tables.weeklyBudgetPlans,
      Tables.settings,
      Tables.aiReflections,
      Tables.recurringExpenses,
      Tables.recurringExpensePayments,
    });
  });

  test('restore orders match the backup table set', () {
    expect(Tables.restoreDeleteOrder.toSet(), Tables.backupTables.toSet());
    expect(Tables.restoreInsertOrder.toSet(), Tables.backupTables.toSet());
  });
}
