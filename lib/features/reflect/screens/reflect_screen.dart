import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../data/models/journal_entry_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/value_model.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../services/ai_reflection_service.dart';
import '../../../shared/constants/mindfulness.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../shared/widgets/tide.dart';

class ReflectScreen extends ConsumerWidget {
  const ReflectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(journalProvider).valueOrNull ?? [];
    final allTransactions = ref.watch(transactionsProvider).valueOrNull ?? [];
    final values = ref.watch(valuesProvider).valueOrNull ?? [];
    final aiService = ref.watch(aiReflectionServiceProvider);

    final now = DateTime.now();
    final weekStart = AppDateUtils.startOfWeek(now);
    final monthStart = AppDateUtils.startOfMonth(now);
    final weekTransactions =
        allTransactions.where((tx) => _isInWeek(tx.date, weekStart)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final noteTransactions = weekTransactions
        .where((tx) => tx.notes?.trim().isNotEmpty ?? false)
        .toList();

    final valueById = {for (final value in values) value.id: value};
    final weeklySpending = _weeklyExpenseByValue(weekTransactions);
    final spendBreakdown = _buildSpendBreakdown(weeklySpending, valueById);

    final weeklyEntries = entries.where((entry) => entry.isWeeklyCheckIn);
    final currentWeekEntries =
        weeklyEntries
            .where(
              (entry) => AppDateUtils.isSameDay(
                entry.periodStart ?? AppDateUtils.startOfWeek(entry.date),
                weekStart,
              ),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final currentWeekCheckIn = currentWeekEntries.isEmpty
        ? null
        : currentWeekEntries.first;

    final pastCheckIns =
        weeklyEntries
            .where(
              (entry) => !AppDateUtils.isSameDay(
                entry.periodStart ?? AppDateUtils.startOfWeek(entry.date),
                weekStart,
              ),
            )
            .toList()
          ..sort((a, b) {
            final aStart = a.periodStart ?? AppDateUtils.startOfWeek(a.date);
            final bStart = b.periodStart ?? AppDateUtils.startOfWeek(b.date);
            final byPeriod = bStart.compareTo(aStart);
            if (byPeriod != 0) return byPeriod;
            return b.createdAt.compareTo(a.createdAt);
          });

    final moneyStoryEntries =
        entries.where((entry) => entry.isMoneyStory).toList()..sort((a, b) {
          final aStart = a.periodStart ?? AppDateUtils.startOfMonth(a.date);
          final bStart = b.periodStart ?? AppDateUtils.startOfMonth(b.date);
          final byPeriod = bStart.compareTo(aStart);
          if (byPeriod != 0) return byPeriod;
          return b.createdAt.compareTo(a.createdAt);
        });
    final currentMonthStory = moneyStoryEntries.where((entry) {
      final entryMonth =
          entry.periodStart ?? AppDateUtils.startOfMonth(entry.date);
      return AppDateUtils.isSameDay(entryMonth, monthStart);
    }).firstOrNull;
    final pastMoneyStories = moneyStoryEntries.where((entry) {
      final entryMonth =
          entry.periodStart ?? AppDateUtils.startOfMonth(entry.date);
      return !AppDateUtils.isSameDay(entryMonth, monthStart);
    }).toList();

    final legacyEntries = entries.where((entry) => entry.isLegacyEntry).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    void openCurrentWeekCheckIn() {
      if (currentWeekCheckIn != null) {
        context.push('/reflect/${currentWeekCheckIn.id}');
        return;
      }
      context.push('/reflect/new');
    }

    return Scaffold(
      body: TidePageBackground(
        child: CustomScrollView(
          slivers: [
            TideScrollHeader(
              compactTitle: 'Reflect',
              eyebrow: 'Weekly check-in',
              expandedTitle: Text.rich(
                TextSpan(
                  style: GoogleFonts.lora(
                    fontSize: 30,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  children: const [
                    TextSpan(text: 'See your week with '),
                    TextSpan(
                      text: 'care.',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              subtitle:
                  'One weekly insight, one deeper check-in, and the spending notes that shaped it.',
              trailing: const TideSurfaceIcon(icon: Icons.waves_rounded),
              actions: [
                TideHeaderIconButton(
                  icon: Icons.edit_note_rounded,
                  onPressed: openCurrentWeekCheckIn,
                  tooltip: currentWeekCheckIn == null
                      ? 'Start weekly check-in'
                      : 'Edit weekly check-in',
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionIntro(
                      eyebrow: 'This week',
                      title: "This Week's Insight",
                      subtitle:
                          'A single narrative built from your spending notes and weekly check-in.',
                    ),
                    const SizedBox(height: 10),
                    _ThisWeekInsightCard(
                      signature: _insightSignature(
                        weeklySpending: weeklySpending,
                        noteTransactions: noteTransactions,
                        currentWeekCheckIn: currentWeekCheckIn,
                      ),
                      aiService: aiService,
                      weekStart: weekStart,
                      weeklySpending: weeklySpending,
                      values: values,
                      noteTransactions: noteTransactions,
                      spendBreakdown: spendBreakdown,
                      currentWeekCheckIn: currentWeekCheckIn,
                      totalExpense: _totalForType(weekTransactions, 'expense'),
                      totalIncome: _totalForType(weekTransactions, 'income'),
                      onOpenCheckIn: openCurrentWeekCheckIn,
                    ),
                    const SizedBox(height: 24),
                    const _SectionIntro(
                      eyebrow: 'Weekly check-in',
                      title: 'One place to zoom out',
                      subtitle:
                          'Capture the meaning of the week once, instead of scattering it across multiple reflection tools.',
                    ),
                    const SizedBox(height: 10),
                    _WeeklyCheckInCard(
                      weekStart: weekStart,
                      checkIn: currentWeekCheckIn,
                      transactionCount: weekTransactions.length,
                      noteCount: noteTransactions.length,
                      totalExpense: _totalForType(weekTransactions, 'expense'),
                      onOpen: openCurrentWeekCheckIn,
                    ),
                    const SizedBox(height: 24),
                    const _SectionIntro(
                      eyebrow: 'Money story',
                      title: 'A slower monthly journal',
                      subtitle:
                          'One prompt each month to explore the history, fear, freedom, and meaning behind money itself.',
                    ),
                    const SizedBox(height: 10),
                    _MoneyStoryCard(
                      monthStart: monthStart,
                      currentMonthStory: currentMonthStory,
                    ),
                    const SizedBox(height: 16),
                    _PastMoneyStoriesCard(entries: pastMoneyStories),
                    const SizedBox(height: 24),
                    const _SectionIntro(
                      eyebrow: 'Evidence',
                      title: 'Spending Notes From This Week',
                      subtitle:
                          'Short notes saved during transactions become context for your weekly insight.',
                    ),
                    const SizedBox(height: 10),
                    _SpendingNotesCard(noteTransactions: noteTransactions),
                    const SizedBox(height: 24),
                    const _SectionIntro(
                      eyebrow: 'History',
                      title: 'Past Check-Ins',
                      subtitle:
                          'Previous weekly check-ins stay easy to revisit without competing with the current week.',
                    ),
                    const SizedBox(height: 10),
                    _PastCheckInsCard(entries: pastCheckIns),
                    if (legacyEntries.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const _SectionIntro(
                        eyebrow: 'Archive',
                        title: 'Legacy Reflections',
                        subtitle:
                            'Older reflections are still available here, but they no longer drive the weekly flow.',
                      ),
                      const SizedBox(height: 10),
                      _LegacyReflectionsCard(entries: legacyEntries),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TideEyebrow(label: eyebrow),
          const SizedBox(height: 6),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ThisWeekInsightCard extends StatefulWidget {
  const _ThisWeekInsightCard({
    required this.signature,
    required this.aiService,
    required this.weekStart,
    required this.weeklySpending,
    required this.values,
    required this.noteTransactions,
    required this.spendBreakdown,
    required this.currentWeekCheckIn,
    required this.totalExpense,
    required this.totalIncome,
    required this.onOpenCheckIn,
  });

  final String signature;
  final AiReflectionService? aiService;
  final DateTime weekStart;
  final Map<String, int> weeklySpending;
  final List<ValueModel> values;
  final List<TransactionModel> noteTransactions;
  final List<_ValueSpend> spendBreakdown;
  final JournalEntryModel? currentWeekCheckIn;
  final int totalExpense;
  final int totalIncome;
  final VoidCallback onOpenCheckIn;

  @override
  State<_ThisWeekInsightCard> createState() => _ThisWeekInsightCardState();
}

class _ThisWeekInsightCardState extends State<_ThisWeekInsightCard> {
  String? _aiInsight;
  String? _aiError;
  bool _loading = false;

  bool get _hasCheckIn =>
      widget.currentWeekCheckIn?.content.trim().isNotEmpty ?? false;
  bool get _hasNotes => widget.noteTransactions.isNotEmpty;
  bool get _isEmptyState => !_hasCheckIn && !_hasNotes;

  @override
  void didUpdateWidget(covariant _ThisWeekInsightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.signature != oldWidget.signature ||
        widget.aiService != oldWidget.aiService) {
      setState(() {
        _loading = false;
        _aiInsight = null;
        _aiError = null;
      });
    }
  }

  Future<void> _generateInsight() async {
    if (_isEmptyState) {
      if (mounted) {
        setState(() {
          _loading = false;
          _aiInsight = null;
          _aiError = null;
        });
      }
      return;
    }

    final service = widget.aiService;
    if (service == null) return;

    setState(() {
      _loading = true;
      _aiError = null;
    });
    final requestSignature = widget.signature;
    final result = await service.generateWeeklyNarrative(
      spendingByValue: widget.weeklySpending,
      values: widget.values,
      transactionNotes: widget.noteTransactions
          .map((tx) => tx.notes!.trim())
          .where((note) => note.isNotEmpty)
          .toList(),
      weeklyCheckInContent: widget.currentWeekCheckIn?.content,
      mood: widget.currentWeekCheckIn?.mood,
    );

    if (!mounted || requestSignature != widget.signature) return;
    setState(() {
      _loading = false;
      switch (result) {
        case AiReflectionSuccess(:final text):
          _aiInsight = text;
          _aiError = null;
        case AiReflectionError(:final message):
          _aiInsight = null;
          _aiError = message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fallbackInsight = _buildFallbackInsight(
      weeklySpending: widget.weeklySpending,
      values: widget.values,
      noteTransactions: widget.noteTransactions,
      currentWeekCheckIn: widget.currentWeekCheckIn,
    );
    final displayedInsight = _isEmptyState
        ? _emptyInsightCopy(hasSpendingData: widget.weeklySpending.isNotEmpty)
        : (_aiInsight ?? fallbackInsight);
    final usingAiInsight = _aiInsight != null;
    final statusLabel = _isEmptyState
        ? 'Empty'
        : _hasCheckIn
        ? 'Final'
        : 'Preview';
    final statusColor = _isEmptyState
        ? AppColors.textSecondary
        : _hasCheckIn
        ? AppColors.primary
        : AppColors.secondaryDeep;
    final statusBackground = _isEmptyState
        ? AppColors.divider.withValues(alpha: 0.7)
        : _hasCheckIn
        ? AppColors.primary.withValues(alpha: 0.12)
        : AppColors.secondary.withValues(alpha: 0.18);

    return TideCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surface,
          AppColors.surfaceWarm,
          AppColors.paperDim.withValues(alpha: 0.55),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TideSurfaceIcon(
                icon: Icons.auto_awesome_rounded,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "This Week's Insight",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isEmptyState
                          ? 'Add meaning to the week before Debbie turns it into one narrative.'
                          : 'Built from this week’s notes, check-in, and value-linked spending.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TidePill(
                label: statusLabel,
                color: statusColor,
                backgroundColor: statusBackground,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TidePill(
                label: AppDateUtils.formatWeekRange(widget.weekStart),
                color: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
              ),
              TidePill(
                label:
                    '${widget.noteTransactions.length} spending note${widget.noteTransactions.length == 1 ? '' : 's'}',
                color: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
              ),
              TidePill(
                label: 'Spent ${CurrencyUtils.format(widget.totalExpense)}',
                color: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
              ),
              if (widget.totalIncome > 0)
                TidePill(
                  label: 'Earned ${CurrencyUtils.format(widget.totalIncome)}',
                  color: AppColors.textPrimary,
                  backgroundColor: AppColors.surface,
                ),
            ],
          ),
          if (widget.spendBreakdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            TideStackedBar(
              segments: widget.spendBreakdown
                  .map(
                    (segment) => TideBarSegment(
                      color: segment.color,
                      value: segment.amount.toDouble(),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.spendBreakdown.take(4).map((segment) {
                return TidePill(
                  label:
                      '${segment.name} ${CurrencyUtils.format(segment.amount)}',
                  color: AppColors.textPrimary,
                  backgroundColor: segment.color.withValues(alpha: 0.12),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 18),
          if (_loading)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Writing this week into one clearer story...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayedInsight,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.7),
                ),
                if (!_isEmptyState) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      usingAiInsight
                          ? 'AI insight shown. Debbie will only call AI again if you press refresh.'
                          : 'Local summary shown by default. AI runs only when you ask for it.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (_aiError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _aiError!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.expense),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 16),
          if (_isEmptyState)
            ElevatedButton(
              onPressed: widget.onOpenCheckIn,
              child: const Text('Start this week’s check-in'),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (widget.aiService != null)
                  TextButton.icon(
                    onPressed: _loading ? null : _generateInsight,
                    icon: Icon(
                      usingAiInsight
                          ? Icons.refresh_rounded
                          : Icons.auto_awesome_rounded,
                      size: 18,
                    ),
                    label: Text(
                      usingAiInsight
                          ? 'Refresh AI insight'
                          : 'Generate AI insight',
                    ),
                  ),
                TextButton.icon(
                  onPressed: widget.onOpenCheckIn,
                  icon: Icon(
                    _hasCheckIn
                        ? Icons.edit_outlined
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _hasCheckIn
                        ? 'Edit weekly check-in'
                        : 'Turn this preview into a full weekly check-in',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeeklyCheckInCard extends StatelessWidget {
  const _WeeklyCheckInCard({
    required this.weekStart,
    required this.checkIn,
    required this.transactionCount,
    required this.noteCount,
    required this.totalExpense,
    required this.onOpen,
  });

  final DateTime weekStart;
  final JournalEntryModel? checkIn;
  final int transactionCount;
  final int noteCount;
  final int totalExpense;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final hasCheckIn = checkIn?.content.trim().isNotEmpty ?? false;

    return TideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TideSurfaceIcon(
                icon: Icons.edit_note_rounded,
                color: AppColors.secondaryDeep,
                backgroundColor: AppColors.secondary.withValues(alpha: 0.16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Check-In',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasCheckIn
                          ? 'Your one longer note for the week.'
                          : 'Pause once this week to name what felt true about your spending, energy, and attention.',
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
            children: [
              TidePill(
                label: 'Week of ${AppDateUtils.formatWeekRange(weekStart)}',
                color: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
              ),
              TidePill(
                label:
                    '$transactionCount session${transactionCount == 1 ? '' : 's'}',
                color: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
              ),
              TidePill(
                label: '$noteCount note${noteCount == 1 ? '' : 's'} ready',
                color: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
              ),
              if (totalExpense > 0)
                TidePill(
                  label: CurrencyUtils.format(totalExpense),
                  color: AppColors.textPrimary,
                  backgroundColor: AppColors.surface,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasCheckIn) ...[
            Text(
              _excerpt(checkIn!.content, maxChars: 240),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.7),
            ),
            if (checkIn!.mood != null) ...[
              const SizedBox(height: 12),
              TidePill(
                label: _moodLabel(checkIn!.mood),
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onOpen,
              child: const Text('Edit weekly check-in'),
            ),
          ] else ...[
            Text(
              'Use this space for the bigger story: what surprised you, where your energy leaked, and what felt aligned. Spending notes saved during the week will support the insight above, but this is where you make sense of it.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.7),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                'Helpful prompt: What part of this week felt most aligned with what matters to you, and what felt off?',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSoft),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onOpen,
              child: const Text('Start weekly check-in'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneyStoryCard extends StatelessWidget {
  const _MoneyStoryCard({
    required this.monthStart,
    required this.currentMonthStory,
  });

  final DateTime monthStart;
  final JournalEntryModel? currentMonthStory;

  @override
  Widget build(BuildContext context) {
    final prompt = MindfulnessContent.promptForMonth(monthStart);
    final hasStory = currentMonthStory?.content.trim().isNotEmpty ?? false;

    return TideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TideSurfaceIcon(
                icon: Icons.auto_stories_outlined,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppDateUtils.formatMonthDisplay(monthStart),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prompt.prompt,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasStory) ...[
            Text(
              _excerpt(currentMonthStory!.content, maxChars: 240),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.7),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  context.push('/reflect/money-story/${currentMonthStory!.id}'),
              child: const Text('Continue this month’s story'),
            ),
          ] else ...[
            Text(
              'This space moves more slowly than the weekly check-in. Use it to notice the older stories that still shape your spending today.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/reflect/money-story'),
              child: const Text('Open monthly prompt'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PastMoneyStoriesCard extends StatelessWidget {
  const _PastMoneyStoriesCard({required this.entries});

  final List<JournalEntryModel> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return TideCard(
        child: Text(
          'Past monthly story entries will gather here, building a quieter archive of how your relationship with money changes over time.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return TideCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          final month =
              entry.periodStart ?? AppDateUtils.startOfMonth(entry.date);

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => context.push('/reflect/money-story/${entry.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TideSurfaceIcon(
                          icon: Icons.history_edu_outlined,
                          color: AppColors.secondaryDeep,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppDateUtils.formatMonthDisplay(month),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _excerpt(entry.content),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSoft,
                                      height: 1.6,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index != entries.length - 1)
                Divider(
                  height: 1,
                  color: AppColors.divider.withValues(alpha: 0.8),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _SpendingNotesCard extends StatelessWidget {
  const _SpendingNotesCard({required this.noteTransactions});

  final List<TransactionModel> noteTransactions;

  @override
  Widget build(BuildContext context) {
    if (noteTransactions.isEmpty) {
      return TideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No spending notes yet this week.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'When you save a session, add one short note about what that spending meant. That note will show up here and feed your weekly insight.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return TideCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(noteTransactions.length, (index) {
          final transaction = noteTransactions[index];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TideSurfaceIcon(
                      icon: transaction.isExpense
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: transaction.isExpense
                          ? AppColors.expense
                          : AppColors.income,
                      backgroundColor: transaction.isExpense
                          ? AppColors.expense.withValues(alpha: 0.12)
                          : AppColors.income.withValues(alpha: 0.12),
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
                                  transaction.displayTitle.isEmpty
                                      ? 'Session note'
                                      : transaction.displayTitle,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyUtils.format(transaction.totalAmount),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: transaction.isExpense
                                          ? AppColors.expense
                                          : AppColors.income,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            transaction.notes!.trim(),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.65),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TidePill(
                                label: AppDateUtils.formatDate(
                                  transaction.date,
                                ),
                                color: AppColors.textPrimary,
                                backgroundColor: AppColors.surface,
                              ),
                              TidePill(
                                label:
                                    '${transaction.itemCount} item${transaction.itemCount == 1 ? '' : 's'}',
                                color: AppColors.textPrimary,
                                backgroundColor: AppColors.surface,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (index != noteTransactions.length - 1)
                Divider(
                  height: 1,
                  color: AppColors.divider.withValues(alpha: 0.8),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _PastCheckInsCard extends StatelessWidget {
  const _PastCheckInsCard({required this.entries});

  final List<JournalEntryModel> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return TideCard(
        child: Text(
          'No past check-ins yet. Once you finish a weekly check-in, it will stay here as a calm archive instead of mixing with the current week.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return TideCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          final weekStart =
              entry.periodStart ?? AppDateUtils.startOfWeek(entry.date);

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => context.push('/reflect/${entry.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TideSurfaceIcon(
                          icon: Icons.menu_book_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Week of ${AppDateUtils.formatWeekRange(weekStart)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _excerpt(entry.content),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSoft,
                                      height: 1.6,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (entry.mood != null)
                                    TidePill(
                                      label: _moodLabel(entry.mood),
                                      color: AppColors.primary,
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.10),
                                    ),
                                  TidePill(
                                    label: AppDateUtils.formatDate(entry.date),
                                    color: AppColors.textPrimary,
                                    backgroundColor: AppColors.surface,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index != entries.length - 1)
                Divider(
                  height: 1,
                  color: AppColors.divider.withValues(alpha: 0.8),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _LegacyReflectionsCard extends StatelessWidget {
  const _LegacyReflectionsCard({required this.entries});

  final List<JournalEntryModel> entries;

  @override
  Widget build(BuildContext context) {
    return TideCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(entries.length, (index) {
          final entry = entries[index];

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => context.push('/reflect/${entry.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TideSurfaceIcon(
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.textSoft,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppDateUtils.formatDate(entry.date),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _excerpt(entry.content),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSoft,
                                      height: 1.6,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index != entries.length - 1)
                Divider(
                  height: 1,
                  color: AppColors.divider.withValues(alpha: 0.8),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _ValueSpend {
  const _ValueSpend({
    required this.name,
    required this.amount,
    required this.color,
  });

  final String name;
  final int amount;
  final Color color;
}

bool _isInWeek(DateTime date, DateTime weekStart) {
  return AppDateUtils.isWithinRange(
    date,
    weekStart,
    weekStart.add(const Duration(days: 6)),
  );
}

Map<String, int> _weeklyExpenseByValue(List<TransactionModel> transactions) {
  final totals = <String, int>{};

  for (final transaction in transactions) {
    if (!transaction.isExpense) continue;
    for (final item in transaction.items) {
      final valueId = item.valueId;
      if (valueId == null) continue;
      totals.update(
        valueId,
        (value) => value + item.amount,
        ifAbsent: () => item.amount,
      );
    }
  }

  return totals;
}

List<_ValueSpend> _buildSpendBreakdown(
  Map<String, int> weeklySpending,
  Map<String, ValueModel> valueById,
) {
  final entries = weeklySpending.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return List.generate(entries.length, (index) {
    final spend = entries[index];
    final value = valueById[spend.key];
    Color color;
    if (value != null) {
      try {
        color = AppColors.fromHex(value.color);
      } catch (_) {
        color = AppColors.valueColors[index % AppColors.valueColors.length];
      }
    } else {
      color = AppColors.valueColors[index % AppColors.valueColors.length];
    }

    return _ValueSpend(
      name: value?.name ?? 'Unassigned',
      amount: spend.value,
      color: color,
    );
  });
}

int _totalForType(List<TransactionModel> transactions, String type) {
  return transactions
      .where((tx) => tx.type == type)
      .fold<int>(0, (sum, tx) => sum + tx.totalAmount);
}

String _insightSignature({
  required Map<String, int> weeklySpending,
  required List<TransactionModel> noteTransactions,
  required JournalEntryModel? currentWeekCheckIn,
}) {
  final spendSignature = weeklySpending.entries
      .map((e) => '${e.key}:${e.value}')
      .join('|');
  final notesSignature = noteTransactions
      .map((tx) => '${tx.id}:${tx.notes?.trim() ?? ''}:${tx.totalAmount}')
      .join('|');
  final checkInSignature = currentWeekCheckIn == null
      ? 'none'
      : '${currentWeekCheckIn.id}:${currentWeekCheckIn.content}:${currentWeekCheckIn.mood ?? ''}';

  return '$spendSignature::$notesSignature::$checkInSignature';
}

String _buildFallbackInsight({
  required Map<String, int> weeklySpending,
  required List<ValueModel> values,
  required List<TransactionModel> noteTransactions,
  required JournalEntryModel? currentWeekCheckIn,
}) {
  final valueById = {for (final value in values) value.id: value};
  final spendingEntries = weeklySpending.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final parts = <String>[];

  if (spendingEntries.isNotEmpty) {
    final topValue =
        valueById[spendingEntries.first.key]?.name ?? 'what matters most';
    parts.add(
      'This week, most of your spending energy flowed toward $topValue.',
    );
  }

  if (noteTransactions.isNotEmpty) {
    final count = noteTransactions.length;
    parts.add(
      count == 1
          ? 'You captured one spending note, which gives the week a more human shape.'
          : 'Your $count spending notes make the week feel more personal than the numbers alone.',
    );
  }

  if (currentWeekCheckIn?.content.trim().isNotEmpty ?? false) {
    if (currentWeekCheckIn!.mood != null) {
      parts.add(
        'Your check-in carried a ${_moodLabel(currentWeekCheckIn.mood).toLowerCase()} tone.',
      );
    } else {
      parts.add(
        'Your weekly check-in turns those moments into one clearer story.',
      );
    }
    parts.add('What part of this pattern feels worth carrying into next week?');
  } else {
    parts.add(
      'Completing the weekly check-in will help connect these moments into one clearer insight.',
    );
  }

  return parts.join(' ');
}

String _emptyInsightCopy({required bool hasSpendingData}) {
  if (hasSpendingData) {
    return 'This week already has numbers behind it, but it still needs meaning. Add one spending note when you save a session or start the weekly check-in to turn the week into a readable story.';
  }

  return 'Nothing reflective has been captured for this week yet. Start the weekly check-in when you are ready, and add short spending notes during transaction entry so this insight has something real to work with.';
}

String _moodLabel(String? mood) {
  switch (mood) {
    case 'grateful':
      return AppStrings.moodGrateful;
    case 'reflective':
      return AppStrings.moodReflective;
    case 'uncertain':
      return AppStrings.moodUncertain;
    case 'motivated':
      return AppStrings.moodMotivated;
    default:
      return 'Weekly check-in';
  }
}

String _excerpt(String text, {int maxChars = 160}) {
  final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= maxChars) return normalized;
  return '${normalized.substring(0, maxChars).trimRight()}...';
}
