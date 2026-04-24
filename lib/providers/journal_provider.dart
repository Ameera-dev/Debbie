import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/journal_entry_model.dart';
import 'database_provider.dart';

final journalProvider =
    AsyncNotifierProvider<JournalNotifier, List<JournalEntryModel>>(
      JournalNotifier.new,
    );

class JournalNotifier extends AsyncNotifier<List<JournalEntryModel>> {
  @override
  Future<List<JournalEntryModel>> build() async {
    return ref.watch(journalRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(journalRepositoryProvider).getAll(),
    );
  }

  Future<void> add(JournalEntryModel entry) async {
    await ref.read(journalRepositoryProvider).insert(entry);
    await refresh();
  }

  Future<void> edit(JournalEntryModel entry) async {
    await ref.read(journalRepositoryProvider).update(entry);
    await refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(journalRepositoryProvider).delete(id);
    await refresh();
  }
}

final latestJournalEntryProvider = FutureProvider<JournalEntryModel?>((ref) {
  ref.watch(journalProvider);
  return ref.watch(journalRepositoryProvider).getLatest();
});
