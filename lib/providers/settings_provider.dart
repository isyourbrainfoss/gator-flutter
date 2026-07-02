import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/models/gator_settings.dart';
import 'package:gator/services/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('SettingsRepository must be overridden at startup');
});

class SettingsNotifier extends AsyncNotifier<Map<String, dynamic>> {
  late SettingsRepository _repo;

  @override
  Future<Map<String, dynamic>> build() async {
    _repo = ref.read(settingsRepositoryProvider);
    return _repo.load();
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final current = state.value ?? processSettings({});
    final updated = Map<String, dynamic>.from(current)..[key] = value;
    final processed = processSettings(updated);
    await _repo.save(processed);
    state = AsyncData(processed);
  }

  Future<void> updateMany(Map<String, dynamic> changes) async {
    final current = state.value ?? processSettings({});
    final updated = Map<String, dynamic>.from(current)..addAll(changes);
    final processed = processSettings(updated);
    await _repo.save(processed);
    state = AsyncData(processed);
  }

  Future<void> resetToDefaults() async {
    await _repo.resetToDefaults();
    state = AsyncData(processSettings({}));
  }

  Future<String> resolveSaveDir() async {
    final settings = state.value ?? processSettings({});
    return _repo.resolveSaveDir(settings);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, Map<String, dynamic>>(
  SettingsNotifier.new,
);