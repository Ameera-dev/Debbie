import 'dart:async';
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
import '../../../services/location_service.dart';
import '../../../services/suggestion_service.dart';
import '../../../shared/constants/default_tags.dart';
import '../../../shared/constants/mindfulness.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/date_utils.dart';
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
  // Each entry: {path: relative path, file: resolved File}
  final List<({String path, File file})> _images = [];
  bool _saving = false;
  bool _loading = true;
  String? _selectedEmotion;

  TransactionModel? _editTransaction;
  bool get _isEditing => _editTransaction != null;

  // Location state
  LocationData? _locationData;
  bool _locationLoading = false;

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

  Future<void> _captureLocation({bool silent = false}) async {
    if (!silent) setState(() => _locationLoading = true);

    final result = await ref.read(locationServiceProvider).getCurrentLocation();

    if (!mounted) return;
    setState(() {
      _locationData = result.data;
      _locationLoading = false;
    });

    if (!silent && result.failure != null) {
      final msg = switch (result.failure!) {
        LocationFailure.permissionDenied => 'Location permission is needed.',
        LocationFailure.permissionPermanentlyDenied =>
          'Location permission permanently denied. Enable it in Settings.',
        LocationFailure.disabled => 'Location services are turned off.',
        LocationFailure.timeout => 'Could not get location. Try again.',
        LocationFailure.unknown => 'Could not get location.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _showLocationSearch() async {
    final picked = await showModalBottomSheet<LocationData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _LocationSearchSheet(
        service: ref.read(locationServiceProvider),
        initialQuery: _locationData?.label ?? '',
      ),
    );
    if (picked != null && mounted) {
      setState(() => _locationData = picked);
    }
  }

  void _initFromExisting(TransactionModel tx) {
    _date = tx.date;
    _type = tx.type;
    _selectedEmotion = tx.emotion;
    _titleController.text = tx.title ?? '';
    _notesController.text = tx.notes ?? '';
    if (tx.latitude != null && tx.longitude != null) {
      _locationData = LocationData(
        latitude: tx.latitude!,
        longitude: tx.longitude!,
        label:
            tx.locationLabel ??
            '${tx.latitude!.toStringAsFixed(4)}, ${tx.longitude!.toStringAsFixed(4)}',
      );
    }

    _loadExistingImages(tx.images);

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

  Future<void> _loadExistingImages(List<String> paths) async {
    for (final path in paths) {
      final file = await ref.read(imageServiceProvider).getFile(path);
      if (mounted && file != null) {
        setState(() => _images.add((path: path, file: file)));
      }
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
                  type: _type,
                  onChanged: (newType) => setState(() {
                    _type = newType;
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

            // ── Image attachments ────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionDivider(label: 'Photos'),
            const SizedBox(height: 12),
            _MultiImageAttachment(
              images: _images,
              onAdd: _pickImages,
              onRemove: (index) => _removeImage(index),
            ),

            // ── Location ─────────────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionDivider(label: 'Location'),
            const SizedBox(height: 12),
            _LocationRow(
              locationData: _locationData,
              isLoading: _locationLoading,
              onCapture: () => _captureLocation(),
              onSearch: _showLocationSearch,
              onClear: () => setState(() => _locationData = null),
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
                      hintText: switch (_type) {
                        'income' => 'How does receiving this feel?',
                        'saving' => 'What is this saving for?',
                        _ => 'What did this spending mean to you?',
                      },
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
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null || !mounted) return;

    // Immediately follow with a time picker — default to existing time
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _date.hour, minute: _date.minute),
    );

    setState(() {
      final hour = pickedTime?.hour ?? _date.hour;
      final minute = pickedTime?.minute ?? _date.minute;
      _date = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        hour,
        minute,
      );
    });
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

  Future<void> _pickImages(ImageSource source) async {
    final imageService = ref.read(imageServiceProvider);
    try {
      final paths = await imageService.pickMultipleAndSave(
        source,
        IdGenerator.generate,
      );
      for (final path in paths) {
        final file = await imageService.getFile(path);
        if (file != null && mounted) {
          setState(() => _images.add((path: path, file: file)));
        }
      }
    } on Exception catch (e) {
      if (!mounted) return;
      final message = e.toString().trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? 'Could not attach image.' : message),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not attach image.')),
        );
      }
    }
  }

  void _removeImage(int index) {
    final img = _images[index];
    ref.read(imageServiceProvider).delete(img.path);
    setState(() => _images.removeAt(index));
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

      final currentPaths = _images.map((img) => img.path).toList();

      // When editing, delete any images that were removed
      if (_isEditing) {
        final removedPaths = _editTransaction!.images
            .where((p) => !currentPaths.contains(p))
            .toList();
        await ref.read(imageServiceProvider).deleteAll(removedPaths);
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
        images: currentPaths,
        pendingUntil: isPending ? now.add(const Duration(hours: 24)) : null,
        emotion: _selectedEmotion,
        latitude: _locationData?.latitude,
        longitude: _locationData?.longitude,
        locationLabel: _locationData?.label,
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
        final messages = switch (_type) {
          'income' => AppStrings.postSaveIncomeMessages,
          'saving' => AppStrings.postSaveSavingMessages,
          _ => AppStrings.postSaveExpenseMessages,
        };
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
    final amountColor = switch (widget.type) {
      'expense' => AppColors.expense,
      'saving' => AppColors.saving,
      _ => AppColors.income,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
              decoration: _itemFieldDecoration(
                context,
                hintText: 'What was this for?',
                icon: Icons.notes_rounded,
                focusColor: AppColors.primary,
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSoft,
                fontWeight: FontWeight.w600,
              ),
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'JetBrains Mono',
                color: amountColor,
                fontWeight: FontWeight.w700,
              ),
              decoration:
                  _itemFieldDecoration(
                    context,
                    hintText: '0',
                    icon: Icons.payments_outlined,
                    focusColor: amountColor,
                    prefixText: 'Rp ',
                  ).copyWith(
                    hintStyle: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(
                          color: amountColor.withValues(alpha: 0.42),
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.w700,
                        ),
                    prefixStyle: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(
                          color: amountColor.withValues(alpha: 0.72),
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.w700,
                        ),
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

  InputDecoration _itemFieldDecoration(
    BuildContext context, {
    required String hintText,
    required IconData icon,
    required Color focusColor,
    String? prefixText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.82)
        : AppColors.surface.withValues(alpha: 0.92);
    final borderColor = isDark
        ? AppColors.darkTextSecondary.withValues(alpha: 0.18)
        : AppColors.divider.withValues(alpha: 0.95);

    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      prefixIcon: Icon(icon, size: 19, color: AppColors.textSecondary),
      prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 48),
      prefixStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.textSecondary,
        fontFamily: 'JetBrains Mono',
        fontWeight: FontWeight.w700,
      ),
      hintStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.textSecondary.withValues(alpha: 0.88),
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.fromLTRB(2, 18, 18, 18),
      border: border(borderColor),
      enabledBorder: border(borderColor),
      focusedBorder: border(focusColor.withValues(alpha: 0.82), width: 1.4),
    );
  }
}

