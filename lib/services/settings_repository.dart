import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/core/logger.dart';
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
    } catch (e) {
      GatorLog.w('SettingsRepository', 'Failed to decode settings JSON, falling back to defaults: $e');
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
      if (await _isWritableDir(saved)) return saved;
      GatorLog.w('SettingsRepository', 'Saved save_dir is not writable: $saved');
    }
    if (Platform.isAndroid) {
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final path = '${ext.path}/Gator';
          await Directory(path).create(recursive: true);
          return path;
        }
      } catch (e) {
        GatorLog.w('SettingsRepository', 'Android app-files dir failed: $e');
      }
    }
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final path = '${downloads.path}/Gator';
        await Directory(path).create(recursive: true);
        return path;
      }
    } catch (e) {
      GatorLog.w('SettingsRepository', 'getDownloadsDirectory failed: $e');
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final path = '${docs.path}/Gator';
      await Directory(path).create(recursive: true);
      return path;
    } catch (e) {
      GatorLog.w('SettingsRepository', 'getApplicationDocumentsDirectory failed: $e');
    }
    return getDefaultSaveDirLabel();
  }

  static Future<bool> _isWritableDir(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) await dir.create(recursive: true);
      final probe = File('${dir.path}/.gator-write-test');
      await probe.writeAsString('ok');
      await probe.delete();
      return true;
    } catch (e) {
      GatorLog.w('SettingsRepository', 'Write probe failed for $path: $e');
      return false;
    }
  }
}