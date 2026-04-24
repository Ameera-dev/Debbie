import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../data/models/value_model.dart';
import '../../../shared/constants/default_values.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/widgets/help_bottom_sheet.dart';
import '../../../shared/widgets/tide.dart';

class PrioritizeScreen extends StatefulWidget {
  const PrioritizeScreen({super.key, required this.selectedValues});

  final List<ValueModel> selectedValues;

  @override
  State<PrioritizeScreen> createState() => _PrioritizeScreenState();
}

class _PrioritizeScreenState extends State<PrioritizeScreen> {
  late List<ValueModel> _values;

  @override
  void initState() {
    super.initState();
    _values = List.from(widget.selectedValues);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/onboarding')),
      ),
      body: TidePageBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
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
                              // Step indicator
                              TidePill(
                                label: 'Step 1 of 2',
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.10,
                                ),
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 14),
                              Text.rich(
                                TextSpan(
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(height: 1.05),
                                  children: const [
                                    TextSpan(text: 'What matters '),
                                    TextSpan(
                                      text: 'most',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    TextSpan(text: '?'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppStrings.prioritizeSubtitle,
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
                            title: AppStrings.helpPrioritizeTitle,
                            body: AppStrings.helpPrioritizeBody,
                          ),
                          icon: Icon(
                            Icons.help_outline_rounded,
                            color: AppColors.primary.withValues(alpha: 0.6),
                          ),
                          tooltip: AppStrings.helpButtonLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Hint
                    TideCard(
                      color: AppColors.secondary.withValues(alpha: 0.06),
                      borderColor: AppColors.secondary.withValues(alpha: 0.18),
                      radius: 18,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.swap_vert_rounded,
                            size: 18,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hold and drag to reorder. Top = most important.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.secondaryDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // ── Reorderable list ────────────────────────────────────
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final t = Curves.easeInOut.transform(animation.value);
                        final elevation = 2 + 6 * t;
                        final scale = 1.0 + 0.02 * t;
                        return Transform.scale(
                          scale: scale,
                          child: Material(
                            elevation: elevation,
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.transparent,
                            child: child,
                          ),
                        );
                      },
                      child: child,
                    );
                  },
                  itemCount: _values.length,
                  onReorder: (oldIndex, newIndex) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _values.removeAt(oldIndex);
                      _values.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final value = _values[index];
                    final color = AppColors.fromHex(value.color);
                    final preset = DefaultValues.presets.firstWhere(
                      (p) => p['name'] == value.name,
                      orElse: () => {},
                    );
                    final description = preset['description'] ?? '';

                    return Padding(
                      key: ValueKey(value.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: color.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              // Rank badge
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: color,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Icon
                              Text(
                                value.icon,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),

                              // Name + description
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      value.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Drag handle
                              Icon(
                                Icons.drag_indicator_rounded,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.4,
                                ),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Continue button ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _continue,
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _continue() {
    final prioritized = _values.asMap().entries.map((e) {
      return e.value.copyWith(priority: e.key);
    }).toList();
    context.go('/onboarding/plan', extra: prioritized);
  }
}
