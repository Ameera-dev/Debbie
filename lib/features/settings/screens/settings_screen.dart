import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/value_model.dart';
import '../../../providers/daily_intentions_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/goals_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/mindfulness_provider.dart';
import '../../../providers/recurring_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../providers/weekly_budget_provider.dart';
import '../../../services/export_service.dart';
import '../../../services/google_drive_service.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/utils/currency.dart';
import '../../../shared/utils/id_generator.dart';
import '../../../shared/widgets/tide.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _backingUp = false;
  bool _restoring = false;

  @override
  Widget build(BuildContext context) {
    final darkModeAsync = ref.watch(darkModeProvider);
    final isDark = darkModeAsync.valueOrNull ?? false;
    final aiEnabled =
        ref.watch(aiReflectionEnabledProvider).valueOrNull ?? false;
    final apiKey = ref.watch(geminiApiKeyProvider).valueOrNull;
    final hasKey = apiKey != null && apiKey.isNotEmpty;
    final values = ref.watch(valuesProvider).valueOrNull ?? [];

    final googleEmail = ref.watch(googleEmailProvider).valueOrNull;
    final isConnected = googleEmail != null && googleEmail.isNotEmpty;
    final autoBackup = ref.watch(autoBackupProvider).valueOrNull ?? false;
    final lastBackup = ref.watch(lastBackupDateProvider).valueOrNull;
    final appVersion = ref.watch(appVersionProvider).valueOrNull ?? '...';
    final coolingOffThreshold =
        ref.watch(coolingOffThresholdProvider).valueOrNull ?? 500000;
    final goals = ref.watch(goalsProvider).valueOrNull ?? const <GoalModel>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.settingsTitle,
          style: GoogleFonts.lora(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: TidePageBackground(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            TidePageIntro(
              eyebrow: AppStrings.settingsTitle,
              title: Text.rich(
                TextSpan(
                  style: GoogleFonts.lora(
                    fontSize: 30,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  children: const [
                    TextSpan(text: 'Make Debbie feel more '),
                    TextSpan(
                      text: 'yours',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    TextSpan(text: '.'),
                  ],
                ),
              ),
              subtitle:
                  'Tune appearance, prompts, backup, and data handling without changing how the app works.',
              trailing: const TideSurfaceIcon(icon: Icons.tune_rounded),
            ),
            const SizedBox(height: 8),
            _SectionHeader(title: AppStrings.settingsAppearance),
            SwitchListTile(
              title: const Text(AppStrings.darkMode),
              value: isDark,
              onChanged: (_) => ref.read(darkModeProvider.notifier).toggle(),
              activeThumbColor: AppColors.primary,
            ),
            const Divider(),

            _SectionHeader(title: 'Mindful Logging'),
            ListTile(
              leading: const Icon(Icons.hourglass_top_rounded),
              title: const Text('Cooling-off threshold'),
              subtitle: const Text(
                'Expenses at or above this amount can be set aside for 24 hours.',
              ),
              trailing: Text(
                CurrencyUtils.format(coolingOffThreshold),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _showCoolingOffThresholdDialog(coolingOffThreshold),
            ),
            const Divider(),

            if (values.isNotEmpty) ...[
              _SectionHeader(title: 'Value Guardians'),
              ...values.map((value) {
                final guardian = value.guardianText?.trim();
                return ListTile(
                  leading: Text(
                    value.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(value.name),
                  subtitle: Text(
                    guardian?.isNotEmpty == true
                        ? guardian!
                        : 'Add one line about what this value protects.',
                    style: TextStyle(
                      color: guardian?.isNotEmpty == true
                          ? AppColors.textSecondary
                          : AppColors.primary.withValues(alpha: 0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _showGuardianDialog(value.id, value.name, guardian),
                );
              }),
              const Divider(),
            ],

            // ── Impact Goals ──────────────────────────────────────────
            _SectionHeader(title: 'Impact Goals'),
            if (goals.isEmpty)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('No goals yet'),
                subtitle: Text(
                  'Create one to channel your spending toward what matters.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.add),
                onTap: () => _showGoalDialog(values: values),
              )
            else ...[
              ...goals.map((goal) {
                final ValueModel? value = values
                    .where((v) => v.id == goal.valueId)
                    .firstOrNull;
                final valueIcon = value?.icon ?? '🎯';
                final valueName = value?.name ?? 'Unlinked';
                final progress = goal.progressPercent;
                final progressLabel = goal.targetAmount != null
                    ? '${CurrencyUtils.format(goal.currentAmount)} / ${CurrencyUtils.format(goal.targetAmount!)}'
                    : CurrencyUtils.format(goal.currentAmount);
                return ListTile(
                  leading: Text(
                    valueIcon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.title,
                          style: TextStyle(
                            decoration: goal.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (goal.isCompleted)
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.income,
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$valueName · $progressLabel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: AppColors.divider,
                            valueColor: AlwaysStoppedAnimation(
                              goal.isCompleted
                                  ? AppColors.income
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) =>
                        _handleGoalAction(action, goal, values),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: goal.isCompleted ? 'reactivate' : 'complete',
                        child: Text(
                          goal.isCompleted
                              ? 'Mark as active'
                              : 'Mark as complete',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: AppColors.expense),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _showGoalDialog(values: values, existing: goal),
                );
              }),
              ListTile(
                leading: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                ),
                title: Text(
                  'Add a goal',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _showGoalDialog(values: values),
              ),
            ],
            const Divider(),

            // ── AI Reflection ─────────────────────────────────────────
            _SectionHeader(title: AppStrings.settingsAiReflection),
            SwitchListTile(
              title: const Text(AppStrings.aiReflectionToggle),
              subtitle: Text(
                hasKey
                    ? AppStrings.aiReflectionToggleSubtitle
                    : AppStrings.aiReflectionNoKey,
                style: TextStyle(
                  color: hasKey
                      ? AppColors.textSecondary
                      : AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
              value: aiEnabled,
              onChanged: hasKey
                  ? (_) =>
                        ref.read(aiReflectionEnabledProvider.notifier).toggle()
                  : null,
              activeThumbColor: AppColors.primary,
            ),
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text(AppStrings.geminiApiKeyLabel),
              subtitle: Text(
                hasKey
                    ? '••••••••${apiKey.substring(apiKey.length - 4)}'
                    : 'Not set',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showApiKeyDialog(context, apiKey),
            ),
            const Divider(),

            // ── Data / Google Drive ───────────────────────────────────
            _SectionHeader(title: AppStrings.settingsData),

            // Google account connection
            if (!isConnected)
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: const Text(AppStrings.connectGoogle),
                subtitle: const Text('Backup and restore your data'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _connectGoogle,
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: Text(googleEmail),
                trailing: TextButton(
                  onPressed: _disconnectGoogle,
                  child: Text(
                    AppStrings.disconnectGoogle,
                    style: TextStyle(color: AppColors.expense),
                  ),
                ),
              ),

              // Back Up Now
              ListTile(
                leading: _backingUp
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.backup_outlined),
                title: Text(
                  _backingUp ? AppStrings.backingUp : AppStrings.backupNow,
                ),
                onTap: _backingUp ? null : _backupNow,
              ),

              // Restore
              ListTile(
                leading: _restoring
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_outlined),
                title: Text(
                  _restoring ? AppStrings.restoring : 'Restore from backup',
                ),
                onTap: _restoring ? null : _showRestoreDialog,
              ),

              // Auto-backup toggle
              SwitchListTile(
                title: const Text(AppStrings.autoBackup),
                subtitle: const Text(AppStrings.autoBackupSubtitle),
                value: autoBackup,
                onChanged: (_) =>
                    ref.read(autoBackupProvider.notifier).toggle(),
                activeThumbColor: AppColors.primary,
              ),

              // Last backup info
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text(AppStrings.lastBackup),
                trailing: Text(
                  _formatBackupDate(lastBackup),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],

            // Image storage info
            _ImageStorageInfo(),

            const Divider(),

            // ── Export ───────────���───────────────────────────────────────
            _SectionHeader(title: 'Export'),
            _ExportSection(),

            const Divider(),
            _SectionHeader(title: AppStrings.settingsAbout),
            ListTile(
              title: const Text(AppStrings.appName),
              subtitle: const Text(AppStrings.madeWithIntention),
              leading: const Text('🌱', style: TextStyle(fontSize: 24)),
            ),
            ListTile(
              title: const Text('Version'),
              trailing: Text(
                appVersion,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCoolingOffThresholdDialog(int currentAmount) {
    final controller = TextEditingController(
      text: currentAmount > 0 ? currentAmount.toString() : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cooling-off threshold'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: 'Rp ',
            hintText: '500000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(controller.text) ?? 0;
              ref
                  .read(coolingOffThresholdProvider.notifier)
                  .setThreshold(amount);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showGuardianDialog(
    String valueId,
    String valueName,
    String? currentGuardian,
  ) {
    final controller = TextEditingController(text: currentGuardian ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$valueName guardian'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Why does this value matter so much to you?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (currentGuardian?.isNotEmpty == true)
            TextButton(
              onPressed: () {
                ref.read(valuesProvider.notifier).updateGuardian(valueId, null);
                Navigator.of(ctx).pop();
              },
              child: Text('Remove', style: TextStyle(color: AppColors.expense)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(valuesProvider.notifier)
                  .updateGuardian(valueId, controller.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Goals ───────────────────────────────────────────────────────────────

  Future<void> _handleGoalAction(
    String action,
    GoalModel goal,
    List<ValueModel> values,
  ) async {
    switch (action) {
      case 'edit':
        await _showGoalDialog(values: values, existing: goal);
      case 'complete':
        await ref
            .read(goalsProvider.notifier)
            .edit(
              goal.copyWith(status: 'completed', completedAt: DateTime.now()),
            );
      case 'reactivate':
        await ref
            .read(goalsProvider.notifier)
            .edit(goal.copyWith(status: 'active', clearCompletedAt: true));
      case 'delete':
        await _confirmDeleteGoal(goal);
    }
  }

  Future<void> _confirmDeleteGoal(GoalModel goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: Text(
          'This removes "${goal.title}" permanently. Linked transactions stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(goalsProvider.notifier).remove(goal.id);
    }
  }

  Future<void> _showGoalDialog({
    required List<ValueModel> values,
    GoalModel? existing,
  }) async {
    if (values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one value before creating a goal.'),
        ),
      );
      return;
    }
    final titleController = TextEditingController(text: existing?.title ?? '');
    final targetController = TextEditingController(
      text: existing?.targetAmount?.toString() ?? '',
    );
    String selectedValueId = existing?.valueId ?? values.first.id;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(existing == null ? 'New goal' : 'Edit goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Family trip',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedValueId,
                  decoration: const InputDecoration(
                    labelText: 'Linked value',
                    border: OutlineInputBorder(),
                  ),
                  items: values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v.id,
                          child: Text('${v.icon}  ${v.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setLocalState(() => selectedValueId = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target amount (optional)',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    final target = int.tryParse(targetController.text.trim());

    if (existing == null) {
      await ref
          .read(goalsProvider.notifier)
          .add(
            GoalModel(
              id: IdGenerator.generate(),
              title: title,
              valueId: selectedValueId,
              targetAmount: target,
              currentAmount: 0,
              status: 'active',
              createdAt: DateTime.now(),
            ),
          );
    } else {
      await ref
          .read(goalsProvider.notifier)
          .edit(
            existing.copyWith(
              title: title,
              valueId: selectedValueId,
              targetAmount: target,
              clearTargetAmount: target == null,
            ),
          );
    }
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────

  Future<void> _connectGoogle() async {
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      final account = await driveService.signIn();
      if (account != null) {
        await ref.read(googleEmailProvider.notifier).setEmail(account.email);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sign-in was canceled or did not complete. Check Google OAuth setup if this keeps happening.',
            ),
          ),
        );
      }
    } on GoogleDriveAuthException catch (e) {
      debugPrint('Google sign-in failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
      }
    } on PlatformException catch (e) {
      debugPrint(
        'Google sign-in failed: code=${e.code}, message=${e.message}, details=${e.details}',
      );
      if (mounted) {
        final message = [
          e.code,
          if (e.message != null && e.message!.isNotEmpty) e.message,
        ].join(': ');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sign-in failed: $message')));
      }
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
      }
    }
  }

  Future<void> _disconnectGoogle() async {
    final driveService = ref.read(googleDriveServiceProvider);
    await driveService.signOut();
    await ref.read(googleEmailProvider.notifier).setEmail(null);
    // Also disable auto-backup
    final autoBackupEnabled = ref.read(autoBackupProvider).valueOrNull ?? false;
    if (autoBackupEnabled) {
      await ref.read(autoBackupProvider.notifier).toggle();
    }
  }

  // ── Backup ────────────────────────────────────────────────────────────────

  Future<void> _backupNow() async {
    setState(() => _backingUp = true);
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      await driveService.backup();

      // Update last backup date
      final now = DateTime.now().toIso8601String();
      final settingsRepo = ref.read(settingsRepositoryProvider);
      await settingsRepo.set('last_backup_date', now);
      ref.invalidate(lastBackupDateProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.backupSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  Future<void> _showRestoreDialog() async {
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      final backups = await driveService.listBackups();

      if (backups.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.errorNoBackups)),
          );
        }
        return;
      }

      if (!mounted) return;

      final selected = await showModalBottomSheet<BackupInfo>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _BackupPickerSheet(backups: backups),
      );

      if (selected == null || !mounted) return;

      // Confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(AppStrings.restoreConfirmTitle),
          content: const Text(AppStrings.restoreConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(AppStrings.restoreCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
              child: const Text(AppStrings.restoreConfirm),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      setState(() => _restoring = true);
      await driveService.restore(selected.id);
      _invalidateRestoredState();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.restoreSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _invalidateRestoredState() {
    ref.invalidate(onboardingCompleteProvider);
    ref.invalidate(darkModeProvider);
    ref.invalidate(monthlyIncomeProvider);
    ref.invalidate(googleEmailProvider);
    ref.invalidate(lastBackupDateProvider);
    ref.invalidate(autoBackupProvider);
    ref.invalidate(aiReflectionEnabledProvider);
    ref.invalidate(geminiApiKeyProvider);
    ref.invalidate(coolingOffThresholdProvider);

    ref.invalidate(valuesProvider);
    ref.invalidate(valuesPlanProvider);
    ref.invalidate(currentMonthPlanProvider);
    ref.invalidate(goalsProvider);
    ref.invalidate(activeGoalsProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(pendingTransactionsProvider);
    ref.invalidate(duePendingTransactionsProvider);
    ref.invalidate(currentMonthTransactionsProvider);
    ref.invalidate(monthlyIncomeAmountProvider);
    ref.invalidate(monthlyExpenseAmountProvider);
    ref.invalidate(allTimeIncomeProvider);
    ref.invalidate(allTimeExpenseProvider);
    ref.invalidate(availableBalanceProvider);
    ref.invalidate(spendingByValueProvider);
    ref.invalidate(todayTransactionsProvider);
    ref.invalidate(spendingStreakProvider);
    ref.invalidate(journalProvider);
    ref.invalidate(latestJournalEntryProvider);
    ref.invalidate(dailyIntentionsProvider);
    ref.invalidate(todayIntentionProvider);
    ref.invalidate(yesterdayIntentionProvider);
    ref.invalidate(weeklyBudgetPlansProvider);
    ref.invalidate(weeklyPerformanceHistoryProvider);
    ref.invalidate(recurringExpensesProvider);
    ref.invalidate(recurringPaymentsProvider);
    ref.invalidate(recurringPaymentHistoryProvider);
    ref.invalidate(recurringMonthSummaryProvider);
    ref.invalidate(awarenessStreakProvider);
  }

  // ── API Key Dialog ────────────────────────────────────────────────────────

  void _showApiKeyDialog(BuildContext context, String? currentKey) {
    final controller = TextEditingController(text: currentKey ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.geminiApiKeyLabel),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: AppStrings.geminiApiKeyHint,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (currentKey != null && currentKey.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(geminiApiKeyProvider.notifier).setKey(null);
                Navigator.of(ctx).pop();
              },
              child: Text('Remove', style: TextStyle(color: AppColors.expense)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(geminiApiKeyProvider.notifier).setKey(controller.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatBackupDate(String? isoDate) {
    if (isoDate == null) return AppStrings.never;
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return DateFormat('d MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return AppStrings.never;
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ---------------------------------------------------------------------------
// Image storage info widget
// ---------------------------------------------------------------------------

class _ImageStorageInfo extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driveService = ref.watch(googleDriveServiceProvider);
    return FutureBuilder<int>(
      future: driveService.getLocalImageStorageBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data ?? 0;
        final label = _SettingsScreenState._formatBytes(bytes);
        return ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text(AppStrings.imageStorage),
          trailing: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Backup picker
// ---------------------------------------------------------------------------

class _BackupPickerSheet extends StatefulWidget {
  const _BackupPickerSheet({required this.backups});

  final List<BackupInfo> backups;

  @override
  State<_BackupPickerSheet> createState() => _BackupPickerSheetState();
}

class _BackupPickerSheetState extends State<_BackupPickerSheet> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BackupInfo> get _filteredBackups {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.backups;

    return widget.backups.where((backup) {
      final dateLabel = _formatDate(backup.createdTime).toLowerCase();
      final sizeLabel = backup.size != null
          ? _SettingsScreenState._formatBytes(backup.size!).toLowerCase()
          : '';
      return backup.name.toLowerCase().contains(query) ||
          dateLabel.contains(query) ||
          sizeLabel.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBackups;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: widget.backups.length > 8 ? 0.78 : 0.6,
      minChildSize: 0.38,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TideSurfaceIcon(
                        icon: Icons.restore_rounded,
                        color: AppColors.primary,
                        backgroundColor: Color(0x143E6C7E),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TideEyebrow(label: 'Google Drive Restore'),
                            const SizedBox(height: 6),
                            Text(
                              AppStrings.selectBackup,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              filtered.length == widget.backups.length
                                  ? '${widget.backups.length} backups available'
                                  : '${filtered.length} of ${widget.backups.length} backups shown',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.backups.isNotEmpty)
                        TidePill(
                          label:
                              'Latest ${_formatShortDate(widget.backups.first.createdTime)}',
                          color: AppColors.primaryDeep,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.10,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search backup name, date, or size',
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                    onChanged: (value) {
                      setState(() => _query = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: filtered.isEmpty
                        ? _BackupEmptyState(query: _query)
                        : Scrollbar(
                            controller: scrollController,
                            thumbVisibility: filtered.length > 6,
                            child: ListView.separated(
                              controller: scrollController,
                              physics: const BouncingScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final backup = filtered[index];
                                final isLatest = identical(
                                  backup,
                                  widget.backups.first,
                                );
                                return _BackupListTile(
                                  backup: backup,
                                  isLatest: isLatest,
                                  onTap: () =>
                                      Navigator.of(context).pop(backup),
                                );
                              },
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.restoreCancel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime date) {
    return DateFormat('d MMM yyyy, HH:mm').format(date.toLocal());
  }

  static String _formatShortDate(DateTime date) {
    return DateFormat('d MMM').format(date.toLocal());
  }
}

class _BackupListTile extends StatelessWidget {
  const _BackupListTile({
    required this.backup,
    required this.onTap,
    required this.isLatest,
  });

  final BackupInfo backup;
  final VoidCallback onTap;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _BackupPickerSheetState._formatDate(backup.createdTime);
    final sizeLabel = backup.size != null
        ? _SettingsScreenState._formatBytes(backup.size!)
        : 'Unknown size';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surfaceWarm,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                TideSurfaceIcon(
                  icon: isLatest
                      ? Icons.history_toggle_off_rounded
                      : Icons.archive_outlined,
                  color: isLatest ? AppColors.primary : AppColors.textSoft,
                  backgroundColor: isLatest
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : AppColors.surface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              backup.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (isLatest) ...[
                            const SizedBox(width: 8),
                            TidePill(
                              label: 'Latest',
                              color: AppColors.primaryDeep,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.10,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _BackupMetaChip(
                            icon: Icons.storage_rounded,
                            label: sizeLabel,
                          ),
                          _BackupMetaChip(
                            icon: Icons.cloud_done_outlined,
                            label: 'Ready to restore',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackupMetaChip extends StatelessWidget {
  const _BackupMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupEmptyState extends StatelessWidget {
  const _BackupEmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No backups match "${query.trim()}".',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different file name, date, or size.',
              textAlign: TextAlign.center,
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
// Export section
// ---------------------------------------------------------------------------

class _ExportSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ExportSection> createState() => _ExportSectionState();
}

class _ExportSectionState extends ConsumerState<_ExportSection> {
  bool _exportingCsv = false;
  bool _exportingExcel = false;

  Future<void> _exportCsv() async {
    setState(() => _exportingCsv = true);
    try {
      await ref.read(exportServiceProvider).exportCsv();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _exportingExcel = true);
    try {
      await ref.read(exportServiceProvider).exportExcel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: _exportingCsv
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.description_outlined),
          title: const Text('Export as CSV'),
          subtitle: const Text('Spreadsheet-compatible, plain text'),
          onTap: _exportingCsv ? null : _exportCsv,
        ),
        ListTile(
          leading: _exportingExcel
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.table_chart_outlined),
          title: const Text('Export as Excel'),
          subtitle: const Text('Formatted .xlsx with styled headers'),
          onTap: _exportingExcel ? null : _exportExcel,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: TideEyebrow(label: title, color: AppColors.primary),
    );
  }
}
