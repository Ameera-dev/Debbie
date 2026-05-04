import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/journal_entry_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/value_model.dart';
import '../../../data/models/values_plan_model.dart';
import '../../../data/models/weekly_budget_plan_model.dart';
import '../../../data/models/ai_reflection_model.dart';
import '../../../data/models/daily_intention_model.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/recurring_provider.dart';
import '../../../providers/daily_intentions_provider.dart';
import '../../../providers/goals_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/mindfulness_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../providers/weekly_budget_provider.dart';
import '../../../services/ai_reflection_service.dart';
import '../../../services/image_service.dart';
import '../../../shared/constants/mindfulness.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../shared/utils/id_generator.dart';
import '../../../shared/widgets/tide.dart';
import '../widgets/alignment_score.dart';
import '../widgets/goal_card.dart';
import '../widgets/values_wheel.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valuesAsync = ref.watch(valuesProvider);
    final availableAsync = ref.watch(availableBalanceProvider);
    final allTimeIncomeAsync = ref.watch(allTimeIncomeProvider);
    final allTimeExpenseAsync = ref.watch(allTimeExpenseProvider);
    final incomeAsync = ref.watch(monthlyIncomeAmountProvider);
    final expenseAsync = ref.watch(monthlyExpenseAmountProvider);
    final spendingByValue = ref.watch(spendingByValueProvider);
    final planAsync = ref.watch(currentMonthPlanProvider);
    final goalsAsync = ref.watch(activeGoalsProvider);
    final allTransactions = ref.watch(transactionsProvider).valueOrNull ?? [];
    final txAsync = ref.watch(currentMonthTransactionsProvider);
    final monthTransactions = txAsync.valueOrNull ?? <TransactionModel>[];
    final latestJournal = ref.watch(latestJournalEntryProvider);
    final journalEntries = ref.watch(journalProvider).valueOrNull ?? [];
    final todayIntention = ref.watch(todayIntentionProvider);
    final awarenessStreak = ref.watch(awarenessStreakProvider);
    final duePendingTransactions = ref.watch(duePendingTransactionsProvider);
    final budgetAsync = ref.watch(monthlyIncomeProvider);

    final values = valuesAsync.valueOrNull ?? <ValueModel>[];
    final income = incomeAsync.valueOrNull ?? 0;
    final expenses = expenseAsync.valueOrNull ?? 0;
    final streak = awarenessStreak;
    final budget = budgetAsync.valueOrNull ?? income;

    return Scaffold(
      body: TidePageBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                child: _GreetingHeader(
                  values: values,
                  spendingByValue: spendingByValue,
                  streak: streak,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _AvailableBalanceCard(
                  availableAsync: availableAsync,
                  totalInAsync: allTimeIncomeAsync,
                  totalOutAsync: allTimeExpenseAsync,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TideOverviewCard(
                  values: values,
                  spendingByValue: spendingByValue.valueOrNull ?? const {},
                  expenses: expenses,
                  budget: budget,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TodayPlanSpotlight(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),

                  _TodayFocusCard(
                    values: values,
                    allTransactions: allTransactions,
                    todayIntention: todayIntention,
                    duePendingTransactions: duePendingTransactions,
                    budget: budget,
                    expenses: expenses,
                    streak: streak,
                  ),
                  const SizedBox(height: 16),

                  const _WeeklyBudgetPlanSummaryCard(),
                  const SizedBox(height: 16),

                  if (duePendingTransactions.isNotEmpty) ...[
                    _PendingPurchaseSection(
                      transactions: duePendingTransactions,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Monthly Overview ───────────────────────────────────
                  _MonthlyOverview(
                    income: income,
                    expenses: expenses,
                    budgetAsync: budgetAsync,
                  ),
                  const SizedBox(height: 16),

                  _TransactionTrendSection(transactions: allTransactions),
                  const SizedBox(height: 16),

                  _MonthPulseAnalytics(
                    monthTransactions: monthTransactions,
                    allTransactions: allTransactions,
                    values: values,
                    budget: budget,
                  ),
                  const SizedBox(height: 16),

                  // ── Recurring commitments card ──────────────────────
                  const _RecurringCommitmentsCard(),
                  const SizedBox(height: 16),

                  // ── Values Wheel + Alignment Score ──────────────────
                  _ValuesWheelSection(
                    values: values,
                    spendingByValue: spendingByValue,
                    planAsync: planAsync,
                    expenses: expenses,
                  ),

                  // ── Plan vs Actual ─────────────────────────────────────
                  _PlanVsActual(
                    values: values,
                    spendingByValue: spendingByValue,
                    planAsync: planAsync,
                  ),

                  // ── Impact Goals ────────────────────────────────────
                  _GoalsSection(goalsAsync: goalsAsync, values: values),

                  // ── Weekly Reflection Prompt ────────────────────────
                  _ReflectionPrompt(
                    latestJournal: latestJournal,
                    spendingByValue: spendingByValue,
                    values: values,
                  ),

                  const SizedBox(height: 16),
                  _MonthlyLetterCard(
                    values: values,
                    transactions: monthTransactions,
                    entries: journalEntries,
                    spendingByValue: spendingByValue.valueOrNull ?? const {},
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
// Greeting header — Tide style: caps date + serif greeting + streak
// ---------------------------------------------------------------------------

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.values,
    required this.spendingByValue,
    required this.streak,
  });

  final List<ValueModel> values;
  final AsyncValue<Map<String, int>> spendingByValue;
  final int streak;

  @override
  Widget build(BuildContext context) {
    String? topValueName;
    final spending = spendingByValue.valueOrNull ?? {};
    if (spending.isNotEmpty && values.isNotEmpty) {
      final topId = spending.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      final topValue = values.where((v) => v.id == topId).firstOrNull;
      topValueName = topValue?.name;
    }

    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TideEyebrow(label: dateStr),
                  const SizedBox(height: 6),
                  Text(
                    AppDateUtils.greeting().replaceAll('!', ''),
                    style: GoogleFonts.lora(
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topValueName != null
                        ? 'Your energy is flowing toward $topValueName.'
                        : 'A softer view of the month so far.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const TideSurfaceIcon(
              icon: Icons.dark_mode_outlined,
              backgroundColor: AppColors.surfaceWarm,
            ),
            if (streak >= 2)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: TidePill(
                  label: '$streak days aware',
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.14),
                  color: AppColors.secondaryDeep,
                  icon: const Text('🌿', style: TextStyle(fontSize: 13)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TideOverviewCard extends StatelessWidget {
  const _TideOverviewCard({
    required this.values,
    required this.spendingByValue,
    required this.expenses,
    required this.budget,
  });

  final List<ValueModel> values;
  final Map<String, int> spendingByValue;
  final int expenses;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final availableBudget = budget > 0 ? budget : expenses;
    final remaining = availableBudget - expenses;
    final segments =
        values
            .where((value) => spendingByValue[value.id] != null)
            .map((value) => MapEntry(value, spendingByValue[value.id]!))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final topSegments = segments.take(4).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDeep,
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.22),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -28,
            right: -28,
            bottom: -18,
            child: SizedBox(
              height: 96,
              child: CustomPaint(
                painter: _WavePainter(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${DateFormat('MMMM').format(DateTime.now())} remaining',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Day ${DateTime.now().day}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  CurrencyUtils.format(remaining),
                  style: GoogleFonts.lora(
                    fontSize: 38,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${CurrencyUtils.format(expenses)} spent of ${CurrencyUtils.format(availableBudget)} planned',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
                const SizedBox(height: 16),
                TideStackedBar(
                  height: 8,
                  segments: segments.isEmpty
                      ? [
                          TideBarSegment(
                            color: Colors.white.withValues(alpha: 0.32),
                            value: 1,
                          ),
                        ]
                      : segments
                            .map(
                              (entry) => TideBarSegment(
                                color: AppColors.fromHex(entry.key.color),
                                value: entry.value.toDouble(),
                              ),
                            )
                            .toList(),
                ),
                if (topSegments.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: topSegments.map((entry) {
                      final value = entry.key;
                      return TidePill(
                        label: value.name,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        color: Colors.white,
                        icon: Text(
                          value.icon,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.52)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.1,
        size.width * 0.38,
        size.height * 0.92,
        size.width * 0.62,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.1,
        size.width * 0.92,
        size.height * 0.75,
        size.width,
        size.height * 0.34,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// ---------------------------------------------------------------------------
// Today's focus — synthesized next step for the dashboard
// ---------------------------------------------------------------------------

class _TodayFocusCard extends StatelessWidget {
  const _TodayFocusCard({
    required this.values,
    required this.allTransactions,
    required this.todayIntention,
    required this.duePendingTransactions,
    required this.budget,
    required this.expenses,
    required this.streak,
  });

  final List<ValueModel> values;
  final List<TransactionModel> allTransactions;
  final DailyIntentionModel? todayIntention;
  final List<TransactionModel> duePendingTransactions;
  final int budget;
  final int expenses;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = AppDateUtils.startOfDay(now);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final monthProgress = now.day / daysInMonth;
    final budgetProgress = budget > 0 ? expenses / budget : 0.0;
    final todayTransactions = allTransactions.where((tx) {
      return tx.isRecorded && AppDateUtils.isSameDay(tx.date, today);
    }).toList();
    final todayExpense = todayTransactions
        .where((tx) => tx.isExpense)
        .fold<int>(0, (sum, tx) => sum + tx.totalAmount);
    final selectedValue = values
        .where((value) => value.id == todayIntention?.valueId)
        .firstOrNull;
    final focusAmount = selectedValue == null
        ? 0
        : todayTransactions.where((tx) => tx.isExpense).fold<int>(0, (sum, tx) {
            final aligned = tx.items
                .where((item) => item.valueId == selectedValue.id)
                .fold<int>(0, (itemSum, item) => itemSum + item.amount);
            return sum + aligned;
          });
    final status = _focusStatus(
      budgetProgress: budgetProgress,
      monthProgress: monthProgress,
      todayExpense: todayExpense,
      focusAmount: focusAmount,
      selectedValue: selectedValue,
      pendingCount: duePendingTransactions.length,
    );
    final cta = _focusCta(
      pendingCount: duePendingTransactions.length,
      todayTransactions: todayTransactions.length,
      selectedValue: selectedValue,
    );

    return TideCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TideSurfaceIcon(
                icon: status.icon,
                color: status.color,
                backgroundColor: status.color.withValues(alpha: 0.11),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Today's focus",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (streak >= 2)
                          TidePill(
                            label: '$streak days',
                            color: AppColors.secondaryDeep,
                            backgroundColor: AppColors.secondary.withValues(
                              alpha: 0.14,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: status.color.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    status.title,
                    style: GoogleFonts.lora(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: status.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(status.icon, color: status.color, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FocusSignal(
                  label: 'Pace',
                  value: budget > 0
                      ? '${(budgetProgress * 100).round()}%'
                      : 'No budget',
                  color: budget > 0 && budgetProgress > monthProgress + 0.12
                      ? AppColors.expense
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FocusSignal(
                  label: 'Today',
                  value: CurrencyUtils.format(todayExpense),
                  color: todayExpense > 0
                      ? AppColors.expense
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FocusSignal(
                  label: 'Intention',
                  value: selectedValue?.name ?? 'Unset',
                  color: selectedValue == null
                      ? AppColors.textSecondary
                      : AppColors.fromHex(selectedValue.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  cta.helper,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => context.push(cta.route),
                icon: Icon(cta.icon, size: 17),
                label: Text(cta.label),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static _FocusStatus _focusStatus({
    required double budgetProgress,
    required double monthProgress,
    required int todayExpense,
    required int focusAmount,
    required ValueModel? selectedValue,
    required int pendingCount,
  }) {
    if (pendingCount > 0) {
      return const _FocusStatus(
        title: 'Review',
        message:
            'A delayed purchase is ready for a decision before it blends into the month.',
        icon: Icons.hourglass_bottom_rounded,
        color: AppColors.secondaryDeep,
      );
    }

    if (budgetProgress > monthProgress + 0.12) {
      return const _FocusStatus(
        title: 'Watch pace',
        message:
            'Spending is moving faster than the calendar. Today is a good day to keep things deliberate.',
        icon: Icons.speed_rounded,
        color: AppColors.expense,
      );
    }

    if (selectedValue != null && focusAmount > 0) {
      return _FocusStatus(
        title: 'Aligned',
        message:
            '${CurrencyUtils.format(focusAmount)} already went toward ${selectedValue.name} today.',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.fromHex(selectedValue.color),
      );
    }

    if (todayExpense == 0) {
      return const _FocusStatus(
        title: 'Open day',
        message:
            'No spending has landed today. When money moves, give it a clear reason.',
        icon: Icons.wb_sunny_outlined,
        color: AppColors.primary,
      );
    }

    return const _FocusStatus(
      title: 'Steady',
      message:
          'The month is readable. Keep connecting each money moment to what it was really for.',
      icon: Icons.explore_outlined,
      color: AppColors.primary,
    );
  }

  static _FocusCta _focusCta({
    required int pendingCount,
    required int todayTransactions,
    required ValueModel? selectedValue,
  }) {
    if (pendingCount > 0) {
      return const _FocusCta(
        label: 'History',
        helper: 'Review the pending item from your transaction history.',
        route: '/transactions',
        icon: Icons.receipt_long_outlined,
      );
    }

    if (todayTransactions == 0) {
      return const _FocusCta(
        label: 'Add',
        helper: 'Start with the first money moment of the day.',
        route: '/add-session',
        icon: Icons.add_rounded,
      );
    }

    if (selectedValue == null) {
      return const _FocusCta(
        label: 'Reflect',
        helper:
            'No intention is set yet, so keep today’s spending easy to read.',
        route: '/reflect',
        icon: Icons.lightbulb_outline,
      );
    }

    return const _FocusCta(
      label: 'Reflect',
      helper:
          'Turn today’s pattern into a short weekly story when you are ready.',
      route: '/reflect',
      icon: Icons.lightbulb_outline,
    );
  }
}

class _FocusSignal extends StatelessWidget {
  const _FocusSignal({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusStatus {
  const _FocusStatus({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
}

class _FocusCta {
  const _FocusCta({
    required this.label,
    required this.helper,
    required this.route,
    required this.icon,
  });

  final String label;
  final String helper;
  final String route;
  final IconData icon;
}

class WeeklyBudgetPlanCard extends ConsumerWidget {
  const WeeklyBudgetPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(weeklyBudgetPlansProvider);
    final today = AppDateUtils.startOfDay(DateTime.now());
    final weekStart = AppDateUtils.startOfWeek(today);

    return plansAsync.when(
      loading: () => const TideCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, _) => TideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              context,
              title: '1-week budget plan',
              description: 'Debbie could not load the weekly plan.',
              action: IconButton(
                tooltip: 'Retry',
                onPressed: () =>
                    ref.read(weeklyBudgetPlansProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.expense,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      data: (plans) {
        final sortedPlans = [...plans]
          ..sort((a, b) => a.date.compareTo(b.date));
        final actualized = sortedPlans
            .where((plan) => plan.isActualized)
            .toList();
        final needsActualize = sortedPlans.where((plan) {
          final planDate = AppDateUtils.startOfDay(plan.date);
          return !plan.isActualized && !planDate.isAfter(today);
        }).length;
        final plannedActualized = actualized.fold<int>(
          0,
          (sum, plan) => sum + plan.plannedAmount,
        );
        final actualTotal = actualized.fold<int>(
          0,
          (sum, plan) => sum + (plan.actualAmount ?? 0),
        );
        final performance = plannedActualized > 0
            ? ((plannedActualized - actualTotal) / plannedActualized) * 100
            : null;
        final performanceColor = WeeklyBudgetPlanCard.performanceColor(
          performance,
        );
        final plannedWeekTotal = sortedPlans.fold<int>(
          0,
          (sum, plan) => sum + plan.plannedAmount,
        );
        final distinctLimits = sortedPlans
            .map((plan) => plan.plannedAmount)
            .toSet();
        final dailyLimit =
            distinctLimits.length == 1 && distinctLimits.isNotEmpty
            ? distinctLimits.first
            : 0;
        final description = sortedPlans.isEmpty
            ? 'Create dated plans for this week, then actualize each day from the dashboard.'
            : needsActualize > 0
            ? '$needsActualize ${needsActualize == 1 ? 'day' : 'days'} need actualization this week.'
            : 'All due days are actualized for ${AppDateUtils.formatWeekRange(weekStart)}.';

        return TideCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                context,
                title: '1-week budget plan',
                description: description,
                action: IconButton(
                  tooltip: 'Add a day',
                  onPressed: () => _showAddPlanSheet(
                    context,
                    ref,
                    weekStart: weekStart,
                    existingPlans: sortedPlans,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              if (sortedPlans.isEmpty)
                _WeeklyBudgetEmptyState(
                  onAddDay: () => _showAddPlanSheet(
                    context,
                    ref,
                    weekStart: weekStart,
                    existingPlans: const [],
                  ),
                  onQuickFill: () => _showQuickFillSheet(
                    context,
                    ref,
                    weekStart: weekStart,
                    currentDailyLimit: dailyLimit,
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _WeeklyBudgetHero(
                        label: 'Performance',
                        value: WeeklyBudgetPlanCard.formatPerformance(
                          performance,
                        ),
                        helper: performance == null
                            ? 'actualize a day'
                            : performance >= 0
                            ? 'under plan'
                            : 'over plan',
                        color: performanceColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _WeeklyBudgetHero(
                        label: 'Week plan',
                        value: CurrencyUtils.format(plannedWeekTotal),
                        helper: AppDateUtils.formatWeekRange(weekStart),
                        color: AppColors.secondaryDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.max(
                      96.0,
                      (constraints.maxWidth - 16) / 3,
                    );
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: width,
                          child: _WeeklyBudgetStat(
                            label: 'Actualized',
                            value: '${actualized.length}/7',
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _WeeklyBudgetStat(
                            label: 'Need actual',
                            value: '$needsActualize',
                            color: needsActualize > 0
                                ? AppColors.expense
                                : AppColors.textSoft,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _WeeklyBudgetStat(
                            label: plannedActualized >= actualTotal
                                ? 'Saved'
                                : 'Over',
                            value: CurrencyUtils.format(
                              (plannedActualized - actualTotal).abs(),
                            ),
                            color: plannedActualized >= actualTotal
                                ? AppColors.primary
                                : AppColors.expense,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Column(
                  children: [
                    for (final plan in sortedPlans) ...[
                      _BudgetPlanRow(
                        plan: plan,
                        today: today,
                        onActualize: () =>
                            _showActualizeSheet(context, ref, plan),
                      ),
                      if (plan != sortedPlans.last) const SizedBox(height: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Performance = (planned - actual) / planned. Spending less gives a higher score.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String title,
    required String description,
    required Widget action,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TideSurfaceIcon(
          icon: Icons.event_note_outlined,
          color: AppColors.primary,
          backgroundColor: AppColors.primary.withValues(alpha: 0.10),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        action,
      ],
    );
  }

  Future<void> _showAddPlanSheet(
    BuildContext context,
    WidgetRef ref, {
    required DateTime weekStart,
    required List<WeeklyBudgetPlanModel> existingPlans,
  }) async {
    // Pick the next unplanned day in the week as default
    final plannedDates = existingPlans
        .map((p) => AppDateUtils.startOfDay(p.date))
        .toSet();
    DateTime? defaultDate;
    for (int i = 0; i < 7; i++) {
      final d = AppDateUtils.startOfDay(weekStart.add(Duration(days: i)));
      if (!plannedDates.contains(d)) {
        defaultDate = d;
        break;
      }
    }
    defaultDate ??= AppDateUtils.startOfDay(DateTime.now());

    DateTime selectedDate = defaultDate;
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String? error;

    // Helper: prefill controllers when the date selection changes.
    // Called from event handlers (onTap), never during build.
    void prefillFor(DateTime date) {
      final plan = existingPlans
          .where((p) => AppDateUtils.isSameDay(p.date, date))
          .firstOrNull;
      if (plan != null) {
        amountController.text = CurrencyUtils.formatInput(
          plan.plannedAmount.toString(),
        );
        notesController.text = plan.notes ?? '';
      } else {
        amountController.clear();
        notesController.clear();
      }
    }

    // Initial prefill (sync, before the sheet renders)
    prefillFor(selectedDate);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            // Read-only computation during build — no mutations.
            final existingForDate = existingPlans
                .where((p) => AppDateUtils.isSameDay(p.date, selectedDate))
                .firstOrNull;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
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
                        const TideSurfaceIcon(
                          icon: Icons.edit_calendar_outlined,
                          color: AppColors.primary,
                          backgroundColor: Color(0x1A3E6C7E),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                existingForDate != null
                                    ? 'Edit day plan'
                                    : 'Plan a day',
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pick a date and how much you plan to spend.',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Date picker — 7 day chips
                    Text(
                      'Date',
                      style: Theme.of(sheetContext).textTheme.labelSmall
                          ?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 7,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final date = AppDateUtils.startOfDay(
                            weekStart.add(Duration(days: i)),
                          );
                          final isSelected = AppDateUtils.isSameDay(
                            date,
                            selectedDate,
                          );
                          final hasPlan = plannedDates.contains(date);
                          final dayName = DateFormat('E').format(date);
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selectedDate = date;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                prefillFor(date);
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 60,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    dayName.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${date.day}',
                                    style: GoogleFonts.lora(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (hasPlan)
                                    Container(
                                      margin: const EdgeInsets.only(top: 3),
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Amount
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      inputFormatters: [_CurrencyInputFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Planned amount',
                        prefixText: 'Rp ',
                        errorText: error,
                      ),
                      onChanged: (_) {
                        if (error != null) {
                          setSheetState(() => error = null);
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // Notes
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'e.g. eating out, errands',
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      children: [
                        if (existingForDate != null)
                          TextButton.icon(
                            onPressed: () async {
                              final id = existingForDate.id;
                              final navigator = Navigator.of(sheetContext);
                              await ref
                                  .read(weeklyBudgetPlansProvider.notifier)
                                  .removePlan(id);
                              if (navigator.mounted) navigator.pop();
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.expense,
                            ),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            final parsed = CurrencyUtils.parse(
                              amountController.text,
                            );
                            if (parsed == null || parsed <= 0) {
                              setSheetState(
                                () => error = 'Enter an amount above Rp 0',
                              );
                              return;
                            }
                            final date = selectedDate;
                            final notesValue = notesController.text;
                            final navigator = Navigator.of(sheetContext);
                            await ref
                                .read(weeklyBudgetPlansProvider.notifier)
                                .addPlanForDate(
                                  date: date,
                                  plannedAmount: parsed,
                                  notes: notesValue,
                                );
                            if (navigator.mounted) navigator.pop();
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            existingForDate != null ? 'Save' : 'Add plan',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // showModalBottomSheet completes on pop, but the sheet's exit animation
    // continues to rebuild its subtree (e.g. transitions reading the controllers).
    // Defer disposal until after that animation settles to avoid
    // "TextEditingController used after being disposed" crashes.
    Future.delayed(const Duration(milliseconds: 500), () {
      amountController.dispose();
      notesController.dispose();
    });
  }

  Future<void> _showQuickFillSheet(
    BuildContext context,
    WidgetRef ref, {
    required DateTime weekStart,
    required int currentDailyLimit,
  }) async {
    final controller = TextEditingController(
      text: currentDailyLimit > 0
          ? CurrencyUtils.formatInput(currentDailyLimit.toString())
          : '',
    );
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentDailyLimit > 0
                          ? 'Edit week plan'
                          : 'Create week plan',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Debbie will create one plan entry for each date in ${AppDateUtils.formatWeekRange(weekStart)}.',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      inputFormatters: [_CurrencyInputFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Daily planned amount',
                        prefixText: 'Rp ',
                        errorText: error,
                      ),
                      onChanged: (_) {
                        if (error != null) {
                          setSheetState(() => error = null);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            final parsed = CurrencyUtils.parse(controller.text);
                            if (parsed == null || parsed <= 0) {
                              setSheetState(
                                () => error = 'Enter an amount above Rp 0',
                              );
                              return;
                            }
                            final navigator = Navigator.of(sheetContext);
                            await ref
                                .read(weeklyBudgetPlansProvider.notifier)
                                .createWeekPlan(
                                  weekStart: weekStart,
                                  dailyLimit: parsed,
                                );
                            if (navigator.mounted) navigator.pop();
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Save plan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 500), controller.dispose);
  }

  Future<void> _showActualizeSheet(
    BuildContext context,
    WidgetRef ref,
    WeeklyBudgetPlanModel plan,
  ) async {
    final amountController = TextEditingController(
      text: plan.actualAmount == null
          ? ''
          : CurrencyUtils.formatInput(plan.actualAmount.toString()),
    );
    final notesController = TextEditingController(text: plan.notes ?? '');
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actualize ${DateFormat('E, d MMM').format(plan.date)}',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Planned ${CurrencyUtils.format(plan.plannedAmount)} for this date.',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      inputFormatters: [_CurrencyInputFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Actual spending',
                        prefixText: 'Rp ',
                        errorText: error,
                      ),
                      onChanged: (_) {
                        if (error != null) {
                          setSheetState(() => error = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Optional',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            final parsed = CurrencyUtils.parse(
                              amountController.text,
                            );
                            if (parsed == null || parsed < 0) {
                              setSheetState(() => error = 'Enter Rp 0 or more');
                              return;
                            }
                            final notesValue = notesController.text;
                            final navigator = Navigator.of(sheetContext);
                            await ref
                                .read(weeklyBudgetPlansProvider.notifier)
                                .actualize(
                                  plan: plan,
                                  actualAmount: parsed,
                                  notes: notesValue,
                                );
                            if (navigator.mounted) navigator.pop();
                          },
                          icon: const Icon(Icons.done_rounded, size: 18),
                          label: const Text('Save actual'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      amountController.dispose();
      notesController.dispose();
    });
  }

  static Color performanceColor(double? value) {
    if (value == null) return AppColors.textSoft;
    if (value < 0) return AppColors.expense;
    if (value == 0) return AppColors.textSoft;
    return AppColors.primary;
  }

  static String formatPerformance(double? value) {
    if (value == null) return '--';
    final rounded = value.round();
    if (rounded > 0) return '+$rounded%';
    return '$rounded%';
  }
}

class _WeeklyBudgetEmptyState extends StatelessWidget {
  const _WeeklyBudgetEmptyState({
    required this.onAddDay,
    required this.onQuickFill,
  });

  final VoidCallback onAddDay;
  final VoidCallback onQuickFill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan day by day. Pick a date, set the amount, and actualize each one when the day comes.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAddDay,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Plan a day'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onQuickFill,
                icon: const Icon(Icons.calendar_view_week_rounded, size: 18),
                label: const Text('Fill week'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyBudgetHero extends StatelessWidget {
  const _WeeklyBudgetHero({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
  });

  final String label;
  final String value;
  final String helper;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.lora(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBudgetStat extends StatelessWidget {
  const _WeeklyBudgetStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetPlanRow extends StatelessWidget {
  const _BudgetPlanRow({
    required this.plan,
    required this.today,
    required this.onActualize,
  });

  final WeeklyBudgetPlanModel plan;
  final DateTime today;
  final VoidCallback onActualize;

  @override
  Widget build(BuildContext context) {
    final planDate = AppDateUtils.startOfDay(plan.date);
    final isFuture = planDate.isAfter(today);
    final performance = plan.performancePercent;
    final statusColor = plan.isActualized
        ? WeeklyBudgetPlanCard.performanceColor(performance)
        : isFuture
        ? AppColors.textSecondary
        : AppColors.expense;
    final statusLabel = plan.isActualized
        ? 'Actualized'
        : isFuture
        ? 'Upcoming'
        : 'Need actual';
    final dayLabel = AppDateUtils.isSameDay(plan.date, today)
        ? 'Today'
        : DateFormat('EEEE').format(plan.date);
    final notes = plan.notes?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMM yyyy').format(plan.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BudgetStatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BudgetAmountChip(
                label: 'Plan',
                value: CurrencyUtils.format(plan.plannedAmount),
                color: AppColors.textSoft,
              ),
              if (plan.isActualized) ...[
                _BudgetAmountChip(
                  label: 'Actual',
                  value: CurrencyUtils.format(plan.actualAmount ?? 0),
                  color: AppColors.expense,
                ),
                _BudgetAmountChip(
                  label: 'Performance',
                  value: WeeklyBudgetPlanCard.formatPerformance(performance),
                  color: statusColor,
                ),
              ],
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          if (!isFuture || plan.isActualized) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onActualize,
                icon: Icon(
                  plan.isActualized
                      ? Icons.edit_outlined
                      : Icons.fact_check_outlined,
                  size: 18,
                ),
                label: Text(plan.isActualized ? 'Edit actual' : 'Actualize'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetAmountChip extends StatelessWidget {
  const _BudgetAmountChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 94),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetStatusPill extends StatelessWidget {
  const _BudgetStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Spotlight card for today's plan: shows planned vs current spending and
/// gives a one-tap shortcut to actualize the day from the dashboard.
/// Renders nothing if there is no plan for today.
class _TodayPlanSpotlight extends ConsumerWidget {
  const _TodayPlanSpotlight();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(weeklyBudgetPlansProvider);
    final todayAsync = ref.watch(todayTransactionsProvider);

    final plans = plansAsync.valueOrNull;
    if (plans == null) return const SizedBox.shrink();

    final today = AppDateUtils.startOfDay(DateTime.now());
    final plan = plans
        .where((p) => AppDateUtils.isSameDay(p.date, today))
        .firstOrNull;
    if (plan == null) return const SizedBox.shrink();

    // Live spending today = sum of today's expense transactions.
    final txList = todayAsync.valueOrNull ?? const <TransactionModel>[];
    final liveSpent = txList
        .where((t) => t.isExpense)
        .fold<int>(0, (sum, t) => sum + t.totalAmount);

    final isActualized = plan.isActualized;
    final shownActual = isActualized ? (plan.actualAmount ?? 0) : liveSpent;
    final remaining = plan.plannedAmount - shownActual;
    final overspent = remaining < 0;
    final progress = plan.plannedAmount <= 0
        ? 0.0
        : (shownActual / plan.plannedAmount).clamp(0.0, 1.0);

    final accent = overspent ? AppColors.expense : AppColors.primary;

    return TideCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TideSurfaceIcon(
                icon: isActualized
                    ? Icons.check_circle_outline_rounded
                    : Icons.today_rounded,
                color: accent,
                backgroundColor: accent.withValues(alpha: 0.10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TODAY'S PLAN",
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, d MMM').format(today),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              if (isActualized)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Actualized',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Hero number: today's current spending
          Text(
            isActualized ? 'Actual today' : 'Current spending',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  CurrencyUtils.format(shownActual),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'of ${CurrencyUtils.format(plan.plannedAmount)} planned',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _SpotlightStat(
                  label: 'Planned',
                  value: CurrencyUtils.format(plan.plannedAmount),
                  color: AppColors.secondaryDeep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SpotlightStat(
                  label: overspent ? 'Over' : 'Remaining',
                  value: CurrencyUtils.format(remaining.abs()),
                  color: overspent ? AppColors.expense : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!isActualized)
            Row(
              children: [
                Expanded(
                  child: Text(
                    overspent
                        ? "You're over today's plan. Actualize at end of day to lock it in."
                        : 'Tap actualize at end of day to lock today’s number in.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => const WeeklyBudgetPlanCard()
                      ._showActualizeSheet(context, ref, plan),
                  icon: const Icon(Icons.done_rounded, size: 18),
                  label: const Text('Actualize'),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    remaining >= 0
                        ? 'You came in under plan by ${CurrencyUtils.format(remaining)}.'
                        : 'You went over plan by ${CurrencyUtils.format(remaining.abs())}.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => const WeeklyBudgetPlanCard()
                      ._showActualizeSheet(context, ref, plan),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SpotlightStat extends StatelessWidget {
  const _SpotlightStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.nunito(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WeeklyBudgetPlanSummaryCard extends ConsumerWidget {
  const _WeeklyBudgetPlanSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(weeklyBudgetPlansProvider);
    final today = AppDateUtils.startOfDay(DateTime.now());

    return plansAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (plans) {
        final sorted = [...plans]..sort((a, b) => a.date.compareTo(b.date));
        final actualized = sorted.where((p) => p.isActualized).toList();
        final needsActualize = sorted.where((p) {
          final d = AppDateUtils.startOfDay(p.date);
          return !p.isActualized && !d.isAfter(today);
        }).length;
        final plannedTotal = actualized.fold<int>(
          0,
          (s, p) => s + p.plannedAmount,
        );
        final actualTotal = actualized.fold<int>(
          0,
          (s, p) => s + (p.actualAmount ?? 0),
        );
        final perf = plannedTotal > 0
            ? ((plannedTotal - actualTotal) / plannedTotal) * 100
            : null;
        final weekTotal = sorted.fold<int>(0, (s, p) => s + p.plannedAmount);

        return GestureDetector(
          onTap: () => context.push('/budget-plan'),
          child: TideCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                TideSurfaceIcon(
                  icon: Icons.event_note_outlined,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1-week budget plan',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      if (sorted.isEmpty)
                        Text(
                          'Tap to create your weekly plan',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            _SummaryChip(
                              label: WeeklyBudgetPlanCard.formatPerformance(
                                perf,
                              ),
                              color: WeeklyBudgetPlanCard.performanceColor(
                                perf,
                              ),
                            ),
                            _SummaryChip(
                              label: CurrencyUtils.format(weekTotal),
                              color: AppColors.secondaryDeep,
                            ),
                            if (needsActualize > 0)
                              _SummaryChip(
                                label: '$needsActualize need actual',
                                color: AppColors.expense,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontFamily: 'JetBrains Mono',
        ),
      ),
    );
  }
}

class _PendingPurchaseSection extends ConsumerWidget {
  const _PendingPurchaseSection({required this.transactions});

  final List<TransactionModel> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TideCard(
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
                      'A purchase you set aside is ready',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A day has passed. You can record it now or let it go.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...transactions.asMap().entries.map((entry) {
            final index = entry.key;
            final transaction = entry.value;
            final emotion = MindfulnessContent.emotionById(transaction.emotion);
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
                          const SizedBox(height: 4),
                          Text(
                            'You set aside ${CurrencyUtils.format(transaction.totalAmount)} for this on ${AppDateUtils.formatDate(transaction.date)}.',
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
                        child: const Text('Let it go'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => ref
                            .read(transactionsProvider.notifier)
                            .confirmPending(transaction.id),
                        child: const Text('Record now'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly overview — visual bar + daily average
// ---------------------------------------------------------------------------

class _MonthlyOverview extends StatelessWidget {
  const _MonthlyOverview({
    required this.income,
    required this.expenses,
    required this.budgetAsync,
  });

  final int income;
  final int expenses;
  final AsyncValue<int> budgetAsync;

  @override
  Widget build(BuildContext context) {
    final balance = income - expenses;
    final total = income + expenses;
    final incomeRatio = total > 0 ? income / total : 0.5;
    final budget = budgetAsync.valueOrNull ?? 0;
    final budgetUsed = budget > 0 ? (expenses / budget).clamp(0.0, 1.5) : 0.0;

    // Daily average
    final now = DateTime.now();
    final daysInMonth = now.day;
    final dailyAvg = daysInMonth > 0 ? (expenses / daysInMonth).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'This month',
                style: GoogleFonts.lora(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MMMM').format(now),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Income vs Expense visual bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
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
          const SizedBox(height: 14),

          // Numbers
          Row(
            children: [
              _MonthlyItem(
                label: 'Income',
                amount: income,
                color: AppColors.income,
                prefix: '+',
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 32, color: AppColors.divider),
              const SizedBox(width: 12),
              _MonthlyItem(
                label: 'Expenses',
                amount: expenses,
                color: AppColors.expense,
                prefix: '-',
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 32, color: AppColors.divider),
              const SizedBox(width: 12),
              _MonthlyItem(
                label: 'Balance',
                amount: balance.abs(),
                color: balance >= 0 ? AppColors.income : AppColors.expense,
                prefix: balance >= 0 ? '+' : '-',
              ),
            ],
          ),

          // Budget usage + daily average
          if (budget > 0 || dailyAvg > 0) ...[
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: AppColors.divider.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (budget > 0) ...[
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          budgetUsed > 1.0
                              ? Icons.warning_amber_rounded
                              : Icons.pie_chart_outline,
                          size: 14,
                          color: budgetUsed > 1.0
                              ? AppColors.expense
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${(budgetUsed * 100).round()}% of budget used',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: budgetUsed > 1.0
                                      ? AppColors.expense
                                      : AppColors.textSecondary,
                                  fontWeight: budgetUsed > 1.0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (dailyAvg > 0) ...[
                  const Icon(
                    Icons.trending_flat,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '~${CurrencyUtils.format(dailyAvg)}/day',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthlyItem extends StatelessWidget {
  const _MonthlyItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.prefix,
  });

  final String label;
  final int amount;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: amount),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '$prefix${CurrencyUtils.format(value)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Transaction trends — filterable income and outcome line charts
// ---------------------------------------------------------------------------

enum _TrendRange { daily, weekly, monthly }

extension _TrendRangeLabels on _TrendRange {
  String get label => switch (this) {
    _TrendRange.daily => 'Daily',
    _TrendRange.weekly => 'Weekly',
    _TrendRange.monthly => 'Monthly',
  };

  String get windowLabel => switch (this) {
    _TrendRange.daily => 'Last 7 days',
    _TrendRange.weekly => 'Last 8 weeks',
    _TrendRange.monthly => 'Last 6 months',
  };

  String get previousUnit => switch (this) {
    _TrendRange.daily => 'day',
    _TrendRange.weekly => 'week',
    _TrendRange.monthly => 'month',
  };

  int get labelStep => switch (this) {
    _TrendRange.daily => 1,
    _TrendRange.weekly => 2,
    _TrendRange.monthly => 1,
  };
}

class _TransactionTrendSection extends StatefulWidget {
  const _TransactionTrendSection({required this.transactions});

  final List<TransactionModel> transactions;

  @override
  State<_TransactionTrendSection> createState() =>
      _TransactionTrendSectionState();
}

class _TransactionTrendSectionState extends State<_TransactionTrendSection> {
  _TrendRange _range = _TrendRange.daily;

  @override
  Widget build(BuildContext context) {
    final outcomePoints = _buildTrendPoints(
      transactions: widget.transactions,
      type: 'expense',
      range: _range,
    );
    final incomePoints = _buildTrendPoints(
      transactions: widget.transactions,
      type: 'income',
      range: _range,
    );

    return TideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: math.max(
                  180,
                  math.min(MediaQuery.sizeOf(context).width - 72, 260),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TideSurfaceIcon(
                      icon: Icons.show_chart_rounded,
                      color: AppColors.primary,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.10,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction trend',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _range.windowLabel,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _TrendRangeSelector(
                selected: _range,
                onChanged: (range) => setState(() => _range = range),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TrendLinePanel(
            title: 'Outcome',
            subtitle: 'Recorded expense transactions',
            color: AppColors.expense,
            icon: Icons.trending_down_rounded,
            points: outcomePoints,
            range: _range,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              height: 1,
              color: AppColors.divider.withValues(alpha: 0.72),
            ),
          ),
          _TrendLinePanel(
            title: 'Income',
            subtitle: 'Recorded income transactions',
            color: AppColors.income,
            icon: Icons.trending_up_rounded,
            points: incomePoints,
            range: _range,
          ),
        ],
      ),
    );
  }

  static List<_TrendPoint> _buildTrendPoints({
    required List<TransactionModel> transactions,
    required String type,
    required _TrendRange range,
  }) {
    final now = DateTime.now();
    final buckets = <DateTime, _TrendPoint>{};

    switch (range) {
      case _TrendRange.daily:
        final start = AppDateUtils.startOfDay(
          now,
        ).subtract(const Duration(days: 6));
        for (var i = 0; i < 7; i++) {
          final day = start.add(Duration(days: i));
          buckets[day] = _TrendPoint(
            date: day,
            label: DateFormat('E').format(day).substring(0, 1),
          );
        }
      case _TrendRange.weekly:
        final thisWeek = AppDateUtils.startOfWeek(now);
        final start = thisWeek.subtract(const Duration(days: 49));
        for (var i = 0; i < 8; i++) {
          final week = start.add(Duration(days: i * 7));
          buckets[week] = _TrendPoint(
            date: week,
            label: DateFormat('d MMM').format(week),
          );
        }
      case _TrendRange.monthly:
        final start = DateTime(now.year, now.month - 5, 1);
        for (var i = 0; i < 6; i++) {
          final month = DateTime(start.year, start.month + i, 1);
          buckets[month] = _TrendPoint(
            date: month,
            label: DateFormat('MMM').format(month),
          );
        }
    }

    for (final tx in transactions) {
      if (!tx.isRecorded || tx.type != type) continue;

      final key = switch (range) {
        _TrendRange.daily => AppDateUtils.startOfDay(tx.date),
        _TrendRange.weekly => AppDateUtils.startOfWeek(tx.date),
        _TrendRange.monthly => DateTime(tx.date.year, tx.date.month, 1),
      };

      final point = buckets[key];
      if (point == null) continue;
      buckets[key] = point.copyWith(amount: point.amount + tx.totalAmount);
    }

    return buckets.values.toList(growable: false);
  }
}

class _TrendRangeSelector extends StatelessWidget {
  const _TrendRangeSelector({required this.selected, required this.onChanged});

  final _TrendRange selected;
  final ValueChanged<_TrendRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _TrendRange.values.map((range) {
        final isSelected = selected == range;
        return ChoiceChip(
          label: Text(range.label),
          selected: isSelected,
          onSelected: (_) => onChanged(range),
          showCheckmark: false,
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundColor: AppColors.surface.withValues(alpha: 0.72),
          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
          side: BorderSide(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.72)
                : AppColors.divider,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
      }).toList(),
    );
  }
}

class _TrendLinePanel extends StatelessWidget {
  const _TrendLinePanel({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.points,
    required this.range,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final List<_TrendPoint> points;
  final _TrendRange range;

  @override
  Widget build(BuildContext context) {
    final total = points.fold<int>(0, (sum, point) => sum + point.amount);
    final hasData = total > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 136),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      CurrencyUtils.format(total),
                      style: GoogleFonts.lora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _trendHelper(points, range),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: hasData ? color : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 156,
          child: _TrendLineChart(
            points: points,
            color: color,
            labelStep: range.labelStep,
            emptyLabel: 'No $title data yet',
          ),
        ),
      ],
    );
  }

  static String _trendHelper(List<_TrendPoint> points, _TrendRange range) {
    if (points.isEmpty || points.every((point) => point.amount == 0)) {
      return 'No activity';
    }

    final current = points.last.amount;
    final previous = points.length > 1 ? points[points.length - 2].amount : 0;
    final delta = current - previous;
    if (delta == 0) return 'Flat vs prior ${range.previousUnit}';
    if (previous == 0 && current > 0) {
      return 'New this ${range.previousUnit}';
    }
    final sign = delta > 0 ? '+' : '-';
    return '$sign${CurrencyUtils.format(delta.abs())} vs prior ${range.previousUnit}';
  }
}

class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({
    required this.points,
    required this.color,
    required this.labelStep,
    required this.emptyLabel,
  });

  final List<_TrendPoint> points;
  final Color color;
  final int labelStep;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendLinePainter(
        points: points,
        color: color,
        gridColor: AppColors.divider.withValues(alpha: 0.78),
        labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        emptyStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        labelStep: labelStep,
        emptyLabel: emptyLabel,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  const _TrendLinePainter({
    required this.points,
    required this.color,
    required this.gridColor,
    required this.labelStyle,
    required this.emptyStyle,
    required this.labelStep,
    required this.emptyLabel,
  });

  final List<_TrendPoint> points;
  final Color color;
  final Color gridColor;
  final TextStyle? labelStyle;
  final TextStyle? emptyStyle;
  final int labelStep;
  final String emptyLabel;

  @override
  void paint(Canvas canvas, Size size) {
    const chartTop = 10.0;
    final chartBottom = size.height - 28;
    const chartLeft = 8.0;
    final chartRight = size.width - 8;
    final chartHeight = chartBottom - chartTop;
    final chartWidth = chartRight - chartLeft;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = chartTop + (chartHeight / 3) * i;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
    }

    if (points.isEmpty) return;

    final maxAmount = points.fold<int>(
      0,
      (maxValue, point) => math.max(maxValue, point.amount),
    );
    final hasData = maxAmount > 0;
    final effectiveMax = hasData ? maxAmount * 1.12 : 1.0;
    final spacing = points.length == 1 ? 0.0 : chartWidth / (points.length - 1);
    final offsets = <Offset>[
      for (var i = 0; i < points.length; i++)
        Offset(
          chartLeft + spacing * i,
          chartTop +
              chartHeight -
              (points[i].amount / effectiveMax * chartHeight),
        ),
    ];

    _drawLabels(canvas, size, offsets);

    if (!hasData) {
      _drawCenteredText(canvas, size, emptyLabel, emptyStyle);
      return;
    }

    final linePath = _smoothPath(offsets);
    final fillPath = Path.from(linePath)
      ..lineTo(offsets.last.dx, chartBottom)
      ..lineTo(offsets.first.dx, chartBottom)
      ..close();

    final fillPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTRB(chartLeft, chartTop, chartRight, chartBottom),
          );
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = color;
    final dotBorderPaint = Paint()..color = AppColors.surface;
    for (final offset in offsets) {
      canvas.drawCircle(offset, 4.4, dotBorderPaint);
      canvas.drawCircle(offset, 2.7, dotPaint);
    }
  }

  Path _smoothPath(List<Offset> offsets) {
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    if (offsets.length == 1) return path;

    for (var i = 1; i < offsets.length; i++) {
      final previous = offsets[i - 1];
      final current = offsets[i];
      final midpoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    path.lineTo(offsets.last.dx, offsets.last.dy);
    return path;
  }

  void _drawLabels(Canvas canvas, Size size, List<Offset> offsets) {
    for (var i = 0; i < points.length; i++) {
      final shouldDraw =
          i == 0 || i == points.length - 1 || i % math.max(labelStep, 1) == 0;
      if (!shouldDraw) continue;

      final painter = TextPainter(
        text: TextSpan(text: points[i].label, style: labelStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 48);
      final dx = (offsets[i].dx - painter.width / 2).clamp(
        0.0,
        size.width - painter.width,
      );
      painter.paint(canvas, Offset(dx, size.height - 20));
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    Size size,
    String text,
    TextStyle? style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width - 24);
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        (size.height - painter.height) / 2 - 8,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelStep != labelStep ||
        oldDelegate.emptyLabel != emptyLabel;
  }
}

class _TrendPoint {
  const _TrendPoint({required this.date, required this.label, this.amount = 0});

  final DateTime date;
  final String label;
  final int amount;

  _TrendPoint copyWith({int? amount}) {
    return _TrendPoint(date: date, label: label, amount: amount ?? this.amount);
  }
}

// ---------------------------------------------------------------------------
// Dashboard analytics — compact month pulse
// ---------------------------------------------------------------------------

class _MonthPulseAnalytics extends StatelessWidget {
  const _MonthPulseAnalytics({
    required this.monthTransactions,
    required this.allTransactions,
    required this.values,
    required this.budget,
  });

  final List<TransactionModel> monthTransactions;
  final List<TransactionModel> allTransactions;
  final List<ValueModel> values;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = AppDateUtils.startOfDay(now);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final elapsedDays = now.day.clamp(1, daysInMonth);
    final expenseTransactions = monthTransactions
        .where((tx) => tx.isRecorded && tx.isExpense)
        .toList();
    final monthExpense = _sumExpenses(expenseTransactions);
    final dailyAverage = elapsedDays > 0
        ? (monthExpense / elapsedDays).round()
        : 0;
    final projectedSpend = dailyAverage * daysInMonth;
    final paceRatio = budget > 0 ? projectedSpend / budget : 0.0;
    final paceColor = budget > 0 && paceRatio > 1.0
        ? AppColors.expense
        : AppColors.primary;
    final paceLabel = budget <= 0
        ? 'Current pace'
        : paceRatio > 1.08
        ? '${((paceRatio - 1) * 100).round()}% over pace'
        : paceRatio < 0.92
        ? '${((1 - paceRatio) * 100).round()}% under pace'
        : 'On pace';

    final last7Start = today.subtract(const Duration(days: 6));
    final previous7Start = today.subtract(const Duration(days: 13));
    final previous7End = today.subtract(const Duration(days: 7));
    final last7 = _expenseBetween(allTransactions, last7Start, today);
    final previous7 = _expenseBetween(
      allTransactions,
      previous7Start,
      previous7End,
    );
    final weeklyDelta = last7 - previous7;
    final weeklyDeltaPct = previous7 > 0 ? weeklyDelta / previous7 : null;
    final topInsight = _topSpendInsight(expenseTransactions, values);
    final biggestDay = _biggestExpenseDay(expenseTransactions);
    final dayTotals = List.generate(7, (index) {
      final day = last7Start.add(Duration(days: index));
      return _DailySpend(
        day: day,
        amount: _expenseForDay(allTransactions, day),
      );
    });

    return TideCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surface,
          AppColors.surfaceWarm,
          AppColors.primary.withValues(alpha: 0.08),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TideSurfaceIcon(
                icon: Icons.insights_rounded,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Month pulse',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expenseTransactions.isEmpty
                          ? 'Analytics will appear once this month has spending.'
                          : 'A quick read on pace, momentum, and where money is moving.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Open analytics',
                onPressed: () => context.push('/analytics'),
                icon: const Icon(Icons.arrow_forward_rounded),
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (expenseTransactions.isEmpty)
            _EmptyPulseState(onOpenAnalytics: () => context.push('/analytics'))
          else ...[
            Row(
              children: [
                Expanded(
                  child: _PulseHeroMetric(
                    label: 'Projected spend',
                    value: CurrencyUtils.format(projectedSpend),
                    helper: paceLabel,
                    color: paceColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PulseHeroMetric(
                    label: 'Last 7 days',
                    value: CurrencyUtils.format(last7),
                    helper: _weeklyDeltaLabel(weeklyDelta, weeklyDeltaPct),
                    color: weeklyDelta <= 0
                        ? AppColors.income
                        : AppColors.expense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SevenDaySpendBars(days: dayTotals),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PulseMiniMetric(
                    icon: topInsight.icon,
                    label: topInsight.label,
                    value: CurrencyUtils.format(topInsight.amount),
                    color: topInsight.color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PulseMiniMetric(
                    icon: Icons.calendar_today_outlined,
                    label: biggestDay == null
                        ? 'Biggest day'
                        : DateFormat('d MMM').format(biggestDay.day),
                    value: biggestDay == null
                        ? CurrencyUtils.format(0)
                        : CurrencyUtils.format(biggestDay.amount),
                    color: AppColors.secondaryDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PulseMiniMetric(
                    icon: Icons.trending_flat_rounded,
                    label: 'Daily avg',
                    value: CurrencyUtils.format(dailyAverage),
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static int _sumExpenses(List<TransactionModel> transactions) {
    return transactions.fold<int>(0, (sum, tx) => sum + tx.totalAmount);
  }

  static int _expenseBetween(
    List<TransactionModel> transactions,
    DateTime start,
    DateTime end,
  ) {
    return transactions
        .where((tx) {
          final day = AppDateUtils.startOfDay(tx.date);
          return tx.isRecorded &&
              tx.isExpense &&
              !day.isBefore(start) &&
              !day.isAfter(end);
        })
        .fold<int>(0, (sum, tx) => sum + tx.totalAmount);
  }

  static int _expenseForDay(List<TransactionModel> transactions, DateTime day) {
    final normalized = AppDateUtils.startOfDay(day);
    return transactions
        .where((tx) {
          return tx.isRecorded &&
              tx.isExpense &&
              AppDateUtils.isSameDay(tx.date, normalized);
        })
        .fold<int>(0, (sum, tx) => sum + tx.totalAmount);
  }

  static _SpendInsight _topSpendInsight(
    List<TransactionModel> transactions,
    List<ValueModel> values,
  ) {
    final byValue = <String, int>{};
    final byTag = <String, int>{};
    var unlinked = 0;

    for (final tx in transactions) {
      for (final item in tx.items) {
        if (item.valueId != null) {
          byValue[item.valueId!] = (byValue[item.valueId!] ?? 0) + item.amount;
        } else if (item.tags.isNotEmpty) {
          final tag = item.tags.first;
          byTag[tag] = (byTag[tag] ?? 0) + item.amount;
        } else {
          unlinked += item.amount;
        }
      }
    }

    if (byValue.isNotEmpty) {
      final top = byValue.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final value = values.where((v) => v.id == top.key).firstOrNull;
      if (value != null) {
        return _SpendInsight(
          label: value.name,
          amount: top.value,
          color: AppColors.fromHex(value.color),
          icon: value.icon,
        );
      }
      unlinked += top.value;
    }

    if (byTag.isNotEmpty) {
      final top = byTag.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return _SpendInsight(
        label: top.key,
        amount: top.value,
        color: AppColors.primary,
        icon: '#',
      );
    }

    return _SpendInsight(
      label: 'Unlinked',
      amount: unlinked,
      color: AppColors.textSecondary,
      icon: Icons.label_outline,
    );
  }

  static _DailySpend? _biggestExpenseDay(List<TransactionModel> transactions) {
    if (transactions.isEmpty) return null;
    final byDay = <DateTime, int>{};
    for (final tx in transactions) {
      final day = AppDateUtils.startOfDay(tx.date);
      byDay[day] = (byDay[day] ?? 0) + tx.totalAmount;
    }
    final top = byDay.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return _DailySpend(day: top.key, amount: top.value);
  }

  static String _weeklyDeltaLabel(int delta, double? pct) {
    if (pct == null) {
      return delta == 0 ? 'No prior week yet' : 'New activity';
    }
    if (delta == 0) return 'Same as previous week';
    final direction = delta > 0 ? 'up' : 'down';
    return '$direction ${(pct.abs() * 100).round()}% vs prior week';
  }
}

class _PulseHeroMetric extends StatelessWidget {
  const _PulseHeroMetric({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
  });

  final String label;
  final String value;
  final String helper;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.75)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.lora(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PulseMiniMetric extends StatelessWidget {
  const _PulseMiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final Object icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final iconWidget = icon is IconData
        ? Icon(icon as IconData, size: 16, color: color)
        : Text(icon.toString(), style: const TextStyle(fontSize: 15));

    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              iconWidget,
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SevenDaySpendBars extends StatelessWidget {
  const _SevenDaySpendBars({required this.days});

  final List<_DailySpend> days;

  @override
  Widget build(BuildContext context) {
    final maxAmount = days.fold<int>(
      0,
      (maxValue, day) => math.max(maxValue, day.amount),
    );

    return Container(
      height: 126,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final heightFactor = maxAmount > 0
              ? (day.amount / maxAmount).clamp(0.08, 1.0)
              : 0.08;
          final isToday = AppDateUtils.isSameDay(day.day, DateTime.now());
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heightFactor,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.primary
                                : AppColors.expense.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    DateFormat('E').format(day.day).substring(0, 1),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isToday
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyPulseState extends StatelessWidget {
  const _EmptyPulseState({required this.onOpenAnalytics});

  final VoidCallback onOpenAnalytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Record a few expenses and this card will show pace, weekly movement, and your strongest spending pattern.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onOpenAnalytics, child: const Text('Open')),
        ],
      ),
    );
  }
}

class _SpendInsight {
  const _SpendInsight({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final int amount;
  final Color color;
  final Object icon;
}

class _DailySpend {
  const _DailySpend({required this.day, required this.amount});

  final DateTime day;
  final int amount;
}

// ---------------------------------------------------------------------------
// Values Wheel section with alignment score
// ---------------------------------------------------------------------------

class _ValuesWheelSection extends StatelessWidget {
  const _ValuesWheelSection({
    required this.values,
    required this.spendingByValue,
    required this.planAsync,
    required this.expenses,
  });

  final List<ValueModel> values;
  final AsyncValue<Map<String, int>> spendingByValue;
  final AsyncValue<List<ValuesPlanModel>> planAsync;
  final int expenses;

  @override
  Widget build(BuildContext context) {
    final spending = spendingByValue.valueOrNull ?? {};
    if (spending.isEmpty) return const SizedBox.shrink();

    // Build wheel segments
    final segments = <WheelSegment>[];
    int totalSpending = 0;
    for (final entry in spending.entries) {
      final value = values.where((v) => v.id == entry.key).firstOrNull;
      if (value == null) continue;
      segments.add(
        WheelSegment(
          value: value,
          amount: entry.value,
          color: AppColors.fromHex(value.color),
        ),
      );
      totalSpending += entry.value;
    }

    segments.sort((a, b) => b.amount.compareTo(a.amount));

    // Calculate alignment score
    final plans = planAsync.valueOrNull ?? [];
    final alignmentScore = _calculateAlignment(spending, plans, totalSpending);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.donut_large_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your energy this month',
                    style: GoogleFonts.lora(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (alignmentScore != null)
                  AlignmentScore(score: alignmentScore),
              ],
            ),
            const SizedBox(height: 8),
            ValuesWheel(segments: segments, totalSpending: totalSpending),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: segments.map((s) {
                final pct = totalSpending > 0
                    ? (s.amount / totalSpending * 100).round()
                    : 0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${s.value.icon} ${s.value.name} $pct%',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                );
              }).toList(),
            ),
            if (alignmentScore != null) ...[
              const SizedBox(height: 12),
              Text(
                _alignmentMessage(alignmentScore),
                style: GoogleFonts.lora(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  double? _calculateAlignment(
    Map<String, int> spending,
    List<ValuesPlanModel> plans,
    int totalSpending,
  ) {
    if (plans.isEmpty || totalSpending == 0) return null;

    final totalPlanned = plans.fold<int>(0, (s, p) => s + p.amount);
    if (totalPlanned == 0) return null;

    final allIds = <String>{...spending.keys, ...plans.map((p) => p.valueId)};

    double diffSum = 0;
    for (final id in allIds) {
      final actualFraction = (spending[id] ?? 0) / totalSpending;
      final planAmount = plans
          .where((p) => p.valueId == id)
          .fold<int>(0, (s, p) => s + p.amount);
      final planFraction = planAmount / totalPlanned;
      diffSum += (actualFraction - planFraction).abs();
    }

    return (1 - diffSum / 2).clamp(0.0, 1.0);
  }

  String _alignmentMessage(double score) {
    final pct = (score * 100).round();
    if (score >= 0.8) {
      return 'Beautiful, $pct% of your energy this month went to what matters most';
    } else if (score >= 0.6) {
      return '$pct% aligned with your intentions — you\'re on a meaningful path';
    } else if (score >= 0.4) {
      return '$pct% aligned — small shifts can bring you closer to your values';
    } else {
      return '$pct% aligned — a good moment to reflect on what matters to you';
    }
  }
}

// ---------------------------------------------------------------------------
// Plan vs Actual — horizontal progress bars per value
// ---------------------------------------------------------------------------

class _PlanVsActual extends StatelessWidget {
  const _PlanVsActual({
    required this.values,
    required this.spendingByValue,
    required this.planAsync,
  });

  final List<ValueModel> values;
  final AsyncValue<Map<String, int>> spendingByValue;
  final AsyncValue<List<ValuesPlanModel>> planAsync;

  @override
  Widget build(BuildContext context) {
    final plans = planAsync.valueOrNull ?? [];
    if (plans.isEmpty) return const SizedBox.shrink();

    final spending = spendingByValue.valueOrNull ?? {};

    // Build rows for each planned value
    final rows = <_PlanRow>[];
    for (final plan in plans) {
      if (plan.amount <= 0) continue;
      final value = values.where((v) => v.id == plan.valueId).firstOrNull;
      if (value == null) continue;
      final spent = spending[plan.valueId] ?? 0;
      rows.add(_PlanRow(value: value, planned: plan.amount, spent: spent));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.balance_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Plan vs Actual',
                  style: GoogleFonts.lora(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...rows.map((row) {
              final color = AppColors.fromHex(row.value.color);
              final ratio = row.planned > 0 ? row.spent / row.planned : 0.0;
              final isOver = ratio > 1.0;
              final remaining = row.planned - row.spent;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          row.value.icon,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            row.value.name,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          remaining >= 0
                              ? '${CurrencyUtils.format(remaining)} left'
                              : '${CurrencyUtils.format(remaining.abs())} over',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isOver
                                    ? AppColors.expense
                                    : AppColors.textSecondary,
                                fontFamily: 'JetBrains Mono',
                                fontWeight: isOver
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress bar
                    Stack(
                      children: [
                        // Background (planned)
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // Actual (spent)
                        FractionallySizedBox(
                          widthFactor: ratio.clamp(0.0, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: isOver ? AppColors.expense : color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CurrencyUtils.format(row.spent),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: color,
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                              ),
                        ),
                        Text(
                          CurrencyUtils.format(row.planned),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PlanRow {
  const _PlanRow({
    required this.value,
    required this.planned,
    required this.spent,
  });

  final ValueModel value;
  final int planned;
  final int spent;
}

// ---------------------------------------------------------------------------
// Impact Goals section
// ---------------------------------------------------------------------------

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({required this.goalsAsync, required this.values});

  final AsyncValue<List<GoalModel>> goalsAsync;
  final List<ValueModel> values;

  @override
  Widget build(BuildContext context) {
    final goals = goalsAsync.valueOrNull ?? [];
    if (goals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Impact Goals',
                style: GoogleFonts.lora(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: goals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final goal = goals[i];
              final value = values
                  .where((v) => v.id == goal.valueId)
                  .firstOrNull;
              return GoalCard(goal: goal, value: value);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly reflection prompt
// ---------------------------------------------------------------------------

class _ReflectionPrompt extends ConsumerStatefulWidget {
  const _ReflectionPrompt({
    required this.latestJournal,
    required this.spendingByValue,
    required this.values,
  });

  final AsyncValue<dynamic> latestJournal;
  final AsyncValue<Map<String, int>> spendingByValue;
  final List<ValueModel> values;

  @override
  ConsumerState<_ReflectionPrompt> createState() => _ReflectionPromptState();
}

class _ReflectionPromptState extends ConsumerState<_ReflectionPrompt> {
  String? _aiResponse;
  bool _aiLoading = false;

  static const _questions = [
    'How does that feel?',
    'Is this where you want your energy to flow?',
    'What would you change?',
  ];

  @override
  Widget build(BuildContext context) {
    final latest = widget.latestJournal.valueOrNull;
    if (latest != null) {
      final daysSince = DateTime.now().difference(latest.date).inDays;
      if (daysSince < 7) return const SizedBox.shrink();
    }

    final spending = widget.spendingByValue.valueOrNull ?? {};
    if (spending.isEmpty) return const SizedBox.shrink();

    final topEntry = spending.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    final topValue = widget.values
        .where((v) => v.id == topEntry.key)
        .firstOrNull;
    if (topValue == null) return const SizedBox.shrink();

    final question = _questions[DateTime.now().day % _questions.length];
    final amountStr = CurrencyUtils.format(topEntry.value);
    final aiService = ref.watch(aiReflectionServiceProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.15),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/reflect/new'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Time to reflect',
                            style: GoogleFonts.lora(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This week, $amountStr of your energy went to ${topValue.name}. $question',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),

                // AI Reflection
                if (aiService != null) ...[
                  const SizedBox(height: 12),
                  if (_aiLoading)
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.aiReflectionLoading,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    )
                  else if (_aiResponse != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: AppColors.primary.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AI Reflection',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _aiResponse!,
                            style: GoogleFonts.lora(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _getAiReflection(
                          aiService,
                          spending,
                          topValue,
                          topEntry.value,
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text(AppStrings.getAiReflection),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _getAiReflection(
    AiReflectionService service,
    Map<String, int> spending,
    ValueModel topValue,
    int topAmount,
  ) async {
    setState(() => _aiLoading = true);
    final result = await service.generateWeeklyReflection(
      spendingByValue: spending,
      values: widget.values,
      topValueName: topValue.name,
      topValueAmount: topAmount,
    );
    if (!mounted) return;

    final text = switch (result) {
      AiReflectionSuccess(:final text) => text,
      AiReflectionError(:final message) => message,
    };

    if (result is AiReflectionSuccess) {
      final reflection = AiReflectionModel(
        id: IdGenerator.generate(),
        type: 'weekly',
        content: text,
        contextSummary:
            'Top value: ${topValue.name}, ${CurrencyUtils.format(topAmount)}',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      ref.read(aiReflectionsRepositoryProvider).insert(reflection);
    }

    setState(() {
      _aiLoading = false;
      _aiResponse = text;
    });
  }
}

class _MonthlyLetterCard extends StatelessWidget {
  const _MonthlyLetterCard({
    required this.values,
    required this.transactions,
    required this.entries,
    required this.spendingByValue,
  });

  final List<ValueModel> values;
  final List<TransactionModel> transactions;
  final List<JournalEntryModel> entries;
  final Map<String, int> spendingByValue;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty && entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final monthStart = AppDateUtils.startOfMonth(DateTime.now());
    final monthLabel = AppDateUtils.formatMonthDisplay(monthStart);
    final monthEntries = entries.where((entry) {
      final entryMonth =
          entry.periodStart ?? AppDateUtils.startOfMonth(entry.date);
      return AppDateUtils.isSameDay(
        AppDateUtils.startOfMonth(entryMonth),
        monthStart,
      );
    }).toList();

    final letter = _buildMonthlyLetter(
      values: values,
      transactions: transactions,
      entries: monthEntries,
      spendingByValue: spendingByValue,
    );
    if (letter == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.mail_outline_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Letter from Debbie',
                style: GoogleFonts.lora(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              monthLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TideCard(
          child: Text(
            letter,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.85,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  String? _buildMonthlyLetter({
    required List<ValueModel> values,
    required List<TransactionModel> transactions,
    required List<JournalEntryModel> entries,
    required Map<String, int> spendingByValue,
  }) {
    final expenses = transactions.where((tx) => tx.isExpense).toList();
    final totalExpense = expenses.fold<int>(
      0,
      (sum, tx) => sum + tx.totalAmount,
    );
    if (totalExpense == 0 && entries.isEmpty) return null;

    final valueById = {for (final value in values) value.id: value};
    final topSpendingEntry = spendingByValue.entries.isEmpty
        ? null
        : spendingByValue.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final topValue = topSpendingEntry != null
        ? valueById[topSpendingEntry.key]
        : null;

    final emotionCounts = <String, int>{};
    final emotionsByValue = <String, Map<String, int>>{};
    final notes = <String>[];

    for (final tx in expenses) {
      if (tx.notes?.trim().isNotEmpty == true) {
        notes.add(tx.notes!.trim());
      }
      if (tx.emotion != null) {
        emotionCounts[tx.emotion!] = (emotionCounts[tx.emotion!] ?? 0) + 1;
        final valueIds = tx.items
            .where((item) => item.valueId != null)
            .map((item) => item.valueId!)
            .toSet();
        for (final valueId in valueIds) {
          final bucket = emotionsByValue.putIfAbsent(
            valueId,
            () => <String, int>{},
          );
          bucket[tx.emotion!] = (bucket[tx.emotion!] ?? 0) + 1;
        }
      }
    }

    final dominantEmotionId = emotionCounts.entries.isEmpty
        ? null
        : emotionCounts.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;
    final dominantEmotion = MindfulnessContent.emotionById(dominantEmotionId);

    String? strongestEmotionPattern;
    if (emotionsByValue.isNotEmpty) {
      final entry = emotionsByValue.entries.reduce((a, b) {
        final aTotal = a.value.values.fold<int>(0, (sum, count) => sum + count);
        final bTotal = b.value.values.fold<int>(0, (sum, count) => sum + count);
        return aTotal >= bTotal ? a : b;
      });
      if (entry.key.isNotEmpty) {
        final topEmotionId = entry.value.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
        final emotion = MindfulnessContent.emotionById(topEmotionId);
        final value = valueById[entry.key];
        if (emotion != null && value != null) {
          strongestEmotionPattern =
              'You most often felt ${emotion.label.toLowerCase()} around ${value.name}.';
        }
      }
    }

    final latestEntry = entries.isEmpty ? null : entries.first;
    final guardian = topValue?.guardianText?.trim();
    final noteLine = notes.isEmpty
        ? null
        : 'One note you left yourself still lingers: "${notes.first}".';
    final journalLine = latestEntry == null
        ? null
        : 'Your reflections kept returning to: "${_excerpt(latestEntry.content, maxChars: 110)}"';

    final parts = <String>[
      'Dear you, this month your energy moved most toward ${topValue?.name ?? 'what mattered most'}, ${topSpendingEntry != null ? 'with ${CurrencyUtils.format(topSpendingEntry.value)} directed there.' : 'and that says something important about what you are choosing to protect.'}',
      if (guardian != null && guardian.isNotEmpty)
        '${topValue!.name} seems to matter because $guardian.',
      if (dominantEmotion != null)
        'The feeling that showed up most often was ${dominantEmotion.label.toLowerCase()}, which gives the numbers a heartbeat instead of leaving them flat.',
      if (strongestEmotionPattern != null) strongestEmotionPattern,
      if (noteLine != null) noteLine,
      if (journalLine != null) journalLine,
      'What matters is not perfection. It is that you kept paying attention, and that attention is changing the story.',
    ];

    return parts.join(' ');
  }

  String _excerpt(String text, {int maxChars = 140}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars).trimRight()}...';
  }
}

// ---------------------------------------------------------------------------
// Recurring commitments mini-card for the dashboard
// ---------------------------------------------------------------------------

class _RecurringCommitmentsCard extends ConsumerWidget {
  const _RecurringCommitmentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(recurringMonthSummaryProvider);

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.totalCount == 0) return const SizedBox.shrink();

        final progress = summary.progressFraction.clamp(0.0, 1.0);
        final allPaid = summary.unpaidCount == 0;

        return TideCard(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => GoRouter.of(context).push('/recurring'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TideSurfaceIcon(
                      icon: Icons.repeat_rounded,
                      color: allPaid ? AppColors.secondary : AppColors.primary,
                      backgroundColor: allPaid
                          ? AppColors.secondary.withValues(alpha: 0.10)
                          : AppColors.primary.withValues(alpha: 0.10),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            allPaid
                                ? 'All commitments paid'
                                : '${summary.unpaidCount} commitment${summary.unpaidCount == 1 ? '' : 's'} remaining',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            allPaid
                                ? CurrencyUtils.format(summary.paidTotal)
                                : '${CurrencyUtils.format(summary.paidTotal)} of ${CurrencyUtils.format(summary.totalCommitment)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'JetBrains Mono',
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        allPaid ? AppColors.secondary : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Available balance — cumulative all-time income minus expenses
// ---------------------------------------------------------------------------

class _AvailableBalanceCard extends StatelessWidget {
  const _AvailableBalanceCard({
    required this.availableAsync,
    required this.totalInAsync,
    required this.totalOutAsync,
  });

  final AsyncValue<int> availableAsync;
  final AsyncValue<int> totalInAsync;
  final AsyncValue<int> totalOutAsync;

  static const _gradientPositive = [
    Color(0xFF2D7A55),
    Color(0xFF3D9168),
    Color(0xFF4AA87A),
  ];
  static const _gradientNegative = [
    Color(0xFF8B3A2A),
    Color(0xFFAF5040),
    Color(0xFFCF7B5F),
  ];

  @override
  Widget build(BuildContext context) {
    final available = availableAsync.valueOrNull ?? 0;
    final totalIn = totalInAsync.valueOrNull ?? 0;
    final totalOut = totalOutAsync.valueOrNull ?? 0;
    final isLoading = availableAsync.isLoading;
    final isNegative = available < 0;
    final gradientColors = isNegative ? _gradientNegative : _gradientPositive;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.30),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative wave at bottom
          Positioned(
            left: -28,
            right: -28,
            bottom: -16,
            child: SizedBox(
              height: 80,
              child: CustomPaint(
                painter: _WavePainter(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Text(
                      'AVAILABLE BALANCE',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        DateFormat('d MMM yyyy').format(DateTime.now()),
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Balance number
                isLoading
                    ? SizedBox(
                        height: 44,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      )
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: available.abs().toDouble()),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isNegative ? '- Rp ' : 'Rp ',
                                style: GoogleFonts.lora(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  height: 1.8,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  NumberFormat(
                                    '#,###',
                                    'id_ID',
                                  ).format(value.round()),
                                  style: GoogleFonts.lora(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                    height: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                const SizedBox(height: 6),
                Text(
                  isNegative
                      ? 'Expenses exceed recorded income'
                      : 'Your real purchasing power',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),

                const SizedBox(height: 18),

                // Divider
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                const SizedBox(height: 14),

                // Total in / total out
                Row(
                  children: [
                    _BalanceStat(
                      label: 'Total in',
                      amount: totalIn,
                      icon: Icons.south_rounded,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    _BalanceStat(
                      label: 'Total out',
                      amount: totalOut,
                      icon: Icons.north_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat({
    required this.label,
    required this.amount,
    required this.icon,
  });

  final String label;
  final int amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.65)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white.withValues(alpha: 0.60),
                  ),
                ),
                Text(
                  CurrencyUtils.format(amount),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = CurrencyUtils.formatInput(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
