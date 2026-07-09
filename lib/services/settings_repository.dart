import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/models/gator_settings.dart';

/// Persists Gator settings via shared_preferences JSON blob.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsRepository(prefs);
  }

  GatorSettings load() {
    final json = _prefs.getString(settingsStorageKey);
    if (json == null || json.isEmpty) {
      return GatorSettings.fromMap({});
    }
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        return GatorSettings.fromMap(decoded);
      }
    } catch (_) {
      // Fall through to defaults.
    }
    return GatorSettings.fromMap({});
  }

  Future<void> save(GatorSettings settings) async {
    final toSave = settings.toDiffMap();
    await _prefs.setString(settingsStorageKey, jsonEncode(toSave));
  }

  Future<void> resetToDefaults() async {
    await _prefs.remove(settingsStorageKey);
  }

  /// Resolve save directory path, using persisted value or platform default.
  Future<String> resolveSaveDir(GatorSettings settings) async {
    final saved = settings.saveDir;
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return '${downloads.path}/Gator';
      }
    } catch (_) {
      // getDownloadsDirectory is unavailable in some test/desktop environments.
    }
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/Gator';
  }
}