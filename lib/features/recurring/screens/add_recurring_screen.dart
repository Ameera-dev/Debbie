import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../data/models/recurring_expense_model.dart';
import '../../../data/models/value_model.dart';
import '../../../providers/recurring_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/id_generator.dart';
import '../../../shared/widgets/tide.dart';

class AddRecurringScreen extends ConsumerStatefulWidget {
  const AddRecurringScreen({super.key, this.editExpense});

  final RecurringExpenseModel? editExpense;

  @override
  ConsumerState<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _AddRecurringScreenState extends ConsumerState<AddRecurringScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();
  final _nameFocus = FocusNode();

  String _payType = RecurringExpenseModel.payTypeManual;
  String? _selectedValueId;
  int? _dueDay;
  bool _saving = false;

  bool get _isEditing => widget.editExpense != null;
  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      (CurrencyUtils.parse(_amountController.text) ?? 0) > 0;

  @override
  void initState() {
    super.initState();

    // Set initial values BEFORE attaching listeners so the listeners
    // don't fire setState during initState (before the first build).
    final e = widget.editExpense;
    if (e != null) {
      _nameController.text = e.name;
      _amountController.text = CurrencyUtils.formatInput(e.amount.toString());
      _categoryController.text = e.category ?? '';
      _notesController.text = e.notes ?? '';
      _payType = e.payType;
      _selectedValueId = e.valueId;
      _dueDay = e.dueDay;
    }

    _nameController.addListener(_rebuild);
    _amountController.addListener(_rebuild);
    _categoryController.addListener(_rebuild);
    _notesController.addListener(_rebuild);
  }

