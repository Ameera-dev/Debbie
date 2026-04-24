import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/utils/currency.dart';

/// Compact card showing Income | Expenses | Balance for current month.
class MonthlySnapshot extends StatelessWidget {
  const MonthlySnapshot({
    super.key,
    required this.income,
    required this.expenses,
  });

  final int income;
  final int expenses;

  int get balance => income - expenses;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly snapshot',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Item(
                    label: 'Income',
                    amount: income,
                    color: AppColors.income,
                  ),
                ),
                Expanded(
                  child: _Item(
                    label: 'Expenses',
                    amount: expenses,
                    color: AppColors.expense,
                  ),
                ),
                Expanded(
                  child: _Item(
                    label: 'Balance',
                    amount: balance,
                    color: balance >= 0 ? AppColors.income : AppColors.expense,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.label, required this.amount, required this.color});

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyUtils.format(amount),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontFamily: 'JetBrains Mono',
          ),
        ),
      ],
    );
  }
}
