import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/value_model.dart';
import '../../../shared/constants/default_tags.dart';

// ---------------------------------------------------------------------------
// Filter state
// ---------------------------------------------------------------------------

enum DateFilter { all, thisWeek, thisMonth, custom }

enum TypeFilter { all, income, expense }

class TransactionFilters {
  const TransactionFilters({
    this.dateFilter = DateFilter.all,
    this.typeFilter = TypeFilter.all,
    this.valueId,
    this.tags = const {},
    this.search = '',
    this.customFrom,
    this.customTo,
    this.selectedDay,
  });

  final DateFilter dateFilter;
  final TypeFilter typeFilter;
  final String? valueId;
  final Set<String> tags;
  final String search;
  final DateTime? customFrom;
  final DateTime? customTo;
  final DateTime? selectedDay; // for calendar day tap

  int get activeCount {
    int count = 0;
    if (dateFilter != DateFilter.all) count++;
    if (typeFilter != TypeFilter.all) count++;
    if (valueId != null) count++;
    if (tags.isNotEmpty) count += tags.length;
    if (search.isNotEmpty) count++;
    if (selectedDay != null) count++;
    return count;
  }

  bool get isActive => activeCount > 0;

  TransactionFilters copyWith({
    DateFilter? dateFilter,
    TypeFilter? typeFilter,
    String? valueId,
    Set<String>? tags,
    String? search,
    DateTime? customFrom,
    DateTime? customTo,
    DateTime? selectedDay,
    bool clearValueId = false,
    bool clearCustom = false,
    bool clearTags = false,
    bool clearSelectedDay = false,
  }) {
    return TransactionFilters(
      dateFilter: dateFilter ?? this.dateFilter,
      typeFilter: typeFilter ?? this.typeFilter,
      valueId: clearValueId ? null : (valueId ?? this.valueId),
      tags: clearTags ? const {} : (tags ?? this.tags),
      search: search ?? this.search,
      customFrom: clearCustom ? null : (customFrom ?? this.customFrom),
      customTo: clearCustom ? null : (customTo ?? this.customTo),
      selectedDay: clearSelectedDay ? null : (selectedDay ?? this.selectedDay),
    );
  }

  TransactionFilters toggleTag(String tag) {
    final newTags = Set<String>.from(tags);
    if (newTags.contains(tag)) {
      newTags.remove(tag);
    } else {
      newTags.add(tag);
    }
    return copyWith(tags: newTags);
  }

  static const empty = TransactionFilters();

  /// Returns the effective date range based on the current filter.
  (DateTime?, DateTime?) get dateRange {
    final now = DateTime.now();
    // If a specific day is selected from calendar, use it
    if (selectedDay != null) {
      return (
        DateTime(selectedDay!.year, selectedDay!.month, selectedDay!.day),
        DateTime(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          23,
          59,
          59,
        ),
      );
    }
    switch (dateFilter) {
      case DateFilter.all:
        return (null, null);
      case DateFilter.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return (DateTime(weekStart.year, weekStart.month, weekStart.day), now);
      case DateFilter.thisMonth:
        return (DateTime(now.year, now.month, 1), now);
      case DateFilter.custom:
        return (customFrom, customTo);
    }
  }

  /// Returns 'income', 'expense', or null (all).
  String? get typeString {
    switch (typeFilter) {
      case TypeFilter.all:
        return null;
      case TypeFilter.income:
        return 'income';
      case TypeFilter.expense:
        return 'expense';
    }
  }
}

