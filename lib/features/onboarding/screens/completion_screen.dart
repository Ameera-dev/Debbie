import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../data/database/tables.dart';
import '../../../data/models/value_model.dart';
import '../../../data/models/values_plan_model.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/id_generator.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/values_provider.dart';

class CompletionScreen extends ConsumerStatefulWidget {
  const CompletionScreen({
    super.key,
    required this.values,
    required this.plans,
    required this.income,
  });

  final List<ValueModel> values;
  final List<ValuesPlanModel> plans;
  final int income;

  @override
  ConsumerState<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<CompletionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build the plan summary for display
    final planMap = <String, int>{};
    for (final p in widget.plans) {
      planMap[p.valueId] = p.amount;
    }

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),

                  // ── Celebration header ────────────────────────────
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('✨', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.completionTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.displaySmall?.copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your energy is now aligned with what matters most to you.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Summary card ──────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your plan',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${CurrencyUtils.format(widget.income)} / month',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontFamily: 'JetBrains Mono',
                              ),
                        ),
                        const SizedBox(height: 14),

                        // Stacked color bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 6,
                            child: Row(
                              children: widget.values.map((v) {
                                final amt = planMap[v.id] ?? 0;
                                if (amt <= 0) {
                                  return const SizedBox.shrink();
                                }
                                return Expanded(
                                  flex: amt,
                                  child: Container(
                                    color: AppColors.fromHex(v.color),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Value breakdown
                        ...widget.values.map((v) {
                          final amt = planMap[v.id] ?? 0;
                          if (amt <= 0) return const SizedBox.shrink();
                          final pct = widget.income > 0
                              ? (amt / widget.income * 100).round()
                              : 0;
                          final color = AppColors.fromHex(v.color);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  v.icon,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    v.name,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                                Text(
                                  '$pct%',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    CurrencyUtils.format(amt),
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          fontFamily: 'JetBrains Mono',
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Open Debbie button ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveAndContinue,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(AppStrings.completionButton),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final now = DateTime.now();
      final savedValues = widget.values.asMap().entries.map((e) {
        return e.value.copyWith(
          id: IdGenerator.generate(),
          priority: e.key,
          createdAt: now,
        );
      }).toList();

      final idMap = <String, String>{};
      for (var i = 0; i < widget.values.length; i++) {
        idMap[widget.values[i].id] = savedValues[i].id;
      }

      final updatedPlans = widget.plans.map((p) {
        return p.copyWith(
          id: IdGenerator.generate(),
          valueId: idMap[p.valueId] ?? p.valueId,
        );
      }).toList();

      await ref.read(valuesRepositoryProvider).insertAll(savedValues);
      await ref.read(valuesRepositoryProvider).upsertAllPlans(updatedPlans);

      await ref
          .read(settingsRepositoryProvider)
          .setInt(SettingsKeys.monthlyIncome, widget.income);

      await ref
          .read(settingsRepositoryProvider)
          .setBool(SettingsKeys.onboardingComplete, value: true);

      if (mounted) {
        ref.invalidate(onboardingCompleteProvider);
        ref.invalidate(valuesProvider);
        ref.invalidate(currentMonthPlanProvider);
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
