import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/transaction_item_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/value_model.dart';
import '../../../providers/goals_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../services/ai_reflection_service.dart';
import '../../../services/image_service.dart';
import '../../../services/suggestion_service.dart';
import '../../../shared/constants/default_tags.dart';
import '../../../shared/constants/mindfulness.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/id_generator.dart';
import '../../../shared/widgets/tide.dart';
import '../widgets/tag_picker.dart';

// ---------------------------------------------------------------------------
// Draft for one item in the session
// ---------------------------------------------------------------------------

class _ItemDraft {
  _ItemDraft({String? id}) : id = id ?? IdGenerator.generate();

  final String id;
  final descController = TextEditingController();
  final amountController = TextEditingController();
  List<String> tags = [];
  String? valueId;
  String? goalId;

  int get amount => CurrencyUtils.parse(amountController.text) ?? 0;
  bool get isValid => descController.text.trim().isNotEmpty && amount > 0;

  void dispose() {
    descController.dispose();
    amountController.dispose();
  }
}

enum _SessionSaveMode { recordNow, pending }

// ---------------------------------------------------------------------------
// Screen — supports both add and edit mode
// ---------------------------------------------------------------------------

class AddSessionScreen extends ConsumerStatefulWidget {
  const AddSessionScreen({super.key, this.editTransactionId});

  /// When non-null the screen loads this transaction and operates in edit mode.
  final String? editTransactionId;