  void _rebuild() {
    if (!mounted) return;
    // Defer to the end of the current frame so we never call setState
    // mid-build (e.g. during a programmatic controller change inside an
    // event handler that's still in progress).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_rebuild);
    _amountController.removeListener(_rebuild);
    _categoryController.removeListener(_rebuild);
    _notesController.removeListener(_rebuild);
    _nameController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = CurrencyUtils.parse(_amountController.text);

    if (name.isEmpty || amount == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      final category = _categoryController.text.trim();
      final notes = _notesController.text.trim();

      if (_isEditing) {
        final updated = widget.editExpense!.copyWith(
          name: name,
          amount: amount,
          category: category.isEmpty ? null : category,
          notes: notes.isEmpty ? null : notes,
          valueId: _selectedValueId,
          payType: _payType,
          dueDay: _dueDay,
          clearCategory: category.isEmpty,
          clearNotes: notes.isEmpty,
          clearValueId: _selectedValueId == null,
          clearDueDay: _dueDay == null,
        );
        await ref.read(recurringExpensesProvider.notifier).edit(updated);
      } else {
        final expense = RecurringExpenseModel(
          id: IdGenerator.generate(),
          name: name,
          amount: amount,
          category: category.isEmpty ? null : category,
          notes: notes.isEmpty ? null : notes,
          valueId: _selectedValueId,
          dueDay: _dueDay,
          payType: _payType,
          createdAt: DateTime.now(),
        );
        await ref.read(recurringExpensesProvider.notifier).add(expense);
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final expense = widget.editExpense!;
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
    if (confirmed == true && mounted) {
      await ref.read(recurringExpensesProvider.notifier).remove(expense.id);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final valuesAsync = ref.watch(valuesProvider);
    final values = valuesAsync.valueOrNull ?? <ValueModel>[];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing ? 'Edit commitment' : 'New commitment',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.expense,
              ),
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: TidePageBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Name — hero field ────────────────────────────────────
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: TextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'What is this commitment?',
                    hintStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: AppColors.textSecondary),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 16, right: 12),
                      child: Icon(
                        Icons.repeat_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Amount per month ─────────────────────────────────────
              _MonthlyCostField(
                controller: _amountController,
                onChanged: (v) {
                  final formatted = CurrencyUtils.formatInput(v);
                  _amountController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              const TideEyebrow(label: 'Details'),
              const SizedBox(height: 10),

              // ── Pay type ─────────────────────────────────────────────
              TideCard(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    _PayTypeBtn(
                      label: 'Manual',
                      subtitle: 'I pay it myself',
                      icon: Icons.touch_app_outlined,
                      selected: _payType == RecurringExpenseModel.payTypeManual,
                      onTap: () => setState(
                        () => _payType = RecurringExpenseModel.payTypeManual,
                      ),
                    ),
                    _PayTypeBtn(
                      label: 'Auto-deducted',
                      subtitle: 'Charged automatically',
                      icon: Icons.autorenew_rounded,
                      selected: _payType == RecurringExpenseModel.payTypeAuto,
                      onTap: () => setState(
                        () => _payType = RecurringExpenseModel.payTypeAuto,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Due day — inline grid ─────────────────────────────────
              TideCard(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        const TideEyebrow(label: 'Due day each month'),
                        const Spacer(),
                        if (_dueDay != null)
                          GestureDetector(
                            onTap: () => setState(() => _dueDay = null),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DayGrid(
                      selected: _dueDay,
                      onSelect: (d) =>
                          setState(() => _dueDay = _dueDay == d ? null : d),
                    ),
                  ],
                ),
              ),

              // ── Link to value ─────────────────────────────────────────
              if (values.isNotEmpty) ...[
                const SizedBox(height: 10),
                TideCard(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          TideEyebrow(label: 'Link to a value (optional)'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: values.map((v) {
                          final color = AppColors.fromHex(v.color);
                          final isSelected = _selectedValueId == v.id;
                          return GestureDetector(
                            onTap: () => setState(
                              () => _selectedValueId = isSelected ? null : v.id,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color
                                    : color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    v.icon,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    v.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Category (optional) ───────────────────────────────────
              const SizedBox(height: 10),
              _CategoryField(
                controller: _categoryController,
                onChanged: () {},
                onClear: () => _categoryController.clear(),
                onSelect: (cat) {
                  final isActive =
                      _categoryController.text.trim().toLowerCase() ==
                      cat.toLowerCase();
                  _categoryController.text = isActive ? '' : cat;
                  HapticFeedback.selectionClick();
                },
              ),

              const SizedBox(height: 10),

              // ── Notes ─────────────────────────────────────────────────
              _NotesField(
                controller: _notesController,
                onChanged: () {},
                onClear: () => _notesController.clear(),
              ),
            ],
          ),
        ),
      ),

      // ── Save button at bottom ─────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            child: ElevatedButton(
              onPressed: (_canSave && !_saving) ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSave
                    ? AppColors.primary
                    : AppColors.divider,
                foregroundColor: Colors.white,
                elevation: _canSave ? 4 : 0,
                shadowColor: AppColors.primary.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                  : Text(
                      _isEditing ? 'Save changes' : 'Add commitment',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly cost field
// ---------------------------------------------------------------------------

class _MonthlyCostField extends StatelessWidget {
  const _MonthlyCostField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.isNotEmpty;

    return TideCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 15,
                color: AppColors.expense.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              const TideEyebrow(label: 'Monthly cost'),
              const Spacer(),
              Text(
                'required',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.expense.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasValue
                    ? AppColors.expense.withValues(alpha: 0.45)
                    : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                _CurrencyPrefix(active: hasValue),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w800,
                      color: hasValue
                          ? AppColors.expense
                          : AppColors.textSecondary.withValues(alpha: 0.55),
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(
                            fontFamily: 'JetBrains Mono',
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.32,
                            ),
                            fontWeight: FontWeight.w700,
                          ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: onChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '/ month',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyPrefix extends StatelessWidget {
  const _CurrencyPrefix({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? AppColors.expense.withValues(alpha: 0.1)
            : AppColors.paperDim.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Rp',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontFamily: 'JetBrains Mono',
          color: active ? AppColors.expense : AppColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category field
// ---------------------------------------------------------------------------

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onSelect,
  });

  static const _suggestions = [
    'Subscription',
    'Bills',
    'Housing',
    'Transport',
    'Insurance',
    'Utilities',
  ];

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final value = controller.text.trim();

    return TideCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldHeader(
            icon: Icons.local_offer_outlined,
            iconColor: AppColors.primary,
            label: 'Category',
            trailing: value.isEmpty
                ? const _OptionalText()
                : _ClearFieldButton(onTap: onClear),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Subscription, housing, utilities...',
              prefixIcon: const Icon(Icons.sell_outlined, size: 18),
              suffixIcon: value.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear category',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: onClear,
                    ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _suggestions.map((cat) {
              final isActive = value.toLowerCase() == cat.toLowerCase();
              return _SuggestionChip(
                label: cat,
                selected: isActive,
                onTap: () => onSelect(cat),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notes field
// ---------------------------------------------------------------------------

class _NotesField extends StatelessWidget {
  const _NotesField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final count = controller.text.length;

    return TideCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldHeader(
            icon: Icons.edit_note_rounded,
            iconColor: AppColors.secondary,
            label: 'Notes',
            trailing: count == 0
                ? const _OptionalText()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$count chars',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ClearFieldButton(onTap: onClear),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Add renewal details, account notes, or why it stays.',
              alignLabelWithHint: true,
              contentPadding: const EdgeInsets.all(14),
              suffixIcon: count == 0
                  ? null
                  : IconButton(
                      tooltip: 'Clear notes',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: onClear,
                    ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _FieldHeader extends StatelessWidget {
  const _FieldHeader({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        TideEyebrow(label: label),
        const Spacer(),
        trailing,
      ],
    );
  }
}

class _OptionalText extends StatelessWidget {
  const _OptionalText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'optional',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textSecondary.withValues(alpha: 0.75),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ClearFieldButton extends StatelessWidget {
  const _ClearFieldButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          'Clear',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pay type button
// ---------------------------------------------------------------------------

class _PayTypeBtn extends StatelessWidget {
  const _PayTypeBtn({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppColors.textSecondary.withValues(alpha: 0.65),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day grid — inline 1–31 picker
// ---------------------------------------------------------------------------

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.selected, required this.onSelect});

  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(31, (i) {
        final day = i + 1;
        final isSelected = selected == day;
        return GestureDetector(
          onTap: () => onSelect(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.divider,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }
}
