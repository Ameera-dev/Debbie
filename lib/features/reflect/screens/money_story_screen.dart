import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../data/models/journal_entry_model.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../shared/constants/mindfulness.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../shared/utils/id_generator.dart';
import '../../../shared/widgets/tide.dart';

class MoneyStoryScreen extends ConsumerStatefulWidget {
  const MoneyStoryScreen({super.key, this.entryId});

  final String? entryId;

  @override
  ConsumerState<MoneyStoryScreen> createState() => _MoneyStoryScreenState();
}

class _MoneyStoryScreenState extends ConsumerState<MoneyStoryScreen> {
  final _contentController = TextEditingController();

  JournalEntryModel? _existing;
  bool _loading = true;
  bool _saving = false;

  DateTime get _monthStart {
    if (_existing?.periodStart != null) {
      return AppDateUtils.startOfMonth(_existing!.periodStart!);
    }
    return AppDateUtils.startOfMonth(DateTime.now());
  }

  MoneyStoryPrompt get _prompt =>
      MindfulnessContent.promptForMonth(_monthStart);

  bool get _canSave => !_saving && _contentController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onChanged);
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    final repository = ref.read(journalRepositoryProvider);
    JournalEntryModel? entry;

    if (widget.entryId != null) {
      entry = await repository.getById(widget.entryId!);
    } else {
      entry = await repository.getEntryByTypeAndPeriodStart(
        entryType: JournalEntryModel.moneyStoryType,
        periodStart: AppDateUtils.startOfMonth(DateTime.now()),
      );
    }

    if (!mounted) return;
    setState(() {
      _existing = entry;
      _contentController.text = entry?.content ?? '';
      _loading = false;
    });
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _contentController
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;

    final content = _contentController.text.trim();
    final notifier = ref.read(journalProvider.notifier);
    final now = DateTime.now();

    setState(() => _saving = true);

    try {
      final entry =
          (_existing ??
                  JournalEntryModel(
                    id: IdGenerator.generate(),
                    content: content,
                    entryType: JournalEntryModel.moneyStoryType,
                    periodStart: _monthStart,
                    date: now,
                    createdAt: now,
                  ))
              .copyWith(
                content: content,
                entryType: JournalEntryModel.moneyStoryType,
                periodStart: _monthStart,
              );

      if (_existing == null) {
        await notifier.add(entry);
      } else {
        await notifier.edit(entry);
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

    final monthLabel = AppDateUtils.formatMonthDisplay(_monthStart);

    return Scaffold(
      body: TidePageBackground(
        child: CustomScrollView(
          slivers: [
            TideScrollHeader(
              compactTitle: 'Money Story',
              eyebrow: monthLabel,
              expandedTitle: Text.rich(
                TextSpan(
                  style: GoogleFonts.lora(
                    fontSize: 30,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  children: const [
                    TextSpan(text: 'Your money has a '),
                    TextSpan(
                      text: 'history.',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              subtitle:
                  'One slower prompt each month to understand the deeper story beneath your spending.',
              showBackButton: true,
              onBackPressed: () => context.pop(),
              trailing: const TideSurfaceIcon(
                icon: Icons.auto_stories_outlined,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TideCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TideEyebrow(label: 'Prompt'),
                          const SizedBox(height: 8),
                          Text(
                            _prompt.prompt,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(height: 1.25),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'There is no right answer here. Let memory, tension, tenderness, or surprise come through.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TideCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your response',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _contentController,
                            minLines: 12,
                            maxLines: 18,
                            textCapitalization: TextCapitalization.sentences,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.8),
                            decoration: const InputDecoration(
                              hintText:
                                  'What feels true when you sit with this question?',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton(
            onPressed: _canSave ? _save : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_existing == null ? 'Save story' : 'Update story'),
          ),
        ),
      ),
    );
  }
}
