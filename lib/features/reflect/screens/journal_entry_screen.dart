import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../data/models/journal_entry_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/value_model.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../shared/utils/id_generator.dart';
import '../../../shared/widgets/tide.dart';
import '../widgets/mood_selector.dart';

class JournalEntryScreen extends ConsumerStatefulWidget {
  const JournalEntryScreen({super.key, this.entryId});

  final String? entryId;

  @override
  ConsumerState<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends ConsumerState<JournalEntryScreen> {
  final _contentController = TextEditingController();

  String? _mood;
  JournalEntryModel? _existing;
  bool _loading = true;
  bool _saving = false;

  bool get _isLegacyEntry => _existing?.isLegacyEntry ?? false;

  DateTime get _targetWeekStart {
    if (_existing?.periodStart != null) {
      return AppDateUtils.startOfWeek(_existing!.periodStart!);
    }
    if (_existing != null && _existing!.isWeeklyCheckIn) {
      return AppDateUtils.startOfWeek(_existing!.date);
    }
    return AppDateUtils.startOfWeek(DateTime.now());
  }

  bool get _canSave => !_saving && _contentController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onContentChanged);
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    final repository = ref.read(journalRepositoryProvider);
    JournalEntryModel? entry;

    if (widget.entryId != null) {
      entry = await repository.getById(widget.entryId!);
    } else {
      entry = await repository.getWeeklyCheckInForPeriodStart(
        AppDateUtils.startOfWeek(DateTime.now()),
      );
    }

