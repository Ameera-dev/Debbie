import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/theme.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/value_model.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../services/image_service.dart';
import '../../../shared/constants/default_tags.dart';
import '../../../shared/constants/mindfulness.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../shared/widgets/tide.dart';
import '../widgets/filter_bar.dart';

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionFilters _filters = const TransactionFilters();
  bool _showSearch = false;
  bool _showCalendar = false;
  final _searchController = TextEditingController();
  TxRange _range = TxRange.month; // default to current month view

  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsProvider);
    final pendingAsync = ref.watch(pendingTransactionsProvider);
    final valuesAsync = ref.watch(valuesProvider);
    final values = valuesAsync.valueOrNull ?? <ValueModel>[];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _showSearch ? 56 : 72,
        titleSpacing: 16,
        title: _showSearch
            ? _SearchField(
                controller: _searchController,
                onChanged: (q) =>
                    setState(() => _filters = _filters.copyWith(search: q)),
                onClose: () {
                  setState(() {
                    _showSearch = false;
                    _searchController.clear();
                    _filters = _filters.copyWith(search: '');
                  });
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const TideEyebrow(label: 'History'),
                  const SizedBox(height: 2),
                  Text(
                    'Your money story',
                    style: GoogleFonts.lora(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
        actions: [
          if (!_showSearch) ...[
            IconButton(
              icon: Icon(
                _showCalendar
                    ? Icons.calendar_month
                    : Icons.calendar_month_outlined,
                color: _showCalendar ? AppColors.primary : null,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _showCalendar = !_showCalendar;
                  if (!_showCalendar) {
                    _selectedDay = null;
                    _filters = _filters.copyWith(clearSelectedDay: true);
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.repeat_rounded, size: 20),
              tooltip: 'Monthly commitments',
              onPressed: () => context.push('/recurring'),
            ),
            const SizedBox(width: 4),
          ],
        ],
        // Range selector docked as AppBar bottom strip
        bottom: _showSearch
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: _RangeSelector(
                  selected: _range,
                  onChanged: (r) => setState(() {
                    _range = r;
                    _selectedDay = null;
                    _filters = _filters.copyWith(clearSelectedDay: true);
                  }),
                ),
              ),
      ),
      body: TidePageBackground(
        child: Column(
          children: [
            // ── Calendar view (collapsible) ─────────────────────────
            if (_showCalendar)
              txAsync.when(
                data: (transactions) => _CalendarHeader(
                  transactions: transactions,
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,
                  calendarFormat: _calendarFormat,
                  onDaySelected: (selected, focused) {
                    final isSameDay =
                        _selectedDay != null &&
                        selected.year == _selectedDay!.year &&
                        selected.month == _selectedDay!.month &&
                        selected.day == _selectedDay!.day;
                    setState(() {
                      if (isSameDay) {
                        _selectedDay = null;
                        _filters = _filters.copyWith(clearSelectedDay: true);
                      } else {
                        _selectedDay = selected;
                        _focusedDay = focused;
                        _filters = _filters.copyWith(selectedDay: selected);
                      }
                    });
                  },
                  onFormatChanged: (format) =>
                      setState(() => _calendarFormat = format),
                  onPageChanged: (day) => setState(() => _focusedDay = day),
                ),
                loading: () => const SizedBox(height: 60),
                error: (_, __) => const SizedBox.shrink(),
              ),

            // ── Filter bar (single row) ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
              child: FilterBar(
                filters: _filters,
                values: values,
                onChanged: (f) => setState(() => _filters = f),
                onSearchTap: () => setState(() => _showSearch = true),
              ),
            ),

            // ── Transaction list ─────────────────────────────────────
            Expanded(
              child: txAsync.when(
                data: (transactions) {
                  final filtered = _applyFilters(transactions);
                  final pending = _applyFilters(
                    pendingAsync.valueOrNull ?? const <TransactionModel>[],
                  );

                  if (filtered.isEmpty && pending.isEmpty) {
                    return _EmptyState(
                      hasFilters: _filters.isActive,
                      onClear: () =>
                          setState(() => _filters = TransactionFilters.empty),
                    );
                  }

                  // Group by range-aware label (preserves insertion order)
                  final grouped = <String, List<TransactionModel>>{};
                  for (final tx in filtered) {
                    final label = AppDateUtils.groupLabelForRange(
                      tx.date,
                      _range,
                    );
                    grouped.putIfAbsent(label, () => []).add(tx);
                  }
                  final groups = grouped.entries.toList();

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      if (pending.isNotEmpty)
                        _PendingTransactionsSection(transactions: pending),
                      if (filtered.isNotEmpty) ...[
                        _RangeSummary(transactions: filtered, range: _range),
                        ...groups.map((group) {
                          return _DateGroup(
                            label: group.key,
                            transactions: group.value,
                            values: values,
                            ref: ref,
                          );
                        }),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Something went wrong: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TransactionModel> _applyFilters(List<TransactionModel> transactions) {
    var result = transactions;

    // Custom date range takes full control — skip range selector when active
    if (_filters.dateFilter == DateFilter.custom &&
        _filters.customFrom != null) {
      final from = _filters.customFrom!;
      final to = _filters.customTo ?? DateTime.now();
      result = result
          .where((tx) => !tx.date.isBefore(from) && !tx.date.isAfter(to))
          .toList();
    } else {
      // Range selector filter (Today / Week / Month / etc.)
      final (rangeFrom, rangeTo) = AppDateUtils.rangeFor(_range);
      result = result
          .where(
            (tx) => !tx.date.isBefore(rangeFrom) && !tx.date.isAfter(rangeTo),
          )
          .toList();

      // Calendar day tap
      if (_filters.selectedDay != null) {
        final d = _filters.selectedDay!;
        final start = DateTime(d.year, d.month, d.day);
        final end = DateTime(d.year, d.month, d.day, 23, 59, 59);
        result = result
            .where((tx) => !tx.date.isBefore(start) && !tx.date.isAfter(end))
            .toList();
      }
    }

    // Type filter
    final typeStr = _filters.typeString;
    if (typeStr != null) {
      result = result.where((tx) => tx.type == typeStr).toList();
    } else if (!_filters.includesSavings) {
      // Savings live silently — hidden from the default "All" view unless
      // the user opts in via the Savings eye chip.
      result = result.where((tx) => !tx.isSaving).toList();
    }

    // Value filter
    if (_filters.valueId != null) {
      result = result.where((tx) {
        return tx.items.any((item) => item.valueId == _filters.valueId);
      }).toList();
    }

    // Tag filter
    if (_filters.tags.isNotEmpty) {
      result = result.where((tx) {
        return tx.items.any((item) {
          return item.tags.any((t) => _filters.tags.contains(t));
        });
      }).toList();
    }

    // Search filter — now searches title too
    if (_filters.search.isNotEmpty) {
      final query = _filters.search.toLowerCase();
      result = result.where((tx) {
        if (tx.title != null && tx.title!.toLowerCase().contains(query)) {
          return true;
        }
        return tx.items.any(
          (item) => item.description.toLowerCase().contains(query),
        );
      }).toList();
    }

    return result;
  }
}

// ---------------------------------------------------------------------------
// Calendar header with spending heatmap
// ---------------------------------------------------------------------------

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.transactions,
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
  });

  final List<TransactionModel> transactions;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final CalendarFormat calendarFormat;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(CalendarFormat) onFormatChanged;
  final void Function(DateTime) onPageChanged;

  Map<DateTime, (int, int)> get _dayTotals {
    final map = <DateTime, (int, int)>{};
    for (final tx in transactions) {
      if (tx.isSaving) continue; // savings are silent — never on the calendar
      final key = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final current = map[key] ?? (0, 0);
      if (tx.isIncome) {
        map[key] = (current.$1 + tx.totalAmount, current.$2);
      } else {
        map[key] = (current.$1, current.$2 + tx.totalAmount);
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final dayTotals = _dayTotals;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: TableCalendar<TransactionModel>(
        firstDay: DateTime(2020),
        lastDay: DateTime.now().add(const Duration(days: 1)),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) =>
            selectedDay != null && isSameDay(selectedDay, day),
        calendarFormat: calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(16),
          ),
          formatButtonTextStyle: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          titleTextStyle: Theme.of(context).textTheme.titleSmall!,
          leftChevronIcon: const Icon(
            Icons.chevron_left,
            size: 20,
            color: AppColors.textSecondary,
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          weekendStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          defaultTextStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
          weekendTextStyle: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary.withValues(alpha: 0.7),
          ),
          cellMargin: const EdgeInsets.all(2),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, _) {
            final key = DateTime(day.year, day.month, day.day);
            final totals = dayTotals[key];
            if (totals == null) return null;

            final hasIncome = totals.$1 > 0;
            final hasExpense = totals.$2 > 0;

            return Positioned(
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasExpense)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.expense,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (hasExpense && hasIncome) const SizedBox(width: 2),
                  if (hasIncome)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.income,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        onDaySelected: onDaySelected,
        onFormatChanged: onFormatChanged,
        onPageChanged: onPageChanged,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters, required this.onClear});

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight > 48
            ? constraints.maxHeight - 48
            : 0.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          hasFilters ? '🔍' : '💸',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      hasFilters
                          ? 'No transactions match your filters'
                          : 'No transactions yet',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasFilters
                          ? 'Try adjusting your filters to see more.'
                          : 'Tap + to add your first transaction\nand start tracking your energy.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (hasFilters) ...[
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: onClear,
                        icon: const Icon(Icons.filter_alt_off, size: 16),
                        label: const Text('Clear all filters'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Search field
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search transactions...',
        border: InputBorder.none,
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: onClose,
        ),
      ),
      style: Theme.of(context).textTheme.bodyLarge,
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly summary card — redesigned with visual bar
// ---------------------------------------------------------------------------

class _RangeSummary extends StatelessWidget {
  const _RangeSummary({required this.transactions, required this.range});

  final List<TransactionModel> transactions;
  final TxRange range;

  String get _rangeLabel {
    final now = DateTime.now();
    return switch (range) {
      TxRange.today => 'Today',
      TxRange.week => 'This week',
      TxRange.month => DateFormat('MMMM yyyy').format(now),
      TxRange.threeMonths => 'Last 3 months',
      TxRange.sixMonths => 'Last 6 months',
      TxRange.oneYear => 'Last 12 months',
      TxRange.threeYears => 'Last 3 years',
      TxRange.fiveYears => 'Last 5 years',
    };
  }

  @override
  Widget build(BuildContext context) {
    int totalIncome = 0;
    int totalExpense = 0;
    int totalSaving = 0;
    for (final tx in transactions) {
      if (tx.isIncome) {
        totalIncome += tx.totalAmount;
      } else if (tx.isSaving) {
        totalSaving += tx.totalAmount;
      } else {
        totalExpense += tx.totalAmount;
      }
    }
    // Savings feel "gone" from the active pool, like an expense — they
    // reduce balance but stay out of the income/expense story.
    final balance = totalIncome - totalExpense - totalSaving;
    final total = totalIncome + totalExpense;
    final incomeRatio = total > 0 ? totalIncome / total : 0.5;
    final isPositive = balance >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TideCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            // Header: label left, net right
            Row(
              children: [
                TideEyebrow(label: _rangeLabel),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (isPositive ? AppColors.income : AppColors.expense)
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${isPositive ? '+' : '-'}${CurrencyUtils.format(balance.abs())}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w700,
                      color: isPositive ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Income vs expense bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 5,
                child: Row(
                  children: [
                    Flexible(
                      flex: (incomeRatio * 100).round().clamp(1, 99),
                      child: Container(color: AppColors.income),
                    ),
                    Flexible(
                      flex: ((1 - incomeRatio) * 100).round().clamp(1, 99),
                      child: Container(color: AppColors.expense),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Three stats
            Row(
              children: [
                _SummaryItem(
                  label: 'In',
                  amount: totalIncome,
                  color: AppColors.income,
                  prefix: '+',
                ),
                Container(width: 1, height: 28, color: AppColors.divider),
                _SummaryItem(
                  label: 'Out',
                  amount: totalExpense,
                  color: AppColors.expense,
                  prefix: '-',
                ),
                Container(width: 1, height: 28, color: AppColors.divider),
                _SummaryItem(
                  label: 'Txns',
                  amount: transactions.length,
                  color: AppColors.textSecondary,
                  prefix: '',
                  isCount: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingTransactionsSection extends ConsumerWidget {
  const _PendingTransactionsSection({required this.transactions});

  final List<TransactionModel> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TideSurfaceIcon(
                  icon: Icons.hourglass_bottom_rounded,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending pause',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'These purchases are waiting for a second look before they become final.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...transactions.asMap().entries.map((entry) {
              final index = entry.key;
              final transaction = entry.value;
              final emotion = MindfulnessContent.emotionById(
                transaction.emotion,
              );
              return Column(
                children: [
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        color: AppColors.divider.withValues(alpha: 0.8),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.displayTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              transaction.isPendingReviewDue
                                  ? 'Ready now. You set aside ${CurrencyUtils.format(transaction.totalAmount)} on ${AppDateUtils.formatDate(transaction.date)}.'
                                  : 'Waiting until ${AppDateUtils.formatDate(transaction.pendingUntil ?? transaction.date)}.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                            ),
                            if (emotion != null) ...[
                              const SizedBox(height: 8),
                              TidePill(
                                label: '${emotion.emoji} ${emotion.label}',
                                color: AppColors.secondaryDeep,
                                backgroundColor: AppColors.secondary.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await ref
                                .read(imageServiceProvider)
                                .deleteAll(transaction.images);
                            await ref
                                .read(transactionsProvider.notifier)
                                .discardPending(transaction.id);
                          },
                          child: const Text('Discard'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => ref
                              .read(transactionsProvider.notifier)
                              .confirmPending(transaction.id),
                          child: Text(
                            transaction.isPendingReviewDue
                                ? 'Record now'
                                : 'Record anyway',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.prefix,
    this.isCount = false,
  });

  final String label;
  final int amount;
  final Color color;
  final String prefix;
  final bool isCount;

  @override
  Widget build(BuildContext context) {
    final displayText = isCount
        ? '$amount'
        : '$prefix ${CurrencyUtils.format(amount)}';
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                displayText,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'JetBrains Mono',
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date group — cleaner header with line
// ---------------------------------------------------------------------------

class _DateGroup extends StatelessWidget {
  const _DateGroup({
    required this.label,
    required this.transactions,
    required this.values,
    required this.ref,
  });

  final String label;
  final List<TransactionModel> transactions;
  final List<ValueModel> values;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    int dailyIncome = 0;
    int dailyExpense = 0;
    int dailySaving = 0;
    for (final tx in transactions) {
      if (tx.isIncome) {
        dailyIncome += tx.totalAmount;
      } else if (tx.isSaving) {
        dailySaving += tx.totalAmount;
      } else {
        dailyExpense += tx.totalAmount;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Row(
            children: [
              TideEyebrow(label: label),
              const SizedBox(width: 8),
              Text(
                '${transactions.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.divider.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 12),
              // Net for this group as a compact pill
              if (dailyExpense > 0 || dailyIncome > 0 || dailySaving > 0)
                Builder(
                  builder: (context) {
                    final net = dailyIncome - dailyExpense - dailySaving;
                    final isPositive = net >= 0;
                    final color = isPositive
                        ? AppColors.income
                        : AppColors.expense;
                    final label = isPositive
                        ? '+${CurrencyUtils.format(net)}'
                        : '-${CurrencyUtils.format(net.abs())}';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.w700,
                          color: color.withValues(alpha: 0.85),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        ...transactions.indexed.map(
          ((int, TransactionModel) pair) =>
              _DismissibleTile(
                    key: ValueKey(pair.$2.id),
                    transaction: pair.$2,
                    values: values,
                    ref: ref,
                  )
                  .animate(delay: Duration(milliseconds: pair.$1 * 40))
                  .fadeIn(duration: 280.ms, curve: Curves.easeOut)
                  .slideX(
                    begin: 0.06,
                    end: 0,
                    duration: 280.ms,
                    curve: Curves.easeOut,
                  ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dismissible wrapper
// ---------------------------------------------------------------------------

class _DismissibleTile extends StatelessWidget {
  const _DismissibleTile({
    super.key,
    required this.transaction,
    required this.values,
    required this.ref,
  });

  final TransactionModel transaction;
  final List<ValueModel> values;
  final WidgetRef ref;

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This will permanently remove this transaction and all its items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss-${transaction.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) async {
        await ref.read(imageServiceProvider).deleteAll(transaction.images);
        await ref.read(transactionsProvider.notifier).remove(transaction.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.expense),
      ),
      child: _TransactionTile(transaction: transaction, values: values),
    );
  }
}

// ---------------------------------------------------------------------------
// Redesigned transaction tile — clean, focused
// ---------------------------------------------------------------------------

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.values});

  final TransactionModel transaction;
  final List<ValueModel> values;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final isExpense = tx.isExpense;
    final amountColor = tx.isSaving
        ? AppColors.saving
        : (isExpense ? AppColors.expense : AppColors.income);
    final emotion = MindfulnessContent.emotionById(tx.emotion);

    // Find primary value (most items mapped to)
    final valueCounts = <String, int>{};
    for (final item in tx.items) {
      if (item.valueId != null) {
        valueCounts[item.valueId!] = (valueCounts[item.valueId!] ?? 0) + 1;
      }
    }
    ValueModel? primaryValue;
    if (valueCounts.isNotEmpty) {
      final topValueId = valueCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      primaryValue = values.where((v) => v.id == topValueId).firstOrNull;
    }

    // Icon: value emoji > tag category icon > fallback
    final firstItem = tx.items.isNotEmpty ? tx.items.first : null;
    final firstTagIcon = (firstItem != null && firstItem.tags.isNotEmpty)
        ? DefaultTags.parentOf(firstItem.tags.first, tx.type)?.icon
        : null;
    final fallbackIcon = tx.isSaving ? '🪴' : (isExpense ? '💸' : '💰');
    final icon = primaryValue?.icon ?? firstTagIcon ?? fallbackIcon;
    final iconBgColor = primaryValue != null
        ? AppColors.fromHex(primaryValue.color).withValues(alpha: 0.12)
        : amountColor.withValues(alpha: 0.08);

    // Collect unique values for chips
    final valueIds = tx.items
        .where((i) => i.valueId != null)
        .map((i) => i.valueId!)
        .toSet();
    final txValues = values.where((v) => valueIds.contains(v.id)).toList();

    final isMultiItem = tx.itemCount > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/transactions/${tx.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Leading: first photo if available, otherwise the value/category icon.
                tx.hasImages
                    ? _ImageThumbnail(
                        imagePath: tx.images.first,
                        size: 44,
                        borderRadius: 12,
                        enableFullscreen: false,
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(icon, style: const TextStyle(fontSize: 20)),
                      ),
                const SizedBox(width: 12),

                // Title + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.displayTitle.isNotEmpty
                            ? tx.displayTitle
                            : (tx.isSaving
                                  ? 'Saving'
                                  : (isExpense ? 'Expense' : 'Income')),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          // Item count badge
                          if (isMultiItem) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: amountColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${tx.itemCount} items',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: amountColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          // Value chips (compact)
                          if (txValues.isNotEmpty) ...[
                            ...txValues.take(2).map((v) {
                              final c = AppColors.fromHex(v.color);
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${v.icon} ${v.name}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: c,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (txValues.length > 2)
                              Text(
                                '+${txValues.length - 2}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                    ),
                              ),
                          ],
                          if (emotion != null) ...[
                            if (txValues.isNotEmpty) const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${emotion.emoji} ${emotion.label}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.secondaryDeep,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          // Date (pushed right if no other meta)
                          if (txValues.isEmpty &&
                              emotion == null &&
                              !isMultiItem)
                            Text(
                              AppDateUtils.formatDate(tx.date),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Amount + time + photo badge column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyUtils.formatSigned(
                        tx.totalAmount,
                        // Savings reduce the active pool just like expenses.
                        isExpense: isExpense || tx.isSaving,
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: amountColor,
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tx.hasImages) ...[
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 10,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${tx.images.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          AppDateUtils.formatTime(tx.date),
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'JetBrains Mono',
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image thumbnail (kept for potential future use)
// ---------------------------------------------------------------------------

class _ImageThumbnail extends ConsumerStatefulWidget {
  const _ImageThumbnail({
    required this.imagePath,
    this.size = 32,
    this.borderRadius = 6,
    this.enableFullscreen = true,
  });

  final String imagePath;
  final double size;
  final double borderRadius;
  final bool enableFullscreen;

  @override
  ConsumerState<_ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends ConsumerState<_ImageThumbnail> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final file = await ref.read(imageServiceProvider).getFile(widget.imagePath);
    if (mounted && file != null) setState(() => _file = file);
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Icon(
          Icons.image_outlined,
          size: widget.size * 0.45,
          color: AppColors.textSecondary,
        ),
      );
    }
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.file(
        _file!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        cacheWidth: (widget.size * 2).round(),
      ),
    );
    if (!widget.enableFullscreen) return image;
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: image,
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoView(imageProvider: FileImage(_file!)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Range selector — horizontal chip strip
// ---------------------------------------------------------------------------

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final TxRange selected;
  final ValueChanged<TxRange> onChanged;

  static const _chipHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // No vertical padding — chips are centered inside the 44px SizedBox
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: TxRange.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final range = TxRange.values[i];
          final isSelected = range == selected;
          return Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: _chipHeight,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkSurface : AppColors.background),
                borderRadius: BorderRadius.circular(_chipHeight / 2),
                border: isSelected
                    ? null
                    : Border.all(
                        color: AppColors.divider.withValues(alpha: 0.8),
                        width: 1,
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(_chipHeight / 2),
                onTap: () => onChanged(range),
                child: SizedBox(
                  height: _chipHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      child: Text(
                        range.label,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
