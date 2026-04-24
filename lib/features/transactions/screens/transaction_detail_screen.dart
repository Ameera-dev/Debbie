import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';

import '../../../app/theme.dart';
import '../../../data/models/transaction_item_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/value_model.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../services/image_service.dart';
import '../../../shared/constants/default_tags.dart';
import '../../../shared/constants/mindfulness.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/date_utils.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsProvider);
    final valuesAsync = ref.watch(valuesProvider);
    final values = valuesAsync.valueOrNull ?? <ValueModel>[];

    return txAsync.when(
      data: (transactions) {
        final tx = transactions.where((t) => t.id == transactionId).firstOrNull;
        if (tx == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Transaction not found.')),
          );
        }
        return _DetailView(transaction: tx, values: values);
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail view
// ---------------------------------------------------------------------------

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({required this.transaction, required this.values});

  final TransactionModel transaction;
  final List<ValueModel> values;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final path = widget.transaction.imagePath;
    if (path == null) return;
    final file = await ref.read(imageServiceProvider).getFile(path);
    if (mounted) setState(() => _imageFile = file);
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final isExpense = tx.isExpense;
    final amountColor = isExpense ? AppColors.expense : AppColors.income;
    final emotion = MindfulnessContent.emotionById(tx.emotion);

    // Build value breakdown
    final valueAmounts = <String, int>{};
    for (final item in tx.items) {
      if (item.valueId != null) {
        valueAmounts[item.valueId!] =
            (valueAmounts[item.valueId!] ?? 0) + item.amount;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        children: [
          // ── Hero header ──────────────────────────────────────────
          _HeroHeader(tx: tx, amountColor: amountColor, isExpense: isExpense),

          if (emotion != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text('${emotion.emoji} ${emotion.label}'),
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
                  side: BorderSide(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                  ),
                  labelStyle: const TextStyle(
                    color: AppColors.secondaryDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ── Value breakdown (if items have values) ───────────────
          if (valueAmounts.isNotEmpty)
            _ValueBreakdown(
              valueAmounts: valueAmounts,
              totalAmount: tx.totalAmount,
              values: widget.values,
            ),

          // ── Items section ────────────────────────────────────────
          _SectionHeader(
            icon: Icons.receipt_long_outlined,
            label: '${tx.itemCount} ${tx.itemCount == 1 ? 'Item' : 'Items'}',
          ),
          ...tx.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _ItemTile(
              item: item,
              index: index + 1,
              totalItems: tx.itemCount,
              type: tx.type,
              values: widget.values,
              totalAmount: tx.totalAmount,
            );
          }),

          // ── Reflection ───────────────────────────────────────────
          if (tx.notes != null && tx.notes!.isNotEmpty) ...[
            const _SectionHeader(
              icon: Icons.edit_note_outlined,
              label: 'Reflection',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border(
                    left: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tx.notes!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],

          // ── Attached image ───────────────────────────────────────
          if (_imageFile != null) ...[
            const _SectionHeader(icon: Icons.photo_outlined, label: 'Receipt'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => _openFullscreen(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      Image.file(
                        _imageFile!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_in,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Tap to zoom',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
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
          ],
        ],
      ),
      // ── Bottom actions ───────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/edit-session/${tx.id}'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.expense,
                  side: BorderSide(
                    color: AppColors.expense.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoView(imageProvider: FileImage(_imageFile!)),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final router = GoRouter.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete transaction?'),
        content: const Text(
          'This will permanently remove this transaction and all its items.',
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

    if (confirmed != true || !mounted) return;

    final imagePath = widget.transaction.imagePath;
    if (imagePath != null) {
      await ref.read(imageServiceProvider).delete(imagePath);
    }

    HapticFeedback.lightImpact();
    await ref.read(transactionsProvider.notifier).remove(widget.transaction.id);
    if (mounted) router.pop();
  }
}

// ---------------------------------------------------------------------------
// Hero header — big amount, date, type
// ---------------------------------------------------------------------------

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.tx,
    required this.amountColor,
    required this.isExpense,
  });

  final TransactionModel tx;
  final Color amountColor;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Title (if set)
          if (tx.title != null && tx.title!.isNotEmpty) ...[
            Text(
              tx.title!,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],

          // Amount — large, prominent
          Text(
            CurrencyUtils.formatSigned(tx.totalAmount, isExpense: isExpense),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: amountColor,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w700,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 12),

          // Meta row: type badge + date + item count
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TypeBadge(type: tx.type),
              const SizedBox(width: 10),
              Container(width: 1, height: 16, color: AppColors.divider),
              const SizedBox(width: 10),
              const Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                AppDateUtils.formatDate(tx.date),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              if (tx.itemCount > 1) ...[
                const SizedBox(width: 10),
                Container(width: 1, height: 16, color: AppColors.divider),
                const SizedBox(width: 10),
                const Icon(
                  Icons.layers_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${tx.itemCount} items',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Value breakdown — shows where energy went
// ---------------------------------------------------------------------------

class _ValueBreakdown extends StatelessWidget {
  const _ValueBreakdown({
    required this.valueAmounts,
    required this.totalAmount,
    required this.values,
  });

  final Map<String, int> valueAmounts;
  final int totalAmount;
  final List<ValueModel> values;

  @override
  Widget build(BuildContext context) {
    // Sort by amount descending
    final sorted = valueAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stacked color bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: sorted.map((entry) {
                    final value = values
                        .where((v) => v.id == entry.key)
                        .firstOrNull;
                    final color = value != null
                        ? AppColors.fromHex(value.color)
                        : AppColors.textSecondary;
                    final ratio = totalAmount > 0
                        ? entry.value / totalAmount
                        : 0.0;
                    return Flexible(
                      flex: (ratio * 100).round().clamp(1, 100),
                      child: Container(color: color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Value rows
            ...sorted.map((entry) {
              final value = values.where((v) => v.id == entry.key).firstOrNull;
              if (value == null) return const SizedBox.shrink();
              final color = AppColors.fromHex(value.color);
              final pct = totalAmount > 0
                  ? (entry.value / totalAmount * 100).round()
                  : 0;

              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${value.icon} ${value.name}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$pct%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyUtils.format(entry.value),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.divider.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item tile — with index number and percentage
// ---------------------------------------------------------------------------

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.index,
    required this.totalItems,
    required this.type,
    required this.values,
    required this.totalAmount,
  });

  final TransactionItemModel item;
  final int index;
  final int totalItems;
  final String type;
  final List<ValueModel> values;
  final int totalAmount;

  @override
  Widget build(BuildContext context) {
    final amountColor = type == 'expense'
        ? AppColors.expense
        : AppColors.income;

    // Find value
    ValueModel? itemValue;
    if (item.valueId != null) {
      itemValue = values.where((v) => v.id == item.valueId).firstOrNull;
    }

    final firstTagIcon = item.tags.isNotEmpty
        ? DefaultTags.parentOf(item.tags.first, type)?.icon
        : null;
    final icon =
        itemValue?.icon ?? firstTagIcon ?? (type == 'expense' ? '💸' : '💰');
    final iconColor = itemValue != null
        ? AppColors.fromHex(itemValue.color)
        : amountColor;

    final pct = totalAmount > 0 ? (item.amount / totalAmount * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            // Index number circle
            if (totalItems > 1) ...[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.divider.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],

            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),

            // Description + chips
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.tags.isNotEmpty || itemValue != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (itemValue != null)
                          _MiniChip(
                            label: '${itemValue.icon} ${itemValue.name}',
                            color: iconColor,
                          ),
                        ...item.tags.map(
                          (tag) => _MiniChip(
                            label: tag,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount + percentage
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyUtils.format(item.amount),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: amountColor,
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (totalItems > 1) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$pct%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final isExpense = type == 'expense';
    final color = isExpense ? AppColors.expense : AppColors.income;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isExpense ? 'Expense' : 'Income',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
