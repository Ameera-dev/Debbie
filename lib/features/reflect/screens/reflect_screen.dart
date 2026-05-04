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
    final weeklyExpenseTotal = _totalForType(weekTransactions, 'expense');
    final weeklyIncomeTotal = _totalForType(weekTransactions, 'income');

    void openCurrentWeekCheckIn() {
      if (currentWeekCheckIn != null) {
        context.push('/reflect/${currentWeekCheckIn.id}');
        return;
      }
      context.push('/reflect/new');
    }

    void openCurrentMonthStory() {
      if (currentMonthStory != null) {
        context.push('/reflect/money-story/${currentMonthStory.id}');
        return;
      }
      context.push('/reflect/money-story');
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
                  'Weekly check-in, monthly story, and the notes behind them.',
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
                    _ReflectMenuCard(
                      weekStart: weekStart,
                      monthStart: monthStart,
                      hasWeeklyCheckIn:
                          currentWeekCheckIn?.content.trim().isNotEmpty ??
                          false,
                      hasMonthStory:
                          currentMonthStory?.content.trim().isNotEmpty ?? false,
                      transactionCount: weekTransactions.length,
                      noteCount: noteTransactions.length,
                      totalExpense: weeklyExpenseTotal,
                      onOpenCheckIn: openCurrentWeekCheckIn,
                      onOpenMoneyStory: openCurrentMonthStory,
                    ),
                    const SizedBox(height: 16),
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
                      totalExpense: weeklyExpenseTotal,
                      totalIncome: weeklyIncomeTotal,
                      onOpenCheckIn: openCurrentWeekCheckIn,
                    ),
                    const SizedBox(height: 16),
                    _ReflectionLibraryCard(
                      noteTransactions: noteTransactions,
                      pastCheckIns: pastCheckIns,
                      pastMoneyStories: pastMoneyStories,
                      legacyEntries: legacyEntries,
                    ),
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

class _ReflectMenuCard extends StatelessWidget {
  const _ReflectMenuCard({
    required this.weekStart,
    required this.monthStart,
    required this.hasWeeklyCheckIn,
    required this.hasMonthStory,
    required this.transactionCount,
    required this.noteCount,
    required this.totalExpense,
    required this.onOpenCheckIn,
    required this.onOpenMoneyStory,
  });

  final DateTime weekStart;
  final DateTime monthStart;
  final bool hasWeeklyCheckIn;
  final bool hasMonthStory;
  final int transactionCount;
  final int noteCount;
  final int totalExpense;
  final VoidCallback onOpenCheckIn;
  final VoidCallback onOpenMoneyStory;

  @override
  Widget build(BuildContext context) {
    final weekLabel = AppDateUtils.formatWeekRange(weekStart);
    final activityLabel = [
      '$transactionCount session${transactionCount == 1 ? '' : 's'}',
      '$noteCount note${noteCount == 1 ? '' : 's'}',
      if (totalExpense > 0) CurrencyUtils.format(totalExpense),
    ].join(' • ');

    return TideCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TideSurfaceIcon(
                icon: Icons.explore_outlined,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start here',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Week of $weekLabel',
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
          _ReflectActionRow(
            icon: hasWeeklyCheckIn
                ? Icons.check_circle_rounded
                : Icons.edit_note_rounded,
            title: hasWeeklyCheckIn
                ? 'Edit weekly check-in'
                : 'Start weekly check-in',
            subtitle: activityLabel,
            primary: true,
            onTap: onOpenCheckIn,
          ),
          const SizedBox(height: 8),
          _ReflectActionRow(
            icon: Icons.auto_stories_outlined,
            title: hasMonthStory
                ? 'Continue monthly money story'
                : 'Open monthly money story',
            subtitle: AppDateUtils.formatMonthDisplay(monthStart),
            onTap: onOpenMoneyStory,
          ),
        ],
      ),
    );
  }
}

