import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/values_provider.dart';
import '../../../services/export_service.dart';
import '../../../services/google_drive_service.dart';
import '../../../shared/constants/strings.dart';
import '../../../shared/utils/currency.dart';
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
    final coolingOffThreshold =
        ref.watch(coolingOffThresholdProvider).valueOrNull ?? 500000;

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
            const ListTile(
              title: Text('Version'),
              trailing: Text(
                '1.0.0',
                style: TextStyle(color: AppColors.textSecondary),
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

  // ── Google Sign-In ──────────────────────────────────────────────────────

  Future<void> _connectGoogle() async {
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      final account = await driveService.signIn();
      if (account != null) {
        await ref.read(googleEmailProvider.notifier).setEmail(account.email);
      }
    } catch (e) {
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

      final selected = await showDialog<BackupInfo>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(AppStrings.selectBackup),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (ctx, i) {
                final b = backups[i];
                final dateStr = DateFormat(
                  'd MMM yyyy, HH:mm',
                ).format(b.createdTime.toLocal());
                final sizeStr = b.size != null ? _formatBytes(b.size!) : '';
                return ListTile(
                  title: Text(b.name),
                  subtitle: Text('$dateStr  $sizeStr'),
                  onTap: () => Navigator.of(ctx).pop(b),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(AppStrings.restoreCancel),
            ),
          ],
        ),
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

      // Invalidate all providers to reload state
      ref.invalidate(lastBackupDateProvider);
      ref.invalidate(googleEmailProvider);
      ref.invalidate(autoBackupProvider);

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
