import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'providers/database_provider.dart';
import 'providers/settings_provider.dart';
import 'services/google_drive_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Offline-first: never reach for fonts.gstatic.com at runtime. Bundled
  // TTFs in assets/google_fonts/ are used; otherwise fall back to system fonts.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: DebbieApp()));
}

class DebbieApp extends ConsumerStatefulWidget {
  const DebbieApp({super.key});

  @override
  ConsumerState<DebbieApp> createState() => _DebbieAppState();
}

class _DebbieAppState extends ConsumerState<DebbieApp> {
  bool _autoBackupChecked = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final darkModeAsync = ref.watch(darkModeProvider);
    final isDark = darkModeAsync.valueOrNull ?? false;

    // Trigger auto-backup check once on startup
    if (!_autoBackupChecked) {
      _autoBackupChecked = true;
      _checkAutoBackup();
    }

    return MaterialApp.router(
      title: 'Debbie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }

  Future<void> _checkAutoBackup() async {
    try {
      final autoEnabled = await ref.read(autoBackupProvider.future);
      if (!autoEnabled) return;

      final googleEmail = await ref.read(googleEmailProvider.future);
      if (googleEmail == null || googleEmail.isEmpty) return;

      // Check if 24+ hours since last backup
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final lastBackupStr = await settingsRepo.get('last_backup_date');
      if (lastBackupStr != null) {
        final lastBackup = DateTime.tryParse(lastBackupStr);
        if (lastBackup != null) {
          final hoursSince = DateTime.now().difference(lastBackup).inHours;
          if (hoursSince < 24) return;
        }
      }

      // Perform silent backup
      final driveService = ref.read(googleDriveServiceProvider);
      await driveService.backup();

      final now = DateTime.now().toIso8601String();
      await settingsRepo.set('last_backup_date', now);
      ref.invalidate(lastBackupDateProvider);
    } catch (_) {
      // Auto-backup failures are silent
    }
  }
}
