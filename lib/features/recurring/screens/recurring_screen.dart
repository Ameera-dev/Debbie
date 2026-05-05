import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/models/recurring_expense_model.dart';
import '../../../data/models/recurring_expense_payment_model.dart';
import '../../../data/models/value_model.dart';
import '../../../providers/recurring_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/widgets/tide.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(recurringExpensesProvider);
    final paymentsAsync = ref.watch(recurringPaymentsProvider);
    final summaryAsync = ref.watch(recurringMonthSummaryProvider);
    final valuesAsync = ref.watch(valuesProvider);
    final values = valuesAsync.valueOrNull ?? <ValueModel>[];

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
              'Bills & subscriptions',
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Payment history',
            icon: const Icon(Icons.history_rounded, size: 20),
            onPressed: () => context.push('/recurring/history'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/recurring/add'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add commitment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        elevation: 3,
      ),
      body: TidePageBackground(
        child: expensesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Something went wrong: $e')),
          data: (expenses) {
            final payments = paymentsAsync.valueOrNull ?? [];
            final paymentMap = {
              for (final p in payments) p.recurringExpenseId: p,
            };

            if (expenses.isEmpty) {
              return const _EmptyState();
            }

            // Sort: unpaid first, then paid; within each group sort by due day
            final sorted = [...expenses]
              ..sort((a, b) {
                final aPaid = paymentMap.containsKey(a.id);
                final bPaid = paymentMap.containsKey(b.id);
                if (aPaid != bPaid) return aPaid ? 1 : -1;
                final aDay = a.dueDay ?? 99;
                final bDay = b.dueDay ?? 99;
                return aDay.compareTo(bDay);
              });

            return ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                // ── Hero summary card ────────────────────────────────
                summaryAsync.when(
                  data: (summary) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SummaryCard(summary: summary),
                  ),
                  loading: () => const SizedBox(height: 120),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── Section label ────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 16, 8),
                  child: TideEyebrow(label: 'Commitments'),
                ),

                // ── Expense tiles ────────────────────────────────────
                ...sorted.indexed.map((pair) {
                  final (index, expense) = pair;
                  final payment = paymentMap[expense.id];
                  final value = values
                      .where((v) => v.id == expense.valueId)
                      .firstOrNull;
                  return _RecurringExpenseTile(
                        key: ValueKey(expense.id),
                        expense: expense,
                        payment: payment,
                        value: value,
                      )
                      .animate(delay: Duration(milliseconds: index * 55))
                      .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                      .slideY(
                        begin: 0.05,
                        end: 0,
                        duration: 300.ms,
                        curve: Curves.easeOut,
                      );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary hero card — gradient with arc progress
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final RecurringMonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.progressFraction.clamp(0.0, 1.0);
    final allDone = summary.unpaidCount == 0 && summary.totalCount > 0;
    final monthName = DateFormat('MMMM yyyy').format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: allDone
              ? [const Color(0xFF2D7A55), const Color(0xFF3D9168)]
              : [AppColors.primaryDeep, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (allDone ? const Color(0xFF2D7A55) : AppColors.primaryDeep)
                .withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Row(
          children: [
            // Arc progress on left
            SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(
                painter: _ArcProgressPainter(
                  progress: progress,
                  trackColor: Colors.white.withValues(alpha: 0.20),
                  fillColor: allDone
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.90),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        allDone ? '✓' : '${summary.paidCount}',
                        style: GoogleFonts.lora(
                          fontSize: allDone ? 22 : 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      if (!allDone)
                        Text(
                          'of ${summary.totalCount}',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Right side info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthName,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allDone ? 'All paid!' : '${summary.unpaidCount} remaining',
                    style: GoogleFonts.lora(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Thin progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.20),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MiniStat(
                        label: 'Paid',
                        value: CurrencyUtils.format(summary.paidTotal),
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      _MiniStat(
                        label: 'Left',
                        value: CurrencyUtils.format(summary.remainingTotal),
                        dimmed: summary.remainingTotal == 0,
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      _MiniStat(
                        label: 'Total',
                        value: CurrencyUtils.format(summary.totalCommitment),
                        dimmed: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.dimmed = false,
  });

  final String label;
  final String value;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.white.withValues(alpha: dimmed ? 0.50 : 0.65),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: dimmed ? 0.65 : 0.95),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Arc progress painter
// ---------------------------------------------------------------------------

class _ArcProgressPainter extends CustomPainter {
  const _ArcProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  final double progress;
  final Color trackColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 5.0;
    const startAngle = -math.pi / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcProgressPainter old) =>
      old.progress != progress;
}

// ---------------------------------------------------------------------------
// Expense tile — redesigned
// ---------------------------------------------------------------------------

class _RecurringExpenseTile extends ConsumerWidget {
  const _RecurringExpenseTile({
    super.key,
    required this.expense,
    required this.payment,
    required this.value,
  });

  final RecurringExpenseModel expense;
  final RecurringExpensePaymentModel? payment;
  final ValueModel? value;

  bool get _isPaid => payment != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valueColor = value != null
        ? AppColors.fromHex(value!.color)
        : AppColors.primary;

    final daysFromNow = expense.dueDaysFromNow();
    String? dueLabel;
    Color dueColor = AppColors.primary;
    if (!_isPaid && daysFromNow != null) {
      if (daysFromNow < 0) {
        dueLabel = 'Overdue ${daysFromNow.abs()}d';
        dueColor = AppColors.expense;
      } else if (daysFromNow == 0) {
        dueLabel = 'Due today';
        dueColor = AppColors.expense;
      } else if (daysFromNow <= 5) {
        dueLabel = 'Due in ${daysFromNow}d';
        dueColor = AppColors.primary;
      }
    }

    final accentColor = _isPaid ? AppColors.income : valueColor;

    return Dismissible(
      key: ValueKey('dismiss-${expense.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDelete(context, ref);
        return false;
      },
      onDismissed: (_) {},
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.delete_outline,
              color: AppColors.expense,
              size: 22,
            ),
            const SizedBox(height: 4),
            const Text(
              'Delete',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.expense,
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/recurring/edit', extra: expense),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left accent bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 4,
                      color: accentColor,
                    ),

                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Icon
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: _isPaid
                                      ? Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 20,
                                          color: AppColors.income,
                                        )
                                      : Text(
                                          value?.icon ??
                                              (expense.isAutoDeducted
                                                  ? '🔄'
                                                  : '📅'),
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                ),
                                const SizedBox(width: 10),

                                // Name + meta
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        expense.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: _isPaid
                                                  ? AppColors.textSecondary
                                                  : null,
                                              decoration: _isPaid
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              decorationColor:
                                                  AppColors.textSecondary,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          if (expense.dueDay != null &&
                                              !_isPaid) ...[
                                            Icon(
                                              Icons.calendar_today_outlined,
                                              size: 10,
                                              color: AppColors.textSecondary
                                                  .withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${_ordinal(expense.dueDay!)} every month',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.textSecondary
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          if (expense.isAutoDeducted)
                                            _Pill(
                                              label: 'Auto',
                                              color: AppColors.secondary,
                                            ),
                                          if (dueLabel != null) ...[
                                            if (expense.isAutoDeducted)
                                              const SizedBox(width: 4),
                                            _Pill(
                                              label: dueLabel,
                                              color: dueColor,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Amount
                                Text(
                                  CurrencyUtils.format(expense.amount),
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontFamily: 'JetBrains Mono',
                                        fontWeight: FontWeight.w700,
                                        color: _isPaid
                                            ? AppColors.textSecondary
                                                  .withValues(alpha: 0.6)
                                            : AppColors.expense,
                                        decoration: _isPaid
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: AppColors.textSecondary
                                            .withValues(alpha: 0.5),
                                      ),
                                ),
                              ],
                            ),

                            // Value chip + pay button row
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (value != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: valueColor.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          value!.icon,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          value!.name,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: valueColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (_isPaid && payment != null) ...[
                                  _Pill(
                                    label: '✓  Paid this month',
                                    color: AppColors.income,
                                  ),
                                ],
                                const Spacer(),
                                _PayButton(
                                  isPaid: _isPaid,
                                  expense: expense,
                                  payment: payment,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete commitment?'),
        content: Text(
          'Remove "${expense.name}" from your monthly commitments?\n\n'
          'Past transactions will not be affected.',
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
    if (confirmed == true) {
      ref.read(recurringExpensesProvider.notifier).remove(expense.id);
    }
  }

  String _ordinal(int n) {
    final suffix = switch (n) {
      1 || 21 || 31 => 'st',
      2 || 22 => 'nd',
      3 || 23 => 'rd',
      _ => 'th',
    };
    return '$n$suffix';
  }
}

// ---------------------------------------------------------------------------
// Pay / Undo button — redesigned
// ---------------------------------------------------------------------------

class _PayButton extends ConsumerStatefulWidget {
  const _PayButton({
    required this.isPaid,
    required this.expense,
    required this.payment,
  });

  final bool isPaid;
  final RecurringExpenseModel expense;
  final RecurringExpensePaymentModel? payment;

  @override
  ConsumerState<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends ConsumerState<_PayButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (widget.isPaid) {
      return GestureDetector(
        onTap: _undoPay,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: const Text(
            'Undo',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _markAsPaid,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.30),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 13, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Mark paid',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsPaid() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(recurringExpensesProvider.notifier)
          .markAsPaid(widget.expense);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _undoPay() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(recurringExpensesProvider.notifier)
          .unmarkAsPaid(widget.expense.id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Small pill label
// ---------------------------------------------------------------------------

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔄', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No commitments yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontFamily: 'Lora'),
            ),
            const SizedBox(height: 10),
            Text(
              'Add subscriptions, rent, utilities and any expense that repeats every month.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
