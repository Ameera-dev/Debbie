import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/value_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../shared/constants/mindfulness.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../shared/widgets/tide.dart';

// ---------------------------------------------------------------------------
// Analytics screen — spending trends, breakdowns, and patterns
// ---------------------------------------------------------------------------

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  // 0 = This Month, 1 = Last 3 Months, 2 = Last 6 Months
  int _rangePicker = 0;

  @override
  Widget build(BuildContext context) {
    final allTx = ref.watch(transactionsProvider).valueOrNull ?? [];
    final values = ref.watch(valuesProvider).valueOrNull ?? [];
    final budgetAsync = ref.watch(monthlyIncomeProvider);
    final budget = budgetAsync.valueOrNull ?? 0;

    return Scaffold(
      body: TidePageBackground(
        child: CustomScrollView(
          slivers: [
            TideScrollHeader(
              compactTitle: 'Analytics',
              eyebrow: 'Analytics',
              leading: TideBackPill(
                label: 'Today',
                onPressed: () => context.go('/'),
              ),
              leadingWidth: 94,
              expandedTitle: Text.rich(
                TextSpan(
                  style: GoogleFonts.lora(
                    fontSize: 30,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  children: const [
                    TextSpan(text: 'Six months of '),
                    TextSpan(
                      text: 'tide',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    TextSpan(text: '.'),
                  ],
                ),
              ),
              subtitle:
                  'See which values have carried the most energy over time.',
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),

                  // ── Range picker chips ────────────────────────────────
                  _RangePicker(
                    selected: _rangePicker,
                    onChanged: (i) => setState(() => _rangePicker = i),
                  ),
                  const SizedBox(height: 16),

                  // ── Monthly Trend ─────────────────────────────────────
                  _MonthlyTrendChart(allTx: allTx, range: _rangePicker),
                  const SizedBox(height: 16),

                  // ── Expense by Value ──────────────────────────────────
                  _ValueBreakdown(
                    allTx: allTx,
                    values: values,
                    range: _rangePicker,
                  ),
                  const SizedBox(height: 16),

                  _EmotionalPatternsCard(
                    allTx: allTx,
                    values: values,
                    range: _rangePicker,
                  ),
                  const SizedBox(height: 16),

                  // ── Weekday Pattern ───────────────────────────────────
                  _WeekdayPattern(allTx: allTx, range: _rangePicker),
                  const SizedBox(height: 16),

                  // ── Top Items ─────────────────────────────────────────
                  _TopItems(allTx: allTx, values: values, range: _rangePicker),
                  const SizedBox(height: 16),

                  // ── Stats Summary ─────────────────────────────────────
                  _StatsSummary(
                    allTx: allTx,
                    range: _rangePicker,
                    budget: budget,
                  ),

                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DateTime _rangeStart(int range) {
  final now = DateTime.now();
  switch (range) {
    case 1:
      return DateTime(now.year, now.month - 2, 1);
    case 2:
      return DateTime(now.year, now.month - 5, 1);
    default:
      return DateTime(now.year, now.month, 1);
  }
}

List<TransactionModel> _filtered(List<TransactionModel> all, int range) {
  final start = _rangeStart(range);
  return all.where((tx) => !tx.date.isBefore(start)).toList();
}

// ---------------------------------------------------------------------------
// Range picker chips
// ---------------------------------------------------------------------------

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['This Month', '3 Months', '6 Months'];
    return Row(
      children: List.generate(labels.length, (i) {
        final isSelected = i == selected;
        return Padding(
          padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
          child: ChoiceChip(
            label: Text(labels[i]),
            selected: isSelected,
            onSelected: (_) => onChanged(i),
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly trend — vertical bars for income & expense per month
// ---------------------------------------------------------------------------

class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart({required this.allTx, required this.range});

  final List<TransactionModel> allTx;
  final int range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthCount = range == 0
        ? 1
        : range == 1
        ? 3
        : 6;

    // Build per-month income/expense totals
    final months = <String>[];
    final incomeByMonth = <String, int>{};
    final expenseByMonth = <String, int>{};

    for (int i = monthCount - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = AppDateUtils.toMonthKey(d);
      months.add(key);
      incomeByMonth[key] = 0;
      expenseByMonth[key] = 0;
    }

    for (final tx in allTx) {
      final key = AppDateUtils.toMonthKey(tx.date);
      if (incomeByMonth.containsKey(key)) {
        if (tx.isIncome) {
          incomeByMonth[key] = incomeByMonth[key]! + tx.totalAmount;
        } else {
          expenseByMonth[key] = expenseByMonth[key]! + tx.totalAmount;
        }
      }
    }

    final maxVal = months.fold<int>(0, (prev, m) {
      return math.max(
        prev,
        math.max(incomeByMonth[m] ?? 0, expenseByMonth[m] ?? 0),
      );
    });

    // For single month, show a summary card instead of bars
    if (monthCount == 1) {
      final m = months.first;
      final inc = incomeByMonth[m] ?? 0;
      final exp = expenseByMonth[m] ?? 0;
      return _SectionCard(
        icon: Icons.trending_up_rounded,
        title: 'This Month',
        child: Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Income',
                value: CurrencyUtils.format(inc),
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Expenses',
                value: CurrencyUtils.format(exp),
                color: AppColors.expense,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Balance',
                value: CurrencyUtils.format((inc - exp).abs()),
                color: inc >= exp ? AppColors.income : AppColors.expense,
              ),
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      icon: Icons.bar_chart_rounded,
      title: 'Monthly Trend',
      child: Column(
        children: [
          // Legend
          Row(
            children: [
              _LegendDot(color: AppColors.income, label: 'Income'),
              const SizedBox(width: 16),
              _LegendDot(color: AppColors.expense, label: 'Expenses'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: months.map((m) {
                final inc = incomeByMonth[m] ?? 0;
                final exp = expenseByMonth[m] ?? 0;
                final incFrac = maxVal > 0 ? inc / maxVal : 0.0;
                final expFrac = maxVal > 0 ? exp / maxVal : 0.0;
                final label = DateFormat('MMM').format(DateTime.parse('$m-01'));
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: FractionallySizedBox(
                                  heightFactor: incFrac.clamp(0.02, 1.0),
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.income,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: FractionallySizedBox(
                                  heightFactor: expFrac.clamp(0.02, 1.0),
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.expense,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Value breakdown — horizontal bars showing spend per value
// ---------------------------------------------------------------------------

class _ValueBreakdown extends StatelessWidget {
  const _ValueBreakdown({
    required this.allTx,
    required this.values,
    required this.range,
  });

  final List<TransactionModel> allTx;
  final List<ValueModel> values;
  final int range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered(
      allTx,
      range,
    ).where((tx) => tx.isExpense).toList();

    // Sum by value
    final byValue = <String, int>{};
    int totalExpense = 0;
    for (final tx in filtered) {
      for (final item in tx.items) {
        if (item.valueId != null) {
          byValue[item.valueId!] = (byValue[item.valueId!] ?? 0) + item.amount;
        }
        totalExpense += item.amount;
      }
    }

    if (byValue.isEmpty) {
      return _SectionCard(
        icon: Icons.pie_chart_rounded,
        title: 'Spending by Value',
        child: _EmptyWidget(message: 'No expense data for this period'),
      );
    }

    // Sort by amount descending
    final sorted = byValue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxAmount = sorted.first.value;

    return _SectionCard(
      icon: Icons.pie_chart_rounded,
      title: 'Spending by Value',
      child: Column(
        children: sorted.map((entry) {
          final val = values.cast<ValueModel?>().firstWhere(
            (v) => v!.id == entry.key,
            orElse: () => null,
          );
          if (val == null) return const SizedBox.shrink();

          final pct = totalExpense > 0
              ? (entry.value / totalExpense * 100).round()
              : 0;
          final barFrac = maxAmount > 0 ? entry.value / maxAmount : 0.0;
          final color = AppColors.fromHex(val.color);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(val.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        val.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyUtils.format(entry.value),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: barFrac,
                    minHeight: 8,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmotionalPatternsCard extends StatelessWidget {
  const _EmotionalPatternsCard({
    required this.allTx,
    required this.values,
    required this.range,
  });

  final List<TransactionModel> allTx;
  final List<ValueModel> values;
  final int range;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered(
      allTx,
      range,
    ).where((tx) => tx.isExpense && tx.emotion != null).toList();

    final emotionByValue = <String, Map<String, int>>{};
    for (final tx in filtered) {
      final valueIds = tx.items
          .where((item) => item.valueId != null)
          .map((item) => item.valueId!)
          .toSet();
      for (final valueId in valueIds) {
        final bucket = emotionByValue.putIfAbsent(
          valueId,
          () => <String, int>{},
        );
        bucket[tx.emotion!] = (bucket[tx.emotion!] ?? 0) + 1;
      }
    }

    if (emotionByValue.isEmpty) {
      return _SectionCard(
        icon: Icons.favorite_border_rounded,
        title: 'Emotional Patterns',
        child: _EmptyWidget(
          message: 'Add emotional tags to transactions to see patterns here',
        ),
      );
    }

    final summaries =
        emotionByValue.entries
            .map((entry) {
              final value = values.cast<ValueModel?>().firstWhere(
                (item) => item!.id == entry.key,
                orElse: () => null,
              );
              if (value == null) return null;
              final topEmotionId = entry.value.entries
                  .reduce((a, b) => a.value >= b.value ? a : b)
                  .key;
              final emotion = MindfulnessContent.emotionById(topEmotionId);
              if (emotion == null) return null;
              final total = entry.value.values.fold<int>(
                0,
                (sum, count) => sum + count,
              );
              return (value, emotion, total);
            })
            .whereType<(ValueModel, MoneyEmotionOption, int)>()
            .toList()
          ..sort((a, b) => b.$3.compareTo(a.$3));

    return _SectionCard(
      icon: Icons.favorite_border_rounded,
      title: 'Emotional Patterns',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: summaries.take(4).map((summary) {
          final value = summary.$1;
          final emotion = summary.$2;
          final count = summary.$3;
          final color = AppColors.fromHex(value.color);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.14)),
              ),
              child: Text(
                'You tend to feel ${emotion.label.toLowerCase()} when spending on ${value.name}. That pattern showed up $count ${count == 1 ? 'time' : 'times'} in this range.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekday spending pattern — which days you spend most
// ---------------------------------------------------------------------------

class _WeekdayPattern extends StatelessWidget {
  const _WeekdayPattern({required this.allTx, required this.range});

  final List<TransactionModel> allTx;
  final int range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered(
      allTx,
      range,
    ).where((tx) => tx.isExpense).toList();

    // Sum expenses by weekday (1=Mon .. 7=Sun)
    final byDay = List.filled(7, 0);
    for (final tx in filtered) {
      final wd = tx.date.weekday - 1; // 0=Mon
      byDay[wd] += tx.totalAmount;
    }

    final maxDay = byDay.fold<int>(0, math.max);
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (maxDay == 0) {
      return _SectionCard(
        icon: Icons.calendar_view_week_rounded,
        title: 'Weekday Pattern',
        child: _EmptyWidget(message: 'No expense data for this period'),
      );
    }

    return _SectionCard(
      icon: Icons.calendar_view_week_rounded,
      title: 'Weekday Pattern',
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final frac = maxDay > 0 ? byDay[i] / maxDay : 0.0;
            final isMax = byDay[i] == maxDay && maxDay > 0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isMax)
                      Text(
                        CurrencyUtils.format(byDay[i]),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: frac.clamp(0.03, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isMax
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayLabels[i],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isMax
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: isMax ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top items — most frequent / highest spending items
// ---------------------------------------------------------------------------

class _TopItems extends StatelessWidget {
  const _TopItems({
    required this.allTx,
    required this.values,
    required this.range,
  });

  final List<TransactionModel> allTx;
  final List<ValueModel> values;
  final int range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered(
      allTx,
      range,
    ).where((tx) => tx.isExpense).toList();

    // Aggregate by item description
    final byDesc = <String, _ItemAgg>{};
    for (final tx in filtered) {
      for (final item in tx.items) {
        final key = item.description.toLowerCase().trim();
        if (byDesc.containsKey(key)) {
          byDesc[key]!.total += item.amount;
          byDesc[key]!.count += 1;
        } else {
          byDesc[key] = _ItemAgg(
            description: item.description,
            total: item.amount,
            count: 1,
            valueId: item.valueId,
          );
        }
      }
    }

    if (byDesc.isEmpty) {
      return _SectionCard(
        icon: Icons.leaderboard_rounded,
        title: 'Top Spending',
        child: _EmptyWidget(message: 'No expense data for this period'),
      );
    }

    final sorted = byDesc.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final top = sorted.take(5).toList();

    return _SectionCard(
      icon: Icons.leaderboard_rounded,
      title: 'Top Spending',
      child: Column(
        children: List.generate(top.length, (i) {
          final item = top[i];
          final val = item.valueId != null
              ? values.cast<ValueModel?>().firstWhere(
                  (v) => v!.id == item.valueId,
                  orElse: () => null,
                )
              : null;
          final color = val != null
              ? AppColors.fromHex(val.color)
              : AppColors.textSecondary;

          return Padding(
            padding: EdgeInsets.only(bottom: i < top.length - 1 ? 12 : 0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${item.count} time${item.count > 1 ? 's' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyUtils.format(item.total),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.expense,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ItemAgg {
  _ItemAgg({
    required this.description,
    required this.total,
    required this.count,
    this.valueId,
  });

  final String description;
  int total;
  int count;
  final String? valueId;
}

// ---------------------------------------------------------------------------
// Stats summary — key numbers at a glance
// ---------------------------------------------------------------------------

class _StatsSummary extends StatelessWidget {
  const _StatsSummary({
    required this.allTx,
    required this.range,
    required this.budget,
  });

  final List<TransactionModel> allTx;
  final int range;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered(allTx, range);
    final expenses = filtered.where((tx) => tx.isExpense).toList();
    final incomes = filtered.where((tx) => tx.isIncome).toList();

    final totalExpense = expenses.fold<int>(0, (s, tx) => s + tx.totalAmount);
    final totalIncome = incomes.fold<int>(0, (s, tx) => s + tx.totalAmount);
    final totalTx = filtered.length;

    // Days in range
    final start = _rangeStart(range);
    final now = DateTime.now();
    final days = now.difference(start).inDays + 1;
    final dailyAvg = days > 0 ? totalExpense ~/ days : 0;

    // Average per transaction
    final avgPerTx = expenses.isNotEmpty ? totalExpense ~/ expenses.length : 0;

    // Largest single expense
    int largest = 0;
    for (final tx in expenses) {
      if (tx.totalAmount > largest) largest = tx.totalAmount;
    }

    return _SectionCard(
      icon: Icons.query_stats_rounded,
      title: 'Quick Stats',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Total Transactions',
                  value: '$totalTx',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Daily Average',
                  value: CurrencyUtils.format(dailyAvg),
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Avg per Expense',
                  value: CurrencyUtils.format(avgPerTx),
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Largest Expense',
                  value: CurrencyUtils.format(largest),
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          if (budget > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Savings Rate',
                    value: totalIncome > 0
                        ? '${((totalIncome - totalExpense) / totalIncome * 100).clamp(0, 100).round()}%'
                        : '—',
                    color: AppColors.income,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Net Balance',
                    value: CurrencyUtils.format(
                      (totalIncome - totalExpense).abs(),
                    ),
                    color: totalIncome >= totalExpense
                        ? AppColors.income
                        : AppColors.expense,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.lora(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _EmptyWidget extends StatelessWidget {
  const _EmptyWidget({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
