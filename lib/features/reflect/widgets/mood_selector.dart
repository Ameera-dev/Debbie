import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class MoodSelector extends StatelessWidget {
  const MoodSelector({
    super.key,
    required this.selectedMood,
    required this.onChanged,
  });

  final String? selectedMood;
  final ValueChanged<String?> onChanged;

  static const _moods = [
    ('grateful', '🙏', 'Grateful'),
    ('reflective', '🌊', 'Reflective'),
    ('uncertain', '🌫️', 'Uncertain'),
    ('motivated', '⚡', 'Motivated'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _moods.map((mood) {
        final (id, emoji, label) = mood;
        final selected = selectedMood == id;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(selected ? null : id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
