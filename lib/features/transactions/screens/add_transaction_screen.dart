import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../data/models/transaction_item_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../shared/constants/default_tags.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/id_generator.dart';
import '../widgets/tag_picker.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _descController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();

  String _type = 'expense';
  String? _selectedValueId;
  List<String> _selectedTags = [];
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _descController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valuesAsync = ref.watch(valuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.addTransactionTitle),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Type toggle ──────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _TypeToggle(
                    label: AppStrings.expense,
                    selected: _type == 'expense',
                    color: AppColors.expense,
                    onTap: () => setState(() {
                      _type = 'expense';
                      _selectedTags = [];
                    }),
                  ),
                  _TypeToggle(
                    label: AppStrings.income,
                    selected: _type == 'income',
                    color: AppColors.income,
                    onTap: () => setState(() {
                      _type = 'income';
                      _selectedTags = [];
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Amount ───────────────────────────────────────────────
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFamily: 'JetBrains Mono',
                color: _type == 'expense'
                    ? AppColors.expense
                    : AppColors.income,
              ),
              decoration: const InputDecoration(
                hintText: '0',
                prefixText: 'Rp ',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                final formatted = CurrencyUtils.formatInput(val);
                if (formatted != val) {
                  _amountController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                }
              },
            ),
            const Divider(),
            const SizedBox(height: 16),

            // ── Description ──────────────────────────────────────────
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                hintText: AppStrings.descriptionHint,
              ),
            ),
            const SizedBox(height: 16),

            // ── Tag picker ───────────────────────────────────────────
            Row(
              children: [
                const _SectionLabel(label: 'Tags'),
                const SizedBox(width: 6),
                Text(
                  '(pick one or more)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._selectedTags.map((tag) {
                  final icon = _tagParentIcon(tag);
                  return Chip(
                    avatar: Text(icon, style: const TextStyle(fontSize: 13)),
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _selectedTags.remove(tag)),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    side: const BorderSide(color: AppColors.primary),
                    labelStyle: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }),
                ActionChip(
                  avatar: const Icon(
                    Icons.add,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  label: Text(
                    _selectedTags.isEmpty ? 'Add tag' : 'Add more',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onPressed: _pickTags,
                  side: const BorderSide(color: AppColors.divider),
                  backgroundColor: Colors.transparent,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Value tag ────────────────────────────────────────────
            valuesAsync.when(
              data: (values) {
                if (values.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(label: 'Value'),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: values.map((v) {
                          final color = AppColors.fromHex(v.color);
                          final selected = _selectedValueId == v.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text('${v.icon} ${v.name}'),
                              selected: selected,
                              selectedColor: color.withValues(alpha: 0.15),
                              checkmarkColor: color,
                              side: BorderSide(
                                color: selected ? color : AppColors.divider,
                              ),
                              labelStyle: TextStyle(
                                color: selected ? color : null,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              onSelected: (_) => setState(() {
                                _selectedValueId = selected ? null : v.id;
                              }),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Date ─────────────────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.textSecondary,
              ),
              title: Text(
                '${_date.day}/${_date.month}/${_date.year}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),

            // ── Notes ────────────────────────────────────────────────
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: AppStrings.noteHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),

            // ── Save ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(AppStrings.saveTransaction),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _tagParentIcon(String tag) {
    final parent = DefaultTags.parentOf(tag, _type);
    return parent?.icon ?? '🏷️';
  }

  Future<void> _pickTags() async {
    final result = await showTagPicker(
      context: context,
      transactionType: _type,
      currentTags: _selectedTags,
    );
    if (result != null) setState(() => _selectedTags = result);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = CurrencyUtils.parse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please add a description')));
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final sessionId = IdGenerator.generate();
      final session = TransactionModel(
        id: sessionId,
        type: _type,
        date: _date,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: now,
      );
      final item = TransactionItemModel(
        id: IdGenerator.generate(),
        transactionId: sessionId,
        description: _descController.text.trim(),
        amount: amount,
        tags: _selectedTags,
        valueId: _selectedValueId,
        createdAt: now,
      );

      await ref.read(transactionsProvider.notifier).addSession(session, [item]);
      HapticFeedback.mediumImpact();
      if (mounted) context.pop();
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

// ── Helper widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
