import 'package:flutter/material.dart';
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
import '../../../data/models/ai_reflection_model.dart';
import '../../../data/models/daily_intention_model.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/daily_intentions_provider.dart';
import '../../../providers/goals_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/mindfulness_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/values_provider.dart';
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
    final todayAsync = ref.watch(todayTransactionsProvider);
    final todayIntention = ref.watch(todayIntentionProvider);
    final yesterdayIntention = ref.watch(yesterdayIntentionProvider);
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
                child: _TideOverviewCard(
                  values: values,
                  spendingByValue: spendingByValue.valueOrNull ?? const {},
                  expenses: expenses,
                  budget: budget,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),

                  // ── Today's Summary ────────────────────────────────────
                  _TodaySummary(todayAsync: todayAsync),
                  const SizedBox(height: 16),

                  _DailyIntentionSection(
                    values: values,
                    todayIntention: todayIntention,
                    yesterdayIntention: yesterdayIntention,
                    allTransactions: allTransactions,
                  ),
                  if (duePendingTransactions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _PendingPurchaseSection(
                      transactions: duePendingTransactions,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Monthly Overview ───────────────────────────────────
                  _MonthlyOverview(
                    income: income,
                    expenses: expenses,
                    budgetAsync: budgetAsync,
                  ),
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
                  const SizedBox(height: 16),

                  // ── Recent Transactions ─────────────────────────────
                  _RecentTransactions(txAsync: txAsync, values: values),

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
// Today's summary — what you spent today
// ---------------------------------------------------------------------------

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.todayAsync});

  final AsyncValue<List<TransactionModel>> todayAsync;

  @override
  Widget build(BuildContext context) {
    final today = todayAsync.valueOrNull ?? [];
    if (today.isEmpty) return const SizedBox.shrink();

    int todayExpense = 0;
    int todayIncome = 0;
    for (final tx in today) {
      if (tx.isExpense) {
        todayExpense += tx.totalAmount;
      } else {
        todayIncome += tx.totalAmount;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            const Text('📊', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${today.length} ${today.length == 1 ? 'transaction' : 'transactions'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (todayExpense > 0) ...[
              Text(
                '-${CurrencyUtils.format(todayExpense)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'JetBrains Mono',
                  color: AppColors.expense,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (todayIncome > 0) const SizedBox(width: 10),
            ],
            if (todayIncome > 0)
              Text(
                '+${CurrencyUtils.format(todayIncome)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'JetBrains Mono',
                  color: AppColors.income,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyIntentionSection extends ConsumerWidget {
  const _DailyIntentionSection({
    required this.values,
    required this.todayIntention,
    required this.yesterdayIntention,
    required this.allTransactions,
  });

  final List<ValueModel> values;
  final DailyIntentionModel? todayIntention;
  final DailyIntentionModel? yesterdayIntention;
  final List<TransactionModel> allTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (values.isEmpty) return const SizedBox.shrink();

    final todayValue = values
        .where((value) => value.id == todayIntention?.valueId)
        .firstOrNull;
    final yesterdayValue = values
        .where((value) => value.id == yesterdayIntention?.valueId)
        .firstOrNull;
    final today = AppDateUtils.startOfDay(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    int todayAligned = 0;
    int yesterdayExpense = 0;
    int yesterdayAligned = 0;

    for (final tx in allTransactions) {
      final day = AppDateUtils.startOfDay(tx.date);
      if (AppDateUtils.isSameDay(day, today) && tx.isExpense) {
        for (final item in tx.items) {
          if (item.valueId == todayIntention?.valueId) {
            todayAligned += item.amount;
          }
        }
      }
      if (AppDateUtils.isSameDay(day, yesterday) && tx.isExpense) {
        yesterdayExpense += tx.totalAmount;
        for (final item in tx.items) {
          if (item.valueId == yesterdayIntention?.valueId) {
            yesterdayAligned += item.amount;
          }
        }
      }
    }

    return TideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TideSurfaceIcon(icon: Icons.wb_sunny_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily intention',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Today, I want my energy to flow toward...',
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((value) {
              final selected = todayIntention?.valueId == value.id;
              final color = AppColors.fromHex(value.color);
              return ChoiceChip(
                label: Text('${value.icon} ${value.name}'),
                selected: selected,
                onSelected: (_) => ref
                    .read(dailyIntentionsProvider.notifier)
                    .setIntention(date: today, valueId: value.id),
                selectedColor: color.withValues(alpha: 0.15),
                side: BorderSide(color: selected ? color : AppColors.divider),
                labelStyle: TextStyle(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
          if (todayValue != null) ...[
            const SizedBox(height: 12),
            Text(
              todayAligned > 0
                  ? 'So far today, ${CurrencyUtils.format(todayAligned)} has gone toward ${todayValue.name}.'
                  : '${todayValue.name} is holding the intention for today.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSoft,
                height: 1.5,
              ),
            ),
          ],
          if (yesterdayValue != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yesterday you intended ${yesterdayValue.name}.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You spent ${CurrencyUtils.format(yesterdayExpense)}, and ${CurrencyUtils.format(yesterdayAligned)} went to ${yesterdayValue.name}.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (yesterdayIntention!.hasReflection) ...[
                    const SizedBox(height: 10),
                    Text(
                      '"${yesterdayIntention!.reflection!.trim()}"',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _openIntentionReflectionDialog(
                        context,
                        ref,
                        yesterdayIntention!,
                        yesterdayValue,
                        yesterdayExpense,
                        yesterdayAligned,
                      ),
                      icon: const Icon(Icons.edit_note_outlined, size: 18),
                      label: const Text('How did that feel?'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openIntentionReflectionDialog(
    BuildContext context,
    WidgetRef ref,
    DailyIntentionModel intention,
    ValueModel value,
    int totalSpend,
    int alignedSpend,
  ) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Yesterday: ${value.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You spent ${CurrencyUtils.format(totalSpend)}, and ${CurrencyUtils.format(alignedSpend)} went to ${value.name}. How did that feel?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Write a short reflection',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(dailyIntentionsProvider.notifier)
                  .saveReflection(
                    intention: intention,
                    reflection: controller.text,
                  );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
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
                          final imagePath = transaction.imagePath;
                          if (imagePath != null) {
                            await ref
                                .read(imageServiceProvider)
                                .delete(imagePath);
                          }
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

          // Analytics link
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.push('/analytics'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 14,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  'View detailed analytics',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 10,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
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
// Recent transactions
// ---------------------------------------------------------------------------

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.txAsync, required this.values});

  final AsyncValue<List<TransactionModel>> txAsync;
  final List<ValueModel> values;

  @override
  Widget build(BuildContext context) {
    final transactions = txAsync.valueOrNull ?? [];
    if (transactions.isEmpty) return const SizedBox.shrink();

    final recent = transactions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.history_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Recent',
                style: GoogleFonts.lora(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/transactions'),
              child: const Text('See all'),
            ),
          ],
        ),
        ...recent.map((tx) => _RecentTile(transaction: tx, values: values)),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.transaction, required this.values});

  final TransactionModel transaction;
  final List<ValueModel> values;

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
    final color = isExpense ? AppColors.expense : AppColors.income;

    // Find the primary value from items
    ValueModel? primaryValue;
    for (final item in transaction.items) {
      if (item.valueId != null) {
        primaryValue = values.where((v) => v.id == item.valueId).firstOrNull;
        if (primaryValue != null) break;
      }
    }

    final iconBgColor = primaryValue != null
        ? AppColors.fromHex(primaryValue.color).withValues(alpha: 0.12)
        : color.withValues(alpha: 0.08);
    final icon = primaryValue?.icon ?? (isExpense ? '💸' : '💰');
    final hasMultipleItems = transaction.itemCount > 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/transactions/${transaction.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(width: 12),
              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.displayTitle.isNotEmpty
                          ? transaction.displayTitle
                          : (isExpense ? 'Expense' : 'Income'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (hasMultipleItems) ...[
                          Text(
                            '${transaction.itemCount} items',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                          ),
                          Container(
                            width: 3,
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: const BoxDecoration(
                              color: AppColors.divider,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        Text(
                          AppDateUtils.formatDate(transaction.date),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount
              Text(
                CurrencyUtils.formatSigned(
                  transaction.totalAmount,
                  isExpense: isExpense,
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'JetBrains Mono',
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
