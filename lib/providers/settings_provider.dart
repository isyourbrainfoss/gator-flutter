import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/models/gator_settings.dart';
import 'package:gator/services/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('SettingsRepository must be overridden at startup');
});

class SettingsNotifier extends AsyncNotifier<GatorSettings> {
  late SettingsRepository _repo;

  @override
  Future<GatorSettings> build() async {
    _repo = ref.read(settingsRepositoryProvider);
    return _repo.load();
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final current = state.value ?? GatorSettings.defaults();
    final updated = Map<String, dynamic>.from(current.toMap())..[key] = value;
    final processed = GatorSettings.fromMap(updated);
    await _repo.save(processed);
    state = AsyncData(processed);
  }

  Future<void> updateMany(Map<String, dynamic> changes) async {
    final current = state.value ?? GatorSettings.defaults();
    final updated = Map<String, dynamic>.from(current.toMap())..addAll(changes);
    final processed = GatorSettings.fromMap(updated);
    await _repo.save(processed);
    state = AsyncData(processed);
  }

  Future<void> resetToDefaults() async {
    await _repo.resetToDefaults();
    state = AsyncData(GatorSettings.fromMap({}));
  }

  Future<String> resolveSaveDir() async {
    final settings = state.value ?? GatorSettings.defaults();
    return _repo.resolveSaveDir(settings);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, GatorSettings>(
  SettingsNotifier.new,
);