  @override
  ConsumerState<AddSessionScreen> createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends ConsumerState<AddSessionScreen> {
  final List<_ItemDraft> _items = [];
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _scrollController = ScrollController();
  DateTime _date = DateTime.now();
  String _type = 'expense';
  String? _imagePath; // relative path after compress+save
  File? _imageFile; // local preview file
  bool _saving = false;
  bool _loading = true;
  String? _selectedEmotion;

  TransactionModel? _editTransaction;
  bool get _isEditing => _editTransaction != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.editTransactionId != null) {
      final transactions = ref.read(transactionsProvider).valueOrNull ?? [];
      final tx = transactions
          .where((t) => t.id == widget.editTransactionId)
          .firstOrNull;
      if (tx != null) {
        _editTransaction = tx;
        _initFromExisting(tx);
      } else {
        _addItem(scrollToBottom: false);
      }
    } else {
      _addItem(scrollToBottom: false);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _initFromExisting(TransactionModel tx) {
    _date = tx.date;
    _type = tx.type;
    _selectedEmotion = tx.emotion;
    _titleController.text = tx.title ?? '';
    _notesController.text = tx.notes ?? '';
    _imagePath = tx.imagePath;

    if (tx.imagePath != null) {
      _loadExistingImage(tx.imagePath!);
    }

    for (final item in tx.items) {
      final draft = _ItemDraft(id: item.id);
      draft.descController.text = item.description;
      draft.amountController.text = CurrencyUtils.formatInput(
        item.amount.toString(),
      );
      draft.tags = List.from(item.tags);
      draft.valueId = item.valueId;
      draft.goalId = item.goalId;
      _items.add(draft);
    }

    if (_items.isEmpty) _addItem(scrollToBottom: false);
  }

  Future<void> _loadExistingImage(String path) async {
    final file = await ref.read(imageServiceProvider).getFile(path);
    if (mounted && file != null) {
      setState(() => _imageFile = file);
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _titleController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addItem({bool scrollToBottom = true}) {
    setState(() => _items.add(_ItemDraft()));
    if (!scrollToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeItem(_ItemDraft item) {
    if (_items.length == 1) return;
    setState(() {
      _items.remove(item);
      item.dispose();
    });
  }

  int get _validItemCount => _items.where((i) => i.isValid).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final valuesAsync = ref.watch(valuesProvider);
    final goalsAsync = ref.watch(activeGoalsProvider);
    final coolingOffThreshold =
        ref.watch(coolingOffThresholdProvider).valueOrNull ??
        MindfulnessContent.defaultCoolingOffThreshold;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing ? AppStrings.editTransactionTitle : 'Add transactions',
        ),
        actions: [
          TextButton(
            onPressed: _validItemCount > 0 && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    'Save${_validItemCount > 0 ? ' ($_validItemCount)' : ''}',
                    style: TextStyle(
                      color: _validItemCount > 0
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TidePageBackground(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            TidePageIntro(
              eyebrow: _isEditing ? 'Edit session' : 'Quick capture',
              title: Text.rich(
                TextSpan(
                  style: Theme.of(
                    context,
                  ).textTheme.displaySmall?.copyWith(height: 1.05),
                  children: [
                    const TextSpan(text: 'Capture the '),
                    const TextSpan(
                      text: 'moment',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    TextSpan(text: _isEditing ? ' again.' : '.'),
                  ],
                ),
              ),
              subtitle: _isEditing
                  ? 'Revisit the details and make them feel right.'
                  : AppStrings.intentionPrompts[DateTime.now().millisecond %
                        AppStrings.intentionPrompts.length],
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              const _IntentionMoment(),
            ],
            const SizedBox(height: 18),
            // ── Date + type row ──────────────────────────────────────
            Row(
              children: [
                _DateRow(date: _date, onTap: _pickDate),
                const Spacer(),
                _SmallToggle(
                  isExpense: _type == 'expense',
                  onToggle: (isExpense) => setState(() {
                    _type = isExpense ? 'expense' : 'income';
                    // Reset tags on all items when type changes
                    for (final item in _items) {
                      item.tags = [];
                    }
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_type == 'expense' && !_isEditing) ...[
              _CoolingOffHint(threshold: coolingOffThreshold),
              const SizedBox(height: 16),
            ],

            // ── Title (optional) ────────────────────────────────────
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Title (e.g. Grocery run, Lunch with team)',
                prefixIcon: const Icon(Icons.label_outline, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),

            // ── Item cards ───────────────────────────────────────────
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _ItemCard(
                key: ValueKey(item.id),
                item: item,
                index: index,
                type: _type,
                canRemove: _items.length > 1,
                valuesAsync: valuesAsync,
                goalsAsync: goalsAsync,
                onRemove: () => _removeItem(item),
                onChanged: () => setState(() {}),
                onPickTags: () => _pickTagsFor(item),
                onSuggestValue: () => _suggestValueFor(item),
              );
            }),

            // ── Add another item ─────────────────────────────────────
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add item'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (ref.watch(aiReflectionServiceProvider) != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showScanOptions(),
                      icon: const Icon(
                        Icons.document_scanner_outlined,
                        size: 18,
                      ),
                      label: const Text('Scan receipt'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: BorderSide(
                          color: AppColors.secondary.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // ── Image attachment ─────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionDivider(label: 'Photo'),
            const SizedBox(height: 12),
            _ImageAttachment(
              imageFile: _imageFile,
              onPickImage: _pickImage,
              onRemoveImage: _removeImage,
            ),

            // ── Spending note ────────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionDivider(label: 'Feeling'),
            const SizedBox(height: 12),
            _EmotionSelector(
              selectedEmotion: _selectedEmotion,
              onChanged: (emotion) =>
                  setState(() => _selectedEmotion = emotion),
            ),

            const SizedBox(height: 24),
            const _SectionDivider(label: 'What did this mean?'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 16,
                        color: AppColors.secondary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'This is your moment to pause',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppColors.secondaryDeep,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _type == 'income'
                          ? 'How does receiving this feel?'
                          : 'What did this spending mean to you?',
                      alignLabelWithHint: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This short note will shape your weekly reflection.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _pickTagsFor(_ItemDraft item) async {
    final result = await showTagPicker(
      context: context,
      transactionType: _type,
      currentTags: item.tags,
    );
    if (result != null) setState(() => item.tags = result);
  }

  Future<void> _suggestValueFor(_ItemDraft item) async {
    final desc = item.descController.text.trim();
    if (desc.isEmpty) return;

    // First try history-based suggestion
    final suggestion = ref.read(suggestionServiceProvider);
    final valueId = await suggestion.suggestValueId(desc);
    if (valueId != null && item.valueId == null && mounted) {
      setState(() => item.valueId = valueId);

      final goalId = await suggestion.suggestGoalId(desc, valueId);
      if (goalId != null && item.goalId == null && mounted) {
        setState(() => item.goalId = goalId);
      }
      return;
    }

    // Fallback: AI suggestion if available and no value set yet
    if (item.valueId != null) return;
    final aiService = ref.read(aiReflectionServiceProvider);
    if (aiService == null) return;

    final values = ref.read(valuesProvider).valueOrNull ?? [];
    if (values.isEmpty) return;

    final result = await aiService.suggestValue(
      description: desc,
      values: values,
    );

    if (result is AiReflectionSuccess && mounted) {
      final suggestedName = result.text.trim();
      final match = values
          .where((v) => v.name.toLowerCase() == suggestedName.toLowerCase())
          .firstOrNull;
      if (match != null && item.valueId == null) {
        setState(() => item.valueId = match.id);
      }
    }
  }

  Future<void> _scanReceipt(ImageSource source) async {
    final aiService = ref.read(aiReflectionServiceProvider);
    if (aiService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enable AI in Settings and add your Gemini API key to scan receipts.',
            ),
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    if (!mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reading your receipt...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final imageBytes = await picked.readAsBytes();
      final values = ref.read(valuesProvider).valueOrNull ?? [];

      final result = await aiService.scanReceipt(
        imageBytes: imageBytes,
        values: values,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      if (result is AiReflectionSuccess) {
        _applyReceiptResult(result.text, values);
      } else if (result is AiReflectionError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not process the receipt.')),
        );
      }
    }
  }

  void _applyReceiptResult(String jsonText, List<ValueModel> values) {
    try {
      // Clean up potential markdown code fences
      var cleaned = jsonText.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```\w*\n?'), '')
            .replaceFirst(RegExp(r'\n?```$'), '');
      }

      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];
      final dateStr = data['date'] as String?;

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items found on the receipt.')),
        );
        return;
      }

      // Parse date if available
      if (dateStr != null && dateStr != 'null') {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          setState(() => _date = parsed);
        }
      }

      // Clear existing empty drafts
      for (final item in _items) {
        if (!item.isValid) item.dispose();
      }
      _items.removeWhere((i) => !i.isValid);

      // Add scanned items
      for (final item in items) {
        final draft = _ItemDraft();
        final desc = item['description'] as String? ?? '';
        final amount = item['amount'] as int? ?? 0;
        final valueName = item['value'] as String? ?? '';

        draft.descController.text = desc;
        draft.amountController.text = CurrencyUtils.formatInput(
          amount.toString(),
        );

        // Match value by name
        final match = values
            .where((v) => v.name.toLowerCase() == valueName.toLowerCase())
            .firstOrNull;
        if (match != null) {
          draft.valueId = match.id;
        }

        _items.add(draft);
      }

      if (_items.isEmpty) _addItem();
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${items.length} items from receipt'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not parse the receipt data. Try again.'),
        ),
      );
    }
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo of receipt'),
              onTap: () {
                Navigator.pop(context);
                _scanReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose receipt from gallery'),
              onTap: () {
                Navigator.pop(context);
                _scanReceipt(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final imageService = ref.read(imageServiceProvider);
    final tempId = IdGenerator.generate();
    try {
      final relativePath = await imageService.pickAndSave(source, tempId);
      if (relativePath == null) return;
      final file = await imageService.getFile(relativePath);
      setState(() {
        _imagePath = relativePath;
        _imageFile = file;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not attach image.')),
        );
      }
    }
  }

  void _removeImage() {
    if (_imagePath != null) {
      ref.read(imageServiceProvider).delete(_imagePath!);
    }
    setState(() {
      _imagePath = null;
      _imageFile = null;
    });
  }

  Future<void> _save() async {
    final validItems = _items.where((i) => i.isValid).toList();
    if (validItems.isEmpty) return;

    setState(() => _saving = true);
    final title = _titleController.text.trim().isEmpty
        ? null
        : _titleController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    try {
      final sessionId = _isEditing
          ? _editTransaction!.id
          : IdGenerator.generate();
      final now = DateTime.now();
      final totalAmount = validItems.fold<int>(
        0,
        (sum, item) => sum + item.amount,
      );
      final coolingOffThreshold =
          ref.read(coolingOffThresholdProvider).valueOrNull ??
          MindfulnessContent.defaultCoolingOffThreshold;
      final saveMode =
          !_isEditing &&
              _type == 'expense' &&
              coolingOffThreshold > 0 &&
              totalAmount >= coolingOffThreshold
          ? await _showCoolingOffDialog(
              totalAmount: totalAmount,
              description: title ?? validItems.first.descController.text.trim(),
            )
          : _SessionSaveMode.recordNow;
      if (saveMode == null) return;
      final isPending = saveMode == _SessionSaveMode.pending;

      // Handle image path for new sessions
      String? finalImagePath = _imagePath;
      if (!_isEditing && _imagePath != null) {
        final imageService = ref.read(imageServiceProvider);
        final oldFile = await imageService.getFile(_imagePath!);
        if (oldFile != null) {
          final newRelative = 'transaction_images/$sessionId.jpg';
          await oldFile.rename(
            oldFile.path.replaceAll(_imagePath!, newRelative),
          );
          finalImagePath = newRelative;
        }
      }

      final session = TransactionModel(
        id: sessionId,
        type: _type,
        date: _date,
        status: isPending
            ? TransactionModel.pendingStatus
            : TransactionModel.recordedStatus,
        title: title,
        notes: notes,
        imagePath: finalImagePath,
        pendingUntil: isPending ? now.add(const Duration(hours: 24)) : null,
        emotion: _selectedEmotion,
        createdAt: _isEditing ? _editTransaction!.createdAt : now,
      );

      final items = validItems.map((draft) {
        return TransactionItemModel(
          id: IdGenerator.generate(),
          transactionId: sessionId,
          description: draft.descController.text.trim(),
          amount: draft.amount,
          tags: draft.tags,
          valueId: draft.valueId,
          goalId: draft.goalId,
          createdAt: now,
        );
      }).toList();

      if (_isEditing) {
        // If the image changed, delete the old one
        final oldImagePath = _editTransaction!.imagePath;
        if (oldImagePath != null && oldImagePath != finalImagePath) {
          await ref.read(imageServiceProvider).delete(oldImagePath);
        }
        await ref
            .read(transactionsProvider.notifier)
            .editSession(session, items);
      } else if (isPending) {
        await ref
            .read(transactionsProvider.notifier)
            .addPendingSession(session, items);
      } else {
        await ref
            .read(transactionsProvider.notifier)
            .addSession(session, items);
      }

      HapticFeedback.mediumImpact();
      if (mounted) {
        final messages = _type == 'income'
            ? AppStrings.postSaveIncomeMessages
            : AppStrings.postSaveExpenseMessages;
        final message = isPending
            ? 'Set aside for tomorrow. You can revisit it after a day of space.'
            : messages[DateTime.now().millisecond % messages.length];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.primary.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        context.pop();
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

  Future<_SessionSaveMode?> _showCoolingOffDialog({
    required int totalAmount,
    required String description,
  }) {
    final label = description.trim().isEmpty
        ? 'this expense'
        : description.trim();
    return showDialog<_SessionSaveMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('A gentle pause'),
        content: Text(
          '${CurrencyUtils.format(totalAmount)} is a meaningful amount. Would you like to sit with "$label" for a day before recording it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_SessionSaveMode.recordNow),
            child: const Text('Record now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_SessionSaveMode.pending),
            child: const Text('Wait 24 hours'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item card widget
// ---------------------------------------------------------------------------

class _ItemCard extends StatefulWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.type,
    required this.canRemove,
    required this.valuesAsync,
    required this.goalsAsync,
    required this.onRemove,
    required this.onChanged,
    required this.onPickTags,
    required this.onSuggestValue,
  });

  final _ItemDraft item;
  final int index;
  final String type;
  final bool canRemove;
  final AsyncValue<dynamic> valuesAsync;
  final AsyncValue<List<GoalModel>> goalsAsync;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onPickTags;
  final VoidCallback onSuggestValue;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final amountColor = widget.type == 'expense'
        ? AppColors.expense
        : AppColors.income;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Text(
                  'Item ${widget.index + 1}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (widget.canRemove)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.textSecondary,
                    onPressed: widget.onRemove,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          // ── Description ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: item.descController,
              decoration: const InputDecoration(
                hintText: 'What was this for?',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: Theme.of(context).textTheme.titleMedium,
              onChanged: (_) {
                widget.onChanged();
                // Auto-suggest value when description changes
                widget.onSuggestValue();
              },
            ),
          ),

          // ── Amount ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: item.amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: 'JetBrains Mono',
                color: amountColor,
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
                  item.amountController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                }
                widget.onChanged();
              },
            ),
          ),

          const Divider(indent: 16, endIndent: 16, height: 16),

          // ── Value selection ─────────────────────────────────────
          widget.valuesAsync.when(
            data: (values) {
              final valueList = values as List;
              final selectedValue = valueList
                  .where((value) => value.id == item.valueId)
                  .cast<ValueModel>()
                  .firstOrNull;
              final guardian = selectedValue?.guardianText?.trim();
              if (valueList.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite_outline,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Link to value',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          if (item.valueId != null) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.auto_awesome,
                              size: 12,
                              color: AppColors.secondary.withValues(alpha: 0.6),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: valueList.map((v) {
                        final color = AppColors.fromHex(v.color as String);
                        final selected = item.valueId == v.id;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              item.valueId = selected ? null : v.id as String;
                              item.goalId = null;
                            });
                            widget.onChanged();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? color : AppColors.divider,
                                width: selected ? 1.5 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.12),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Colored dot
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: selected ? 18 : 8,
                                  height: selected ? 18 : 8,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? color
                                        : color.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: selected
                                      ? const Icon(
                                          Icons.check,
                                          size: 11,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${v.icon} ${v.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: selected
                                        ? color
                                        : AppColors.textSecondary,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (guardian != null && guardian.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          'What you\'re protecting: $guardian',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.secondaryDeep,
                                height: 1.5,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── Goal row (when value with active goals selected) ────
          if (item.valueId != null)
            widget.goalsAsync.when(
              data: (goals) {
                final matching = goals
                    .where((g) => g.valueId == item.valueId)
                    .toList();
                if (matching.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: matching.map((goal) {
                      final selected = item.goalId == goal.id;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            item.goalId = selected ? null : goal.id;
                          });
                          widget.onChanged();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.secondary.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.secondary
                                  : AppColors.divider,
                              width: selected ? 1.5 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: AppColors.secondary.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: selected ? 18 : 8,
                                height: selected ? 18 : 8,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.secondary
                                      : AppColors.secondary.withValues(
                                          alpha: 0.4,
                                        ),
                                  shape: BoxShape.circle,
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check,
                                        size: 11,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '🎯 ${goal.title}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selected
                                      ? AppColors.secondary
                                      : AppColors.textSecondary,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          // ── Tags row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...item.tags.map((tag) {
                  final cat = DefaultTags.parentOf(tag, widget.type);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cat != null) ...[
                          Text(cat.icon, style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          tag,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() => item.tags.remove(tag));
                            widget.onChanged();
                          },
                          child: const Icon(
                            Icons.close,
                            size: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                GestureDetector(
                  onTap: widget.onPickTags,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.divider,
                        style: item.tags.isEmpty
                            ? BorderStyle.solid
                            : BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.tags.isEmpty ? Icons.label_outline : Icons.add,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.tags.isEmpty ? 'Add tags' : 'More',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
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

// ---------------------------------------------------------------------------
// Image attachment widget
// ---------------------------------------------------------------------------

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({
    required this.imageFile,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  final File? imageFile;
  final Future<void> Function(ImageSource) onPickImage;
  final VoidCallback onRemoveImage;

  @override
  Widget build(BuildContext context) {
    if (imageFile != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              imageFile!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemoveImage,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ).animate().scale(
        begin: const Offset(0.85, 0.85),
        end: const Offset(1.0, 1.0),
        duration: 300.ms,
        curve: Curves.easeOutBack,
      ).fadeIn(duration: 220.ms);
    }

    return Row(
      children: [
        _CameraButton(
          icon: Icons.camera_alt_outlined,
          label: 'Camera',
          onTap: () => onPickImage(ImageSource.camera),
        ),
        const SizedBox(width: 12),
        _CameraButton(
          icon: Icons.photo_library_outlined,
          label: 'Gallery',
          onTap: () => onPickImage(ImageSource.gallery),
        ),
      ],
    );
  }
}

class _CoolingOffHint extends StatelessWidget {
  const _CoolingOffHint({required this.threshold});

  final int threshold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TideSurfaceIcon(
            icon: Icons.hourglass_top_rounded,
            size: 16,
            backgroundColor: AppColors.surfaceWarm,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Large expenses can wait a day',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'When an expense reaches ${CurrencyUtils.format(threshold)}, Debbie can help you set it aside for 24 hours before it becomes final.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
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

class _EmotionSelector extends StatelessWidget {
  const _EmotionSelector({
    required this.selectedEmotion,
    required this.onChanged,
  });

  final String? selectedEmotion;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MindfulnessContent.emotions.map((emotion) {
        final selected = emotion.id == selectedEmotion;
        return ChoiceChip(
          label: Text('${emotion.emoji} ${emotion.label}'),
          selected: selected,
          onSelected: (_) => onChanged(selected ? null : emotion.id),
          selectedColor: AppColors.secondary.withValues(alpha: 0.16),
          side: BorderSide(
            color: selected ? AppColors.secondary : AppColors.divider,
          ),
          labelStyle: TextStyle(
            color: selected ? AppColors.secondaryDeep : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        );
      }).toList(),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
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

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(date);
    final label = isToday ? 'Today' : '${date.day}/${date.month}/${date.year}';

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.expand_more,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _SmallToggle extends StatelessWidget {
  const _SmallToggle({required this.isExpense, required this.onToggle});

  final bool isExpense;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleTab(
            label: 'Expense',
            selected: isExpense,
            color: AppColors.expense,
            onTap: () => onToggle(true),
          ),
          _ToggleTab(
            label: 'Income',
            selected: !isExpense,
            color: AppColors.income,
            onTap: () => onToggle(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _IntentionMoment extends StatefulWidget {
  const _IntentionMoment();

  @override
  State<_IntentionMoment> createState() => _IntentionMomentState();
}

class _IntentionMomentState extends State<_IntentionMoment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _breatheAnimation,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(
                    alpha: _breatheAnimation.value,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is more than a number. Let it land.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
