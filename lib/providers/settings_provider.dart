import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/tables.dart';
import '../shared/constants/mindfulness.dart';
import 'database_provider.dart';

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getBool(SettingsKeys.onboardingComplete);
});

final darkModeProvider = AsyncNotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);

class DarkModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getBool(SettingsKeys.darkMode);
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? false;
    final next = !current;
    state = AsyncValue.data(next);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setBool(SettingsKeys.darkMode, value: next);
  }
}

final monthlyIncomeProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return (await repo.getInt(SettingsKeys.monthlyIncome)) ?? 0;
});

// ---------------------------------------------------------------------------
// Google Drive backup settings
// ---------------------------------------------------------------------------

final googleEmailProvider = AsyncNotifierProvider<GoogleEmailNotifier, String?>(
  GoogleEmailNotifier.new,
);

class GoogleEmailNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.get(SettingsKeys.googleEmail);
  }

  Future<void> setEmail(String? email) async {
    final repo = ref.read(settingsRepositoryProvider);
    if (email == null || email.isEmpty) {
      await repo.delete(SettingsKeys.googleEmail);
      state = const AsyncValue.data(null);
    } else {
      await repo.set(SettingsKeys.googleEmail, email);
      state = AsyncValue.data(email);
    }
  }
}

final lastBackupDateProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.get(SettingsKeys.lastBackupDate);
});

final autoBackupProvider = AsyncNotifierProvider<AutoBackupNotifier, bool>(
  AutoBackupNotifier.new,
);

class AutoBackupNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getBool(SettingsKeys.autoBackup);
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? false;
    final next = !current;
    state = AsyncValue.data(next);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setBool(SettingsKeys.autoBackup, value: next);
  }
}

// ---------------------------------------------------------------------------
// AI Reflection settings
// ---------------------------------------------------------------------------

final aiReflectionEnabledProvider =
    AsyncNotifierProvider<AiReflectionEnabledNotifier, bool>(
      AiReflectionEnabledNotifier.new,
    );

class AiReflectionEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getBool(SettingsKeys.aiReflectionEnabled);
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? false;
    final next = !current;
    state = AsyncValue.data(next);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setBool(SettingsKeys.aiReflectionEnabled, value: next);
  }

  Future<void> setEnabled(bool value) async {
    state = AsyncValue.data(value);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setBool(SettingsKeys.aiReflectionEnabled, value: value);
  }
}

final geminiApiKeyProvider =
    AsyncNotifierProvider<GeminiApiKeyNotifier, String?>(
      GeminiApiKeyNotifier.new,
    );

class GeminiApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.get(SettingsKeys.geminiApiKey);
  }

  Future<void> setKey(String? key) async {
    final repo = ref.read(settingsRepositoryProvider);
    if (key == null || key.trim().isEmpty) {
      await repo.delete(SettingsKeys.geminiApiKey);
      state = const AsyncValue.data(null);
      // Also disable AI reflection when key is cleared
      await ref.read(aiReflectionEnabledProvider.notifier).setEnabled(false);
    } else {
      await repo.set(SettingsKeys.geminiApiKey, key.trim());
      state = AsyncValue.data(key.trim());
    }
  }
}

final coolingOffThresholdProvider =
    AsyncNotifierProvider<CoolingOffThresholdNotifier, int>(
      CoolingOffThresholdNotifier.new,
    );

class CoolingOffThresholdNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return (await repo.getInt(SettingsKeys.coolingOffThreshold)) ??
        MindfulnessContent.defaultCoolingOffThreshold;
  }

  Future<void> setThreshold(int amount) async {
    state = AsyncValue.data(amount);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setInt(SettingsKeys.coolingOffThreshold, amount);
  }
}
