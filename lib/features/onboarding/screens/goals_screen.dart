import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/value_model.dart';
import '../../../data/models/values_plan_model.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/id_generator.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    super.key,
    required this.values,
    required this.plans,
    required this.income,
  });

  final List<ValueModel> values;
  final List<ValuesPlanModel> plans;
  final int income;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final List<_GoalDraft> _drafts = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/onboarding/plan')),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.goalsTitle,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.goalsSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ..._drafts.asMap().entries.map((entry) {
                    return _GoalDraftCard(
                      key: ValueKey(entry.key),
                      draft: entry.value,
                      values: widget.values,
                      onRemove: () =>
                          setState(() => _drafts.removeAt(entry.key)),
                    );
                  }),
                  if (_drafts.length < 3)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _drafts.add(
                            _GoalDraft(valueId: widget.values.first.id),
                          );
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add an intention'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _skip,
                      child: const Text('Skip for now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _continue,
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _skip() {
    context.go(
      '/onboarding/complete',
      extra: {
        'values': widget.values,
        'plans': widget.plans,
        'goals': <GoalModel>[],
        'income': widget.income,
      },
    );
  }

  void _continue() {
    final goals = _drafts
        .where((d) => d.title.isNotEmpty)
        .map(
          (d) => GoalModel(
            id: IdGenerator.generate(),
            title: d.title,
            valueId: d.valueId,
            targetAmount: d.targetAmount,
            currentAmount: 0,
            status: 'active',
            createdAt: DateTime.now(),
          ),
        )
        .toList();

    context.go(
      '/onboarding/complete',
      extra: {
        'values': widget.values,
        'plans': widget.plans,
        'goals': goals,
        'income': widget.income,
      },
    );
  }
}

class _GoalDraft {
  _GoalDraft({required this.valueId});
  String title = '';
  String valueId;
  int? targetAmount;
}

class _GoalDraftCard extends StatefulWidget {
  const _GoalDraftCard({
    super.key,
    required this.draft,
    required this.values,
    required this.onRemove,
  });

  final _GoalDraft draft;
  final List<ValueModel> values;
  final VoidCallback onRemove;

  @override
  State<_GoalDraftCard> createState() => _GoalDraftCardState();
}

class _GoalDraftCardState extends State<_GoalDraftCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'What do you want to work toward?',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) => widget.draft.title = v,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onRemove,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: widget.draft.valueId,
              decoration: const InputDecoration(labelText: 'Linked value'),
              items: widget.values.map((v) {
                return DropdownMenuItem(
                  value: v.id,
                  child: Text('${v.icon} ${v.name}'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => widget.draft.valueId = val);
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target amount (optional)',
                prefixText: 'Rp ',
              ),
              onChanged: (v) {
                widget.draft.targetAmount = CurrencyUtils.parse(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
