import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../data/models/value_model.dart';
import '../../../data/models/values_plan_model.dart';
import '../../../shared/constants/default_values.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../shared/utils/id_generator.dart';
import '../../../shared/widgets/help_bottom_sheet.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.values});

  final List<ValueModel> values;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _incomeController = TextEditingController();
  int _income = 0;
  late Map<String, int> _percentages;
  late Map<String, TextEditingController> _pctControllers;
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _percentages = {for (final v in widget.values) v.id: 0};
    _pctControllers = {
      for (final v in widget.values) v.id: TextEditingController(),
    };
    _incomeController.addListener(_onIncomeChanged);
  }

  @override
  void dispose() {
    _incomeController.dispose();
    for (final c in _pctControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onIncomeChanged() {
    final parsed = CurrencyUtils.parse(_incomeController.text) ?? 0;
    setState(() => _income = parsed);
  }

  int get _totalPercent => _percentages.values.fold(0, (sum, v) => sum + v);

  int get _remainingPercent => 100 - _totalPercent;

  int _amountForValue(String id) =>
      (_income * (_percentages[id] ?? 0) / 100).round();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.go('/onboarding/prioritize', extra: widget.values),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header section ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Step 2 of 2',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppStrings.planTitle,
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppStrings.planSubtitle,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => showHelpSheet(
                          context,
                          title: AppStrings.helpPlanTitle,
                          body: AppStrings.helpPlanBody,
                        ),
                        icon: Icon(
                          Icons.help_outline_rounded,
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                        tooltip: AppStrings.helpButtonLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Income input ──────────────────────────────────
                  TextField(
                    controller: _incomeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: AppStrings.monthlyIncome,
                      prefixText: 'Rp ',
                    ),
                    onChanged: (val) {
                      final formatted = CurrencyUtils.formatInput(val);
                      if (formatted != val) {
                        _incomeController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(
                            offset: formatted.length,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Allocation summary bar ──────────────────────────────
            if (_income > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: _AllocationSummary(
                  totalPercent: _totalPercent,
                  remainingPercent: _remainingPercent,
                  totalAmount: (_income * _totalPercent / 100).round(),
                  values: widget.values,
                  percentages: _percentages,
                ),
              ),

            // ── Value cards list ────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: widget.values.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final value = widget.values[index];
                  return _ValueAllocationCard(
                    index: index + 1,
                    value: value,
                    percentage: _percentages[value.id] ?? 0,
                    amount: _amountForValue(value.id),
                    income: _income,
                    controller: _pctControllers[value.id]!,
                    isExpanded: _expandedIds.contains(value.id),
                    onToggleExpand: () {
                      setState(() {
                        if (_expandedIds.contains(value.id)) {
                          _expandedIds.remove(value.id);
                        } else {
                          _expandedIds.add(value.id);
                        }
                      });
                    },
                    onPercentChanged: _income > 0
                        ? (pct) {
                            setState(() => _percentages[value.id] = pct);
                          }
                        : null,
                  );
                },
              ),
            ),

            // ── Continue button ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _income > 0 && _totalPercent > 0
                      ? _continue
                      : null,
                  child: const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _continue() {
    final month = AppDateUtils.currentMonthKey();
    final plans = widget.values.map((v) {
      return ValuesPlanModel(
        id: IdGenerator.generate(),
        valueId: v.id,
        amount: _amountForValue(v.id),
        month: month,
      );
    }).toList();
    context.go(
      '/onboarding/complete',
      extra: {'values': widget.values, 'plans': plans, 'income': _income},
    );
  }
}

// ---------------------------------------------------------------------------
// Allocation summary — progress bar + stats
// ---------------------------------------------------------------------------

class _AllocationSummary extends StatelessWidget {
  const _AllocationSummary({
    required this.totalPercent,
    required this.remainingPercent,
    required this.totalAmount,
    required this.values,
    required this.percentages,
  });

  final int totalPercent;
  final int remainingPercent;
  final int totalAmount;
  final List<ValueModel> values;
  final Map<String, int> percentages;

  @override
  Widget build(BuildContext context) {
    final isOver = remainingPercent < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOver
            ? Colors.red.withValues(alpha: 0.05)
            : AppColors.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOver ? Colors.red.withValues(alpha: 0.2) : AppColors.divider,
        ),
      ),
      child: Column(
        children: [
          // Stacked color bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  ...values.map((v) {
                    final pct = percentages[v.id] ?? 0;
                    if (pct <= 0) return const SizedBox.shrink();
                    return Expanded(
                      flex: pct,
                      child: Container(color: AppColors.fromHex(v.color)),
                    );
                  }),
                  if (remainingPercent > 0)
                    Expanded(
                      flex: remainingPercent,
                      child: Container(
                        color: AppColors.divider.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _SummaryChip(
                label: 'Allocated',
                value: '$totalPercent%',
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _SummaryChip(
                label: 'Remaining',
                value: '${remainingPercent.abs()}%',
                color: isOver ? Colors.red : AppColors.secondary,
              ),
              const Spacer(),
              Text(
                CurrencyUtils.format(totalAmount),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontFamily: 'JetBrains Mono',
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          if (isOver) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  'Total exceeds 100% — adjust your values',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.red),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Value allocation card — clean percentage input with expandable detail
// ---------------------------------------------------------------------------

class _ValueAllocationCard extends StatelessWidget {
  const _ValueAllocationCard({
    required this.index,
    required this.value,
    required this.percentage,
    required this.amount,
    required this.income,
    required this.controller,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onPercentChanged,
  });

  final int index;
  final ValueModel value;
  final int percentage;
  final int amount;
  final int income;
  final TextEditingController controller;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<int>? onPercentChanged;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromHex(value.color);

    final preset = DefaultValues.presets.firstWhere(
      (p) => p['name'] == value.name,
      orElse: () => {},
    );
    final description = preset['description'] ?? '';
    final detail = preset['detail'] ?? '';
    final suggestion = preset['suggestion'];

    return Card(
      elevation: percentage > 0 ? 1 : 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: percentage > 0
              ? color.withValues(alpha: 0.3)
              : AppColors.divider.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          // ── Main row: rank, icon+name, percentage input ─────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                // Rank number
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Icon
                Text(value.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),

                // Name + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Percentage input
                SizedBox(
                  width: 72,
                  height: 38,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _MaxValueFormatter(100),
                    ],
                    enabled: onPercentChanged != null,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      suffixText: '%',
                      suffixStyle: TextStyle(
                        color: percentage > 0
                            ? color
                            : AppColors.textSecondary.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: percentage > 0
                          ? color.withValues(alpha: 0.06)
                          : AppColors.divider.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: color.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w600,
                      color: percentage > 0 ? color : AppColors.textSecondary,
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val) ?? 0;
                      onPercentChanged?.call(parsed.clamp(0, 100));
                    },
                  ),
                ),

                // Expand toggle
                SizedBox(
                  width: 32,
                  child: IconButton(
                    onPressed: onToggleExpand,
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

          // ── Calculated amount (visible when percentage > 0) ────
          if (income > 0 && percentage > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                '= ${CurrencyUtils.format(amount)} / month',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'JetBrains Mono',
                  color: color.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
              ),
            ),

          // ── Expandable detail section ──────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.6, fontSize: 12),
                  ),
                  if (suggestion != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 14,
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Suggested: $suggestion',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

/// Limits numeric input to a maximum value.
class _MaxValueFormatter extends TextInputFormatter {
  _MaxValueFormatter(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final val = int.tryParse(newValue.text);
    if (val == null || val > max) return oldValue;
    return newValue;
  }
}