class _ReflectActionRow extends StatelessWidget {
  const _ReflectActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? AppColors.primary : AppColors.textPrimary;
    final background = primary
        ? AppColors.primary.withValues(alpha: 0.10)
        : AppColors.surface;
    final border = primary
        ? AppColors.primary.withValues(alpha: 0.22)
        : AppColors.divider;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primary
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : AppColors.paperDim.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 19, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
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
              Icon(
                Icons.chevron_right_rounded,
                color: primary ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReflectionLibraryCard extends StatelessWidget {
  const _ReflectionLibraryCard({
    required this.noteTransactions,
    required this.pastCheckIns,
    required this.pastMoneyStories,
    required this.legacyEntries,
  });

  final List<TransactionModel> noteTransactions;
  final List<JournalEntryModel> pastCheckIns;
  final List<JournalEntryModel> pastMoneyStories;
  final List<JournalEntryModel> legacyEntries;

  @override
  Widget build(BuildContext context) {
    return TideCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                const TideSurfaceIcon(
                  icon: Icons.folder_open_outlined,
                  color: AppColors.textSoft,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reference',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Notes and past entries',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _LibrarySection(
            icon: Icons.sticky_note_2_outlined,
            iconColor: AppColors.secondaryDeep,
            title: 'Spending notes',
            subtitle: '${noteTransactions.length} from this week',
            child: _SpendingNotesCard(
              noteTransactions: noteTransactions,
              framed: false,
            ),
          ),
          _LibrarySection(
            icon: Icons.menu_book_rounded,
            iconColor: AppColors.primary,
            title: 'Past check-ins',
            subtitle: '${pastCheckIns.length} saved',
            child: _PastCheckInsCard(entries: pastCheckIns, framed: false),
          ),
          _LibrarySection(
            icon: Icons.history_edu_outlined,
            iconColor: AppColors.secondaryDeep,
            title: 'Monthly stories',
            subtitle: '${pastMoneyStories.length} archived',
            child: _PastMoneyStoriesCard(
              entries: pastMoneyStories,
              framed: false,
            ),
          ),
          if (legacyEntries.isNotEmpty)
            _LibrarySection(
              icon: Icons.inventory_2_outlined,
              iconColor: AppColors.textSoft,
              title: 'Legacy reflections',
              subtitle: '${legacyEntries.length} older entries',
              child: _LegacyReflectionsCard(
                entries: legacyEntries,
                framed: false,
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        leading: TideSurfaceIcon(
          icon: icon,
          color: iconColor,
          backgroundColor: iconColor.withValues(alpha: 0.10),
          size: 16,
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        children: [child],
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

class _PastMoneyStoriesCard extends StatelessWidget {
  const _PastMoneyStoriesCard({required this.entries, this.framed = true});

  final List<JournalEntryModel> entries;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      final child = Text(
        'Past monthly story entries will gather here, building a quieter archive of how your relationship with money changes over time.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      );
      return framed ? TideCard(child: child) : child;
    }

    final child = Column(
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
                  padding: EdgeInsets.all(framed ? 18 : 12),
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
    );
    return framed ? TideCard(padding: EdgeInsets.zero, child: child) : child;
  }
}

class _SpendingNotesCard extends StatelessWidget {
  const _SpendingNotesCard({
    required this.noteTransactions,
    this.framed = true,
  });

  final List<TransactionModel> noteTransactions;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    if (noteTransactions.isEmpty) {
      final child = Column(
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
      );
      return framed ? TideCard(child: child) : child;
    }

    final child = Column(
      children: List.generate(noteTransactions.length, (index) {
        final transaction = noteTransactions[index];
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.all(framed ? 18 : 12),
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
                                style: Theme.of(context).textTheme.titleMedium,
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
                              label: AppDateUtils.formatDate(transaction.date),
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
    );
    return framed ? TideCard(padding: EdgeInsets.zero, child: child) : child;
  }
}

class _PastCheckInsCard extends StatelessWidget {
  const _PastCheckInsCard({required this.entries, this.framed = true});

  final List<JournalEntryModel> entries;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      final child = Text(
        'No past check-ins yet. Once you finish a weekly check-in, it will stay here as a calm archive instead of mixing with the current week.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      );
      return framed ? TideCard(child: child) : child;
    }

    final child = Column(
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
                  padding: EdgeInsets.all(framed ? 18 : 12),
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
    );
    return framed ? TideCard(padding: EdgeInsets.zero, child: child) : child;
  }
}

class _LegacyReflectionsCard extends StatelessWidget {
  const _LegacyReflectionsCard({required this.entries, this.framed = true});

  final List<JournalEntryModel> entries;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final child = Column(
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
                  padding: EdgeInsets.all(framed ? 18 : 12),
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
    );
    return framed ? TideCard(padding: EdgeInsets.zero, child: child) : child;
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
