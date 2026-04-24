import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/value_model.dart';
import '../../../shared/utils/currency.dart';

/// Compact card for an active Impact Goal, used in a horizontal list.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.value});

  final GoalModel goal;
  final ValueModel? value;

  @override
  Widget build(BuildContext context) {
    final progress = goal.progressPercent;
    final color = value != null
        ? AppColors.fromHex(value!.color)
        : AppColors.primary;
    final percentText = progress != null
        ? '${(progress * 100).round()}%'
        : null;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            goal.title,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (value != null)
            Row(
              children: [
                Text(value!.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    value!.name,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const Spacer(),
          if (goal.targetAmount != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  CurrencyUtils.format(goal.currentAmount),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
                if (percentText != null)
                  Text(
                    percentText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress ?? 0,
                backgroundColor: AppColors.divider,
                color: color,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'of ${CurrencyUtils.format(goal.targetAmount!)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ] else
            Text(
              CurrencyUtils.format(goal.currentAmount),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFamily: 'JetBrains Mono',
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}
