import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Locates the bundled croc binary for the current platform.
class CrocBinaryLocator {
  CrocBinaryLocator({this._cachedPath});

  String? _cachedPath;

  static const _crocChannel = MethodChannel('org.gator.gator/croc');

  /// Returns the path to an executable croc binary, or null if unavailable.
  Future<String?> locate() async {
    if (_cachedPath != null) return _cachedPath;

    if (kIsWeb) return null;

    if (!Platform.isAndroid) {
      final resolved = await _resolveDesktopCroc();
      return _cachedPath = resolved;
    }

    try {
      final path = await _crocChannel.invokeMethod<String>('getCrocPath');
      if (path != null && path.isNotEmpty) {
        return _cachedPath = path;
      }
    } catch (_) {
      // Fall through.
    }
    return null;
  }

  /// Verify croc runs and return version string, or null on failure.
  Future<String?> verify() async {
    if (Platform.isAndroid) {
      try {
        return await _crocChannel.invokeMethod<String>('verifyCroc');
      } catch (_) {
        return null;
      }
    }

    final path = await locate();
    if (path == null) return null;
    try {
      final result = await Process.run(path, ['--version']);
      if (result.exitCode == 0) {
        final out = (result.stdout as String).trim();
        if (out.isNotEmpty) return out;
      }
      final err = (result.stderr as String).trim();
      if (err.isNotEmpty) return err;
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<String> _resolveDesktopCroc() async {
    for (final dir in (Platform.environment['PATH'] ?? '').split(':')) {
      if (dir.isEmpty) continue;
      final candidate = File('$dir/croc');
      if (await candidate.exists()) return candidate.path;
    }
    for (final path in ['/usr/bin/croc', '/usr/local/bin/croc']) {
      if (await File(path).exists()) return path;
    }
    try {
      final which = await Process.run('which', ['croc']);
      if (which.exitCode == 0) {
        final path = (which.stdout as String).trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}
    return 'croc';
  }
}