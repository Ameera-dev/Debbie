import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/value_model.dart';
import '../../../shared/constants/default_values.dart';

class ValueCard extends StatelessWidget {
  const ValueCard({
    super.key,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  final ValueModel value;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromHex(value.color);
    final preset = DefaultValues.presets.firstWhere(
      (p) => p['name'] == value.name,
      orElse: () => {'description': '', 'detail': ''},
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showDetail(context, preset, color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: (MediaQuery.of(context).size.width - 48) / 2,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value.icon, style: const TextStyle(fontSize: 28)),
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isSelected ? color : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              preset['description'] ?? '',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(
    BuildContext context,
    Map<String, String> preset,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(value.icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Text(
                  value.name,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              preset['description'] ?? '',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              preset['detail'] ?? '',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    'Suggested: ${preset['suggestion'] ?? '5–10%'} of income',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
