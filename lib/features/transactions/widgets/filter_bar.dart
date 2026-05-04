import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/models/value_model.dart';
import '../../../shared/constants/default_tags.dart';
import '../../../shared/utils/date_utils.dart';

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
  final DateTime? selectedDay;

  int get activeCount {
    int count = 0;
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

  (DateTime?, DateTime?) get dateRange {
    final now = DateTime.now();
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
// Filter bar — single compact row
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

  int get _tagCount => filters.tags.length;
  bool get _hasCustomDate => filters.dateFilter == DateFilter.custom && filters.customFrom != null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Search
          _FilterChip(
            icon: Icons.search_rounded,
            selected: filters.search.isNotEmpty,
            onTap: onSearchTap,
          ),

          // Clear all — only when active
          if (filters.isActive) ...[
            const SizedBox(width: 6),
            _FilterChip(
              icon: Icons.close_rounded,
              label: 'Clear ${filters.activeCount}',
              selected: true,
              color: AppColors.expense,
              onTap: () => onChanged(TransactionFilters.empty),
            ),
          ],

          const SizedBox(width: 6),
          _Separator(),

          // Type segmented: All | ↓ In | ↑ Out
          const SizedBox(width: 6),
          _TypeSegment(
            current: filters.typeFilter,
            onChanged: (t) => onChanged(filters.copyWith(typeFilter: t)),
          ),

          // Date range
          _Separator(),
          const SizedBox(width: 6),
          _hasCustomDate
              ? _DateRangeActiveChip(
                  from: filters.customFrom!,
                  to: filters.customTo,
                  onTap: () => _openDateSheet(context),
                  onClear: () => onChanged(
                    filters.copyWith(
                      dateFilter: DateFilter.all,
                      clearCustom: true,
                    ),
                  ),
                )
              : _FilterChip(
                  icon: Icons.date_range_rounded,
                  selected: false,
                  onTap: () => _openDateSheet(context),
                ),

          // Values
          if (values.isNotEmpty) ...[
            _Separator(),
            const SizedBox(width: 6),
            ...values.map((v) {
              final color = AppColors.fromHex(v.color);
              final selected = filters.valueId == v.id;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _ValueChip(
                  value: v,
                  color: color,
                  selected: selected,
                  onTap: () => onChanged(
                    selected
                        ? filters.copyWith(clearValueId: true)
                        : filters.copyWith(valueId: v.id),
                  ),
                ),
              );
            }),
          ],

          // Tags
          _Separator(),
          const SizedBox(width: 6),
          _FilterChip(
            icon: Icons.tune_rounded,
            label: _tagCount > 0 ? '$_tagCount' : null,
            selected: _tagCount > 0,
            onTap: () => _openTagSheet(context),
          ),
        ],
      ),
    );
  }

  void _openDateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DateRangeSheet(
        initialFrom: filters.customFrom,
        initialTo: filters.customTo,
        onApply: (from, to) {
          onChanged(
            filters.copyWith(
              dateFilter: DateFilter.custom,
              customFrom: from,
              customTo: to,
            ),
          );
          Navigator.of(ctx).pop();
        },
        onClear: () {
          onChanged(
            filters.copyWith(
              dateFilter: DateFilter.all,
              clearCustom: true,
            ),
          );
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _openTagSheet(BuildContext context) {
    final typeFilter = filters.typeFilter;
    final List<TagCategory> categories;
    switch (typeFilter) {
      case TypeFilter.expense:
        categories = DefaultTags.expenseCategories;
      case TypeFilter.income:
        categories = DefaultTags.incomeCategories;
      case TypeFilter.all:
        categories = [
          ...DefaultTags.expenseCategories,
          ...DefaultTags.incomeCategories,
        ];
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TagFilterSheet(
        categories: categories,
        selectedTags: filters.tags,
        onChanged: (newTags) {
          onChanged(filters.copyWith(tags: newTags));
          Navigator.of(ctx).pop();
        },
        onClear: () {
          onChanged(filters.copyWith(clearTags: true));
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type segment — 3-button toggle (All / In / Out)
// ---------------------------------------------------------------------------

class _TypeSegment extends StatelessWidget {
  const _TypeSegment({required this.current, required this.onChanged});

  final TypeFilter current;
  final ValueChanged<TypeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SegBtn(
          label: 'All',
          selected: current == TypeFilter.all,
          onTap: () => onChanged(TypeFilter.all),
        ),
        const SizedBox(width: 3),
        _SegBtn(
          label: '↓ In',
          selected: current == TypeFilter.income,
          color: AppColors.income,
          onTap: () => onChanged(TypeFilter.income),
        ),
        const SizedBox(width: 3),
        _SegBtn(
          label: '↑ Out',
          selected: current == TypeFilter.expense,
          color: AppColors.expense,
          onTap: () => onChanged(TypeFilter.expense),
        ),
      ],
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({
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
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: AppColors.divider, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip (icon-only or icon+label)
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: label != null ? 10 : 8,
          vertical: 6,
        ),
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
            Icon(
              icon,
              size: 14,
              color: selected ? c : AppColors.textSecondary,
            ),
            if (label != null) ...[
              const SizedBox(width: 4),
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

// ---------------------------------------------------------------------------
// Value chip
// ---------------------------------------------------------------------------

class _ValueChip extends StatelessWidget {
  const _ValueChip({
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value.icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              value.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Separator
// ---------------------------------------------------------------------------

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 1,
        height: 20,
        color: AppColors.divider.withValues(alpha: 0.7),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tag filter bottom sheet — shows all categories
// ---------------------------------------------------------------------------

class _TagFilterSheet extends StatefulWidget {
  const _TagFilterSheet({
    required this.categories,
    required this.selectedTags,
    required this.onChanged,
    required this.onClear,
  });

  final List<TagCategory> categories;
  final Set<String> selectedTags;
  final ValueChanged<Set<String>> onChanged;
  final VoidCallback onClear;

  @override
  State<_TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends State<_TagFilterSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filter by tag',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() => _selected.clear());
                      widget.onClear();
                    },
                    child: const Text('Clear all'),
                  ),
                TextButton(
                  onPressed: () => widget.onChanged(_selected),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Tag categories
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              cat.icon,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat.name,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: cat.tags.map((tag) {
                            final isSelected = _selected.contains(tag);
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (isSelected) {
                                  _selected.remove(tag);
                                } else {
                                  _selected.add(tag);
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.divider,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.check_rounded,
                                          size: 12,
                                          color: AppColors.primary,
                                        ),
                                      ),
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
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active date range chip — shows from/to with an X to clear
// ---------------------------------------------------------------------------

class _DateRangeActiveChip extends StatelessWidget {
  const _DateRangeActiveChip({
    required this.from,
    required this.to,
    required this.onTap,
    required this.onClear,
  });

  final DateTime from;
  final DateTime? to;
  final VoidCallback onTap;
  final VoidCallback onClear;

  String _fmt(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    final dateStr = isToday ? 'Today' : DateFormat('d MMM').format(dt);
    final timeStr = AppDateUtils.formatTime(dt);
    return '$dateStr $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final label = to != null ? '${_fmt(from)} – ${_fmt(to!)}' : _fmt(from);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.date_range_rounded,
              size: 13,
              color: AppColors.primary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                size: 13,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date + time range bottom sheet
// ---------------------------------------------------------------------------

class _DateRangeSheet extends StatefulWidget {
  const _DateRangeSheet({
    required this.initialFrom,
    required this.initialTo,
    required this.onApply,
    required this.onClear,
  });

  final DateTime? initialFrom;
  final DateTime? initialTo;
  final void Function(DateTime from, DateTime to) onApply;
  final VoidCallback onClear;

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = widget.initialFrom ?? DateTime(now.year, now.month, now.day);
    _to = widget.initialTo ?? now;
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _from : _to;
    final first = isFrom ? DateTime(2020) : _from;
    final last = isFrom ? _to : DateTime.now().add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;

    // Preserve existing time
    final updated = DateTime(
      picked.year,
      picked.month,
      picked.day,
      initial.hour,
      initial.minute,
    );
    setState(() => isFrom ? _from = updated : _to = updated);

    // Make sure from <= to after date change
    if (_from.isAfter(_to)) {
      setState(() => isFrom ? _to = _from : _from = _to);
    }
  }

  Future<void> _pickTime(bool isFrom) async {
    final initial = isFrom ? _from : _to;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (picked == null || !mounted) return;

    final updated = DateTime(
      initial.year,
      initial.month,
      initial.day,
      picked.hour,
      picked.minute,
    );
    setState(() => isFrom ? _from = updated : _to = updated);

    if (_from.isAfter(_to)) {
      setState(() => isFrom ? _to = _from : _from = _to);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 16),
            child: Row(
              children: [
                const Icon(
                  Icons.date_range_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filter by date & time',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),

          const Divider(height: 1),
          const SizedBox(height: 20),

          // From row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _DateTimeRow(
              label: 'From',
              dateTime: _from,
              onDateTap: () => _pickDate(true),
              onTimeTap: () => _pickTime(true),
            ),
          ),

          const SizedBox(height: 6),

          // Arrow connector
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                SizedBox(width: 40),
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // To row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _DateTimeRow(
              label: 'To',
              dateTime: _to,
              onDateTap: () => _pickDate(false),
              onTimeTap: () => _pickTime(false),
            ),
          ),

          const SizedBox(height: 24),

          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Row(
              children: [
                if (widget.initialFrom != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onClear,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.expense,
                        side: BorderSide(
                          color: AppColors.expense.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Clear'),
                    ),
                  ),
                if (widget.initialFrom != null) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onApply(_from, _to),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Apply filter'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date + time picker row
// ---------------------------------------------------------------------------

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.dateTime,
    required this.onDateTap,
    required this.onTimeTap,
  });

  final String label;
  final DateTime dateTime;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // Date button
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: onDateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('d MMM yyyy').format(dateTime),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Time button
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: onTimeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppDateUtils.formatTime(dateTime),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