// ---------------------------------------------------------------------------
// Filter bar — compact, visually polished
// ---------------------------------------------------------------------------

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.filters,
    required this.values,
    required this.onChanged,
    required this.onSearchTap,
  });

  final TransactionFilters filters;
  final List<ValueModel> values;
  final ValueChanged<TransactionFilters> onChanged;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    // Determine which tag categories to show based on type filter
    final List<TagCategory> tagCategories;
    switch (filters.typeFilter) {
      case TypeFilter.expense:
        tagCategories = DefaultTags.expenseCategories;
      case TypeFilter.income:
        tagCategories = DefaultTags.incomeCategories;
      case TypeFilter.all:
        tagCategories = [
          ...DefaultTags.expenseCategories,
          ...DefaultTags.incomeCategories,
        ];
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Row 1: type toggle + value pills + search ───────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Search
              _PillButton(
                icon: Icons.search,
                selected: filters.search.isNotEmpty,
                onTap: onSearchTap,
              ),
              const SizedBox(width: 6),

              // Clear all (only when filters active)
              if (filters.isActive) ...[
                _PillButton(
                  icon: Icons.close,
                  label: '${filters.activeCount}',
                  selected: true,
                  color: AppColors.expense,
                  onTap: () => onChanged(TransactionFilters.empty),
                ),
                const SizedBox(width: 6),
                _VerticalDivider(),
                const SizedBox(width: 6),
              ],

              // Type toggle pills
              _TypePill(
                label: 'All',
                selected: filters.typeFilter == TypeFilter.all,
                onTap: () =>
                    onChanged(filters.copyWith(typeFilter: TypeFilter.all)),
              ),
              const SizedBox(width: 4),
              _TypePill(
                label: 'Expense',
                selected: filters.typeFilter == TypeFilter.expense,
                color: AppColors.expense,
                onTap: () =>
                    onChanged(filters.copyWith(typeFilter: TypeFilter.expense)),
              ),
              const SizedBox(width: 4),
              _TypePill(
                label: 'Income',
                selected: filters.typeFilter == TypeFilter.income,
                color: AppColors.income,
                onTap: () =>
                    onChanged(filters.copyWith(typeFilter: TypeFilter.income)),
              ),

              // Values (pill with colored dot)
              if (values.isNotEmpty) ...[
                _VerticalDivider(),
                ...values.map((v) {
                  final color = AppColors.fromHex(v.color);
                  final selected = filters.valueId == v.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _ValuePill(
                      value: v,
                      color: color,
                      selected: selected,
                      onTap: () {
                        if (selected) {
                          onChanged(filters.copyWith(clearValueId: true));
                        } else {
                          onChanged(filters.copyWith(valueId: v.id));
                        }
                      },
                    ),
                  );
                }),
              ],
            ],
          ),
        ),

        // ── Row 2: tag category pills ─────────────────────────────
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: tagCategories.map((cat) {
              final catTagsSelected = cat.tags
                  .where((t) => filters.tags.contains(t))
                  .toSet();
              final isSelected = catTagsSelected.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _TagCategoryPill(
                  category: cat,
                  selectedCount: catTagsSelected.length,
                  isSelected: isSelected,
                  onTap: () => _showTagPicker(context, cat),
                  onClear: isSelected
                      ? () {
                          final newTags = Set<String>.from(filters.tags);
                          newTags.removeAll(cat.tags);
                          onChanged(filters.copyWith(tags: newTags));
                        }
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showTagPicker(BuildContext context, TagCategory category) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TagPickerSheet(
        category: category,
        selectedTags: filters.tags,
        onChanged: (newTags) {
          onChanged(filters.copyWith(tags: newTags));
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tag picker bottom sheet
// ---------------------------------------------------------------------------

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({
    required this.category,
    required this.selectedTags,
    required this.onChanged,
  });

  final TagCategory category;
  final Set<String> selectedTags;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(widget.category.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                widget.category.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => widget.onChanged(_selected),
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.category.tags.map((tag) {
              final isSelected = _selected.contains(tag);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selected.remove(tag);
                    } else {
                      _selected.add(tag);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(
                          Icons.check,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        tag,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pill widgets
// ---------------------------------------------------------------------------

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String? label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? c : AppColors.textSecondary),
            if (label != null) ...[
              const SizedBox(width: 3),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? c : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final ValueModel value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Colored dot indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              value.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagCategoryPill extends StatelessWidget {
  const _TagCategoryPill({
    required this.category,
    required this.selectedCount,
    required this.isSelected,
    required this.onTap,
    this.onClear,
  });

  final TagCategory category;
  final int selectedCount;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$selectedCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close,
                  size: 13,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(width: 1, height: 20, color: AppColors.divider),
    );
  }
}
