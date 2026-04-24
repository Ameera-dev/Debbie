import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/value_model.dart';
import '../../../shared/constants/default_values.dart';
import '../../../shared/utils/currency.dart';

class PlanSlider extends StatelessWidget {
  const PlanSlider({
    super.key,
    required this.value,
    required this.amount,
    required this.maxAmount,
    required this.onChanged,
  });

  final ValueModel value;
  final int amount;
  final int maxAmount;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromHex(value.color);
    final pct = maxAmount > 0 ? amount / maxAmount : 0.0;
    final pctStr = maxAmount > 0 ? '${(pct * 100).toStringAsFixed(0)}%' : '';

    // Get the suggested percentage for this value
    final preset = DefaultValues.presets.firstWhere(
      (p) => p['name'] == value.name,
      orElse: () => {},
    );
    final suggestion = preset['suggestion'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(value.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (suggestion != null)
                        Text(
                          'Suggested: $suggestion',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyUtils.format(amount),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                    if (pctStr.isNotEmpty)
                      Text(
                        pctStr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.15),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.1),
                trackHeight: 4,
              ),
              child: Slider(
                value: pct.clamp(0.0, 1.0),
                onChanged: onChanged != null
                    ? (v) => onChanged!((v * maxAmount).round())
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
