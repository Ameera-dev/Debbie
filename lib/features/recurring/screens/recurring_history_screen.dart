import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/models/recurring_payment_history_entry_model.dart';
import '../../../data/models/value_model.dart';
import '../../../providers/recurring_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/widgets/tide.dart';

class RecurringHistoryScreen extends ConsumerWidget {
  const RecurringHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(recurringPaymentHistoryProvider);
    final values =
        ref.watch(valuesProvider).valueOrNull ?? const <ValueModel>[];
    final valueById = {for (final value in values) value.id: value};

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TideEyebrow(label: 'Monthly commitments'),
            const SizedBox(height: 2),
            Text(
              'Payment history',
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
      body: TidePageBackground(
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Something went wrong: $e')),
          data: (entries) {
            if (entries.isEmpty) return const _EmptyHistoryState();

            final grouped = <String, List<RecurringPaymentHistoryEntryModel>>{};
            for (final entry in entries) {
              grouped.putIfAbsent(entry.month, () => []).add(entry);
            }

            final totalPaid = entries.fold<int>(0, (sum, entry) {
              return sum + entry.amount;
            });

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _HistorySummaryCard(
                  entryCount: entries.length,
                  monthCount: grouped.length,
                  totalPaid: totalPaid,
                  latestPaidAt: entries.first.paidAt,
                ),
                const SizedBox(height: 20),
                ...grouped.entries.expand((group) sync* {
                  yield Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: TideEyebrow(
                      label: _formatMonthLabel(group.key),
                      color: AppColors.primary,
                    ),
                  );

                  for (final entry in group.value) {
                    yield Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HistoryTile(
                        entry: entry,
                        value: entry.valueId != null
                            ? valueById[entry.valueId!]
                            : null,
                      ),
                    );
                  }

                  yield const SizedBox(height: 10);
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _formatMonthLabel(String monthKey) {
    try {
      final parsed = DateFormat('yyyy-MM').parseStrict(monthKey);
      return DateFormat('MMMM yyyy').format(parsed);
    } catch (_) {
      return monthKey;
    }
  }
}

class _HistorySummaryCard extends StatelessWidget {
  const _HistorySummaryCard({
    required this.entryCount,
    required this.monthCount,
    required this.totalPaid,
    required this.latestPaidAt,
  });

  final int entryCount;
  final int monthCount;
  final int totalPaid;
  final DateTime latestPaidAt;

  @override
  Widget build(BuildContext context) {
    final latestLabel = DateFormat(
      'd MMM yyyy, HH:mm',
    ).format(latestPaidAt.toLocal());

    return TideCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TideSurfaceIcon(
                icon: Icons.history_rounded,
                color: AppColors.primary,
                backgroundColor: Color(0x143E6C7E),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Every marked payment lands here.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap any row to open the transaction that was created from that monthly commitment.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryChip(
                label: '$entryCount payments',
                icon: Icons.receipt_long_outlined,
              ),
              _SummaryChip(
                label: '$monthCount months',
                icon: Icons.calendar_month_outlined,
              ),
              _SummaryChip(
                label: CurrencyUtils.format(totalPaid),
                icon: Icons.payments_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Latest recorded: $latestLabel',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.value});

  final RecurringPaymentHistoryEntryModel entry;
  final ValueModel? value;

  @override
  Widget build(BuildContext context) {
    final valueColor = value != null
        ? AppColors.fromHex(value!.color)
        : AppColors.primary;
    final paidLabel = DateFormat(
      'd MMM yyyy, HH:mm',
    ).format(entry.paidAt.toLocal());
    final dueDay = entry.dueDay;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: entry.transactionId == null
            ? null
            : () => context.push('/transactions/${entry.transactionId}'),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TideSurfaceIcon(
                  icon: entry.isAutoDeducted
                      ? Icons.autorenew_rounded
                      : Icons.receipt_long_outlined,
                  color: valueColor,
                  backgroundColor: valueColor.withValues(alpha: 0.10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.expenseName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Paid on $paidLabel',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (value != null)
                            _EntryChip(
                              label: value!.name,
                              iconText: value!.icon,
                              color: valueColor,
                            ),
                          _EntryChip(
                            label: entry.isAutoDeducted ? 'Auto' : 'Manual',
                            icon: entry.isAutoDeducted
                                ? Icons.bolt_rounded
                                : Icons.touch_app_rounded,
                            color: entry.isAutoDeducted
                                ? AppColors.secondaryDeep
                                : AppColors.primary,
                          ),
                          if (dueDay != null)
                            _EntryChip(
                              label: 'Due ${_ordinal(dueDay)}',
                              icon: Icons.event_repeat_rounded,
                              color: AppColors.textSecondary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyUtils.format(entry.amount),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.expense,
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(
                      entry.transactionId == null
                          ? Icons.link_off_rounded
                          : Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
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

  static String _ordinal(int n) {
    final suffix = switch (n) {
      1 || 21 || 31 => 'st',
      2 || 22 => 'nd',
      3 || 23 => 'rd',
      _ => 'th',
    };
    return '$n$suffix';
  }
}

class _EntryChip extends StatelessWidget {
  const _EntryChip({
    required this.label,
    required this.color,
    this.icon,
    this.iconText,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final String? iconText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconText != null) ...[
            Text(iconText!, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.history_toggle_off_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No payment history yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Once you mark a monthly commitment as paid, it will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