// ---------------------------------------------------------------------------
// Image attachment widget
// ---------------------------------------------------------------------------

class _MultiImageAttachment extends StatelessWidget {
  const _MultiImageAttachment({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<({String path, File file})> images;
  final Future<void> Function(ImageSource) onAdd;
  final void Function(int index) onRemove;

  static const _maxImages = 5;

  @override
  Widget build(BuildContext context) {
    final canAdd = images.length < _maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        images[i].file,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onRemove(i),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 260.ms,
                  curve: Curves.easeOutBack,
                );
              },
            ),
          ),
        if (images.isNotEmpty && canAdd) const SizedBox(height: 10),
        if (canAdd)
          Row(
            children: [
              _CameraButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () => onAdd(ImageSource.camera),
              ),
              const SizedBox(width: 12),
              _CameraButton(
                icon: Icons.photo_library_outlined,
                label: images.isEmpty ? 'Gallery' : 'Add more',
                onTap: () => onAdd(ImageSource.gallery),
              ),
              if (images.isNotEmpty) ...[
                const Spacer(),
                Text(
                  '${images.length}/$_maxImages',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedOption = MindfulnessContent.emotionById(selectedEmotion);
    final summaryBackground = selectedOption == null
        ? (isDark
              ? AppColors.darkSurface.withValues(alpha: 0.88)
              : AppColors.surfaceWarm.withValues(alpha: 0.94))
        : AppColors.secondary.withValues(alpha: isDark ? 0.18 : 0.1);
    final summaryBorder = selectedOption == null
        ? (isDark
              ? AppColors.darkTextSecondary.withValues(alpha: 0.16)
              : AppColors.divider.withValues(alpha: 0.95))
        : AppColors.secondary.withValues(alpha: 0.28);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 3 : 2;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        final optionWidth = width.isFinite && width > 0
            ? width
            : constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: summaryBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: summaryBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TideSurfaceIcon(
                    icon: selectedOption == null
                        ? Icons.favorite_border_rounded
                        : Icons.auto_awesome_rounded,
                    size: 17,
                    color: selectedOption == null
                        ? AppColors.textSoft
                        : AppColors.secondaryDeep,
                    backgroundColor: selectedOption == null
                        ? (isDark ? AppColors.darkSurface : AppColors.surface)
                        : AppColors.secondary.withValues(alpha: 0.14),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedOption == null
                              ? 'Name the energy behind this spending'
                              : 'You marked this as ${selectedOption.label.toLowerCase()}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: selectedOption == null
                                    ? null
                                    : AppColors.secondaryDeep,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedOption == null
                              ? 'Optional, but it helps Debbie spot the patterns behind your decisions.'
                              : _emotionDescription(selectedOption.id),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: selectedOption == null
                                    ? AppColors.textSecondary
                                    : AppColors.secondaryDeep.withValues(
                                        alpha: 0.86,
                                      ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedOption == null)
                    TidePill(
                      label: 'Optional',
                      color: AppColors.textSecondary,
                      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
                    )
                  else
                    TextButton(
                      onPressed: () => onChanged(null),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.secondaryDeep,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: MindfulnessContent.emotions.map((emotion) {
                final selected = emotion.id == selectedEmotion;
                return SizedBox(
                  width: optionWidth,
                  child: _EmotionOptionCard(
                    emotion: emotion,
                    selected: selected,
                    description: _emotionDescription(emotion.id),
                    onTap: () => onChanged(selected ? null : emotion.id),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  String _emotionDescription(String id) {
    return switch (id) {
      'joyful' => 'Light, warm, or celebratory.',
      'anxious' => 'Tight, uncertain, or protective.',
      'impulsive' => 'Fast, urgent, or hard to pause.',
      'intentional' => 'Chosen with purpose and clarity.',
      'generous' => 'Open-hearted and glad to give.',
      'guilty' => 'Heavy, regretful, or a little off.',
      'proud' => 'Aligned with progress you value.',
      _ => 'A quick note for the emotional side of this choice.',
    };
  }
}

class _EmotionOptionCard extends StatelessWidget {
  const _EmotionOptionCard({
    required this.emotion,
    required this.selected,
    required this.description,
    required this.onTap,
  });

  final MoneyEmotionOption emotion;
  final bool selected;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = selected
        ? AppColors.secondary.withValues(alpha: isDark ? 0.2 : 0.12)
        : (isDark
              ? AppColors.darkSurface.withValues(alpha: 0.88)
              : AppColors.surface.withValues(alpha: 0.94));
    final borderColor = selected
        ? AppColors.secondary.withValues(alpha: 0.36)
        : (isDark
              ? AppColors.darkTextSecondary.withValues(alpha: 0.16)
              : AppColors.divider.withValues(alpha: 0.95));
    final emojiBackground = selected
        ? AppColors.secondary.withValues(alpha: 0.16)
        : (isDark ? AppColors.darkBackground : AppColors.surfaceWarm);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 138),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: emojiBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      emotion.emoji,
                      style: const TextStyle(fontSize: 21),
                    ),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 140),
                    opacity: selected ? 1 : 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryDeep,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                emotion.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? AppColors.secondaryDeep : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected
                      ? AppColors.secondaryDeep.withValues(alpha: 0.82)
                      : AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
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
    final dateLabel = isToday
        ? 'Today'
        : '${date.day}/${date.month}/${date.year}';
    final timeLabel = AppDateUtils.formatTime(date);

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
            '$dateLabel · $timeLabel',
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
  const _SmallToggle({required this.type, required this.onChanged});

  final String type;
  final ValueChanged<String> onChanged;

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
            selected: type == 'expense',
            color: AppColors.expense,
            onTap: () => onChanged('expense'),
          ),
          _ToggleTab(
            label: 'Income',
            selected: type == 'income',
            color: AppColors.income,
            onTap: () => onChanged('income'),
          ),
          _ToggleTab(
            label: 'Save',
            selected: type == 'saving',
            color: AppColors.saving,
            onTap: () => onChanged('saving'),
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

// ---------------------------------------------------------------------------
// Location row
// ---------------------------------------------------------------------------

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.locationData,
    required this.isLoading,
    required this.onCapture,
    required this.onSearch,
    required this.onClear,
  });

  final LocationData? locationData;
  final bool isLoading;
  final VoidCallback onCapture;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasLocation = locationData != null;
    final background = hasLocation
        ? AppColors.secondary.withValues(alpha: isDark ? 0.18 : 0.08)
        : (isDark
              ? AppColors.darkSurface.withValues(alpha: 0.88)
              : AppColors.surfaceWarm.withValues(alpha: 0.94));
    final borderColor = hasLocation
        ? AppColors.secondary.withValues(alpha: 0.24)
        : (isDark
              ? AppColors.darkTextSecondary.withValues(alpha: 0.16)
              : AppColors.divider.withValues(alpha: 0.95));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TideSurfaceIcon(
                icon: hasLocation
                    ? Icons.place_rounded
                    : Icons.add_location_alt_rounded,
                size: 17,
                color: hasLocation
                    ? AppColors.secondaryDeep
                    : AppColors.primaryDeep,
                backgroundColor: hasLocation
                    ? AppColors.secondary.withValues(alpha: 0.14)
                    : (isDark ? AppColors.darkSurface : AppColors.surface),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading
                          ? 'Finding your current spot'
                          : hasLocation
                          ? 'Location attached'
                          : 'Add context with a place',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: hasLocation ? AppColors.secondaryDeep : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isLoading)
                      Text(
                        'This only takes a moment.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    else if (hasLocation)
                      Text(
                        locationData!.label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.secondaryDeep,
                              height: 1.35,
                            ),
                      )
                    else
                      Text(
                        'Search for a place or use your current spot so this transaction is easier to revisit later.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TidePill(
                label: hasLocation ? 'Attached' : 'Optional',
                color: hasLocation
                    ? AppColors.secondaryDeep
                    : AppColors.textSecondary,
                backgroundColor: hasLocation
                    ? AppColors.secondary.withValues(alpha: 0.14)
                    : AppColors.surface.withValues(alpha: 0.92),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isLoading)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Getting your location...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            )
          else if (hasLocation)
            Text(
              'You can swap this place, refresh it from your current position, or remove it entirely.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryDeep.withValues(alpha: 0.82),
                height: 1.45,
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: isLoading ? null : onCapture,
                icon: Icon(
                  hasLocation
                      ? Icons.my_location_rounded
                      : Icons.near_me_rounded,
                  size: 16,
                ),
                label: Text(
                  hasLocation ? 'Refresh current' : 'Use current spot',
                ),
                style: FilledButton.styleFrom(
                  foregroundColor: AppColors.primaryDeep,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: isLoading ? null : onSearch,
                icon: const Icon(Icons.search_rounded, size: 16),
                label: Text(hasLocation ? 'Change place' : 'Search place'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: hasLocation
                      ? AppColors.secondaryDeep
                      : AppColors.primary,
                  side: BorderSide(
                    color: hasLocation
                        ? AppColors.secondary.withValues(alpha: 0.34)
                        : AppColors.divider,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              if (hasLocation)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location search sheet
// ---------------------------------------------------------------------------

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet({
    required this.service,
    required this.initialQuery,
  });

  final LocationService service;
  final String initialQuery;

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  late final TextEditingController _controller;
  Timer? _debounce;
  List<LocationData> _results = const [];
  bool _searching = false;
  bool _searched = false;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().isNotEmpty) {
      _runSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
        _searched = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    setState(() => _searching = true);
    final results = await widget.service.searchPlaces(query);
    if (!mounted || token != _searchToken) return;
    setState(() {
      _results = results;
      _searching = false;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Search a place',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: _runSearch,
                decoration: InputDecoration(
                  hintText: 'e.g. Pasar Santa, Jakarta',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: _buildResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_searched) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Type a place name or address to search.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No matches. Try a different name or include the city.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.6)),
      itemBuilder: (context, i) {
        final r = _results[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(
            Icons.location_on_outlined,
            color: AppColors.secondary,
          ),
          title: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          onTap: () => Navigator.of(context).pop(r),
        );
      },
    );
  }
}