    if (!mounted) return;
    setState(() {
      _existing = entry;
      _contentController.text = entry?.content ?? '';
      _mood = entry?.mood;
      _loading = false;
    });
  }

  void _onContentChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _contentController
      ..removeListener(_onContentChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;

    final notifier = ref.read(journalProvider.notifier);
    final repository = ref.read(journalRepositoryProvider);
    final content = _contentController.text.trim();
    final now = DateTime.now();

    setState(() => _saving = true);

    try {
      if (_existing != null) {
        final updated = _existing!.copyWith(
          content: content,
          mood: _mood,
          clearMood: _mood == null,
        );
        await notifier.edit(updated);
      } else {
        final weekStart = AppDateUtils.startOfWeek(now);
        final existingWeek = await repository.getWeeklyCheckInForPeriodStart(
          weekStart,
        );

        final entry =
            (existingWeek ??
                    JournalEntryModel(
                      id: IdGenerator.generate(),
                      content: content,
                      mood: _mood,
                      entryType: JournalEntryModel.weeklyCheckInType,
                      periodStart: weekStart,
                      date: now,
                      createdAt: now,
                    ))
                .copyWith(
                  content: content,
                  mood: _mood,
                  clearMood: _mood == null,
                  entryType: JournalEntryModel.weeklyCheckInType,
                  periodStart: weekStart,
                );

        if (existingWeek == null) {
          await notifier.add(entry);
        } else {
          await notifier.edit(entry);
        }
      }

      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: TidePageBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final transactions = ref.watch(transactionsProvider).valueOrNull ?? [];
    final values = ref.watch(valuesProvider).valueOrNull ?? [];
    final weekTransactions = _isLegacyEntry
        ? <TransactionModel>[]
        : (transactions
              .where((tx) => _isInWeek(tx.date, _targetWeekStart))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date)));
    final noteCount = weekTransactions
        .where((tx) => tx.notes?.trim().isNotEmpty ?? false)
        .length;
    final spendBreakdown = _buildSpendBreakdown(weekTransactions, values);
    final totalExpense = weekTransactions
        .where((tx) => tx.isExpense)
        .fold<int>(0, (sum, tx) => sum + tx.totalAmount);

    final compactTitle = _isLegacyEntry ? 'Reflection' : 'Weekly Check-In';
    final eyebrow = _isLegacyEntry ? 'Legacy reflection' : 'Weekly check-in';
    final expandedTitle = _isLegacyEntry
        ? Text.rich(
            TextSpan(
              style: GoogleFonts.lora(
                fontSize: 30,
                height: 1.05,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              children: const [
                TextSpan(text: 'Revisit this '),
                TextSpan(
                  text: 'reflection.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          )
        : Text.rich(
            TextSpan(
              style: GoogleFonts.lora(
                fontSize: 30,
                height: 1.05,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              children: const [
                TextSpan(text: 'Name what this '),
                TextSpan(
                  text: 'week',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                TextSpan(text: ' meant.'),
              ],
            ),
          );

    return Scaffold(
      body: TidePageBackground(
        child: CustomScrollView(
          slivers: [
            TideScrollHeader(
              compactTitle: compactTitle,
              eyebrow: eyebrow,
              expandedTitle: expandedTitle,
              subtitle: _isLegacyEntry
                  ? 'This older reflection stays editable, but it no longer drives the weekly flow.'
                  : 'One deeper note for the week. Short spending notes from saved sessions support it below.',
              showBackButton: true,
              onBackPressed: () => context.pop(),
              trailing: TideSurfaceIcon(
                icon: _isLegacyEntry
                    ? Icons.inventory_2_outlined
                    : Icons.edit_note_rounded,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLegacyEntry)
                      _LegacyContextCard(entry: _existing!)
                    else
                      _WeekContextCard(
                        weekStart: _targetWeekStart,
                        transactionCount: weekTransactions.length,
                        noteCount: noteCount,
                        totalExpense: totalExpense,
                        spendBreakdown: spendBreakdown,
                        hasExistingDraft: _existing != null,
                      ),
                    const SizedBox(height: 24),
                    Text(
                      _isLegacyEntry
                          ? 'How did this reflection feel?'
                          : 'How did this week feel?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mood is optional, but it helps color the story you are telling yourself.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    MoodSelector(
                      selectedMood: _mood,
                      onChanged: (mood) => setState(() => _mood = mood),
                    ),
                    const SizedBox(height: 24),
                    TideCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isLegacyEntry ? 'Reflection' : 'Your weekly note',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isLegacyEntry
                                ? 'You can still edit this older entry, even though new reflections now happen as weekly check-ins.'
                                : 'This is the one place to pull the week together. Let the short transaction notes stay small, and use this space for the larger meaning.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _contentController,
                            minLines: 10,
                            maxLines: 18,
                            textCapitalization: TextCapitalization.sentences,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.8),
                            decoration: InputDecoration(
                              hintText: _isLegacyEntry
                                  ? 'What feels worth keeping from this reflection?'
                                  : 'What did this week teach you about where your energy went?',
                              filled: false,
                              alignLabelWithHint: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isLegacyEntry) ...[
                      const SizedBox(height: 16),
                      TideCard(
                        color: AppColors.surface,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 14,
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Need a starting point?',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: AppColors.secondaryDeep,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _pickPrompts(3).map((prompt) {
                                return GestureDetector(
                                  onTap: () {
                                    if (_contentController.text
                                        .trim()
                                        .isEmpty) {
                                      _contentController.text = '$prompt\n\n';
                                      _contentController
                                          .selection = TextSelection.collapsed(
                                        offset: _contentController.text.length,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.divider,
                                      ),
                                    ),
                                    child: Text(
                                      prompt,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.textSoft),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: ElevatedButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _existing == null ? 'Save weekly check-in' : 'Save changes',
                  ),
          ),
        ),
      ),
    );
  }
}

class _WeekContextCard extends StatelessWidget {
  const _WeekContextCard({
    required this.weekStart,
    required this.transactionCount,
    required this.noteCount,
    required this.totalExpense,
    required this.spendBreakdown,
    required this.hasExistingDraft,
  });

  final DateTime weekStart;
  final int transactionCount;
  final int noteCount;
  final int totalExpense;
  final List<_ValueSpend> spendBreakdown;
  final bool hasExistingDraft;

  @override
  Widget build(BuildContext context) {
    return TideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TideSurfaceIcon(
                icon: Icons.calendar_today_rounded,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasExistingDraft
                          ? 'Continue this week’s check-in'
                          : 'This week at a glance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Keep the narrative here. The short spending notes stay attached to their sessions and feed into this weekly view.',
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
              TidePill(
                label: 'Spent ${CurrencyUtils.format(totalExpense)}',
                color: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
              ),
            ],
          ),
          if (spendBreakdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            TideStackedBar(
              segments: spendBreakdown
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
              children: spendBreakdown.take(4).map((segment) {
                return TidePill(
                  label:
                      '${segment.name} ${CurrencyUtils.format(segment.amount)}',
                  color: AppColors.textPrimary,
                  backgroundColor: segment.color.withValues(alpha: 0.12),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegacyContextCard extends StatelessWidget {
  const _LegacyContextCard({required this.entry});

  final JournalEntryModel entry;

  @override
  Widget build(BuildContext context) {
    return TideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TideSurfaceIcon(
                icon: Icons.inventory_2_outlined,
                color: AppColors.textSoft,
                backgroundColor: AppColors.surface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Archived reflection',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This entry predates the weekly check-in structure. It stays editable, but it is now treated as archive rather than part of the current flow.',
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
                label: AppDateUtils.formatDate(entry.date),
                color: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
              ),
              if (entry.mood != null)
                TidePill(
                  label: _moodLabel(entry.mood),
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                ),
            ],
          ),
        ],
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

List<_ValueSpend> _buildSpendBreakdown(
  List<TransactionModel> transactions,
  List<ValueModel> values,
) {
  final valueById = {for (final value in values) value.id: value};
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

  final entries = totals.entries.toList()
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

List<String> _pickPrompts(int count) {
  final all = List<String>.from(AppStrings.guidedJournalPrompts);
  all.shuffle();
  return all.take(count).toList();
}

String _moodLabel(String? mood) {
  switch (mood) {
    case 'grateful':
      return 'Grateful';
    case 'reflective':
      return 'Reflective';
    case 'uncertain':
      return 'Uncertain';
    case 'motivated':
      return 'Motivated';
    default:
      return 'Mood';
  }
}
