import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:gator/core/logger.dart';

/// Locates the bundled croc binary for the current platform.
class CrocBinaryLocator {
  CrocBinaryLocator({this.cachedPath});

  String? cachedPath;

  static const _crocChannel = MethodChannel('org.gator.gator/croc');

  /// Returns the path to an executable croc binary, or null if unavailable.
  Future<String?> locate() async {
    if (cachedPath != null) return cachedPath;

    if (kIsWeb) return null;

    if (!Platform.isAndroid) {
      final resolved = await _resolveDesktopCroc();
      return cachedPath = resolved;
    }

    try {
      final path = await _crocChannel.invokeMethod<String>('getCrocPath');
      if (path != null && path.isNotEmpty) {
        return cachedPath = path;
      }
    } catch (e, st) {
      GatorLog.e('CrocBinaryLocator', 'Failed to get croc path via channel', e, st);
    }
    return null;
  }

  /// Verify croc runs and return version string, or null on failure.
  Future<String?> verify() async {
    if (Platform.isAndroid) {
      try {
        return await _crocChannel.invokeMethod<String>('verifyCroc');
      } catch (e, st) {
        GatorLog.e('CrocBinaryLocator', 'Android verifyCroc failed', e, st);
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
    } catch (e, st) {
      GatorLog.e('CrocBinaryLocator', 'Process --version failed for $path', e, st);
      return null;
    }
    return null;
  }

  Future<String?> _resolveDesktopCroc() async {
    try {
      final nextToApp = File(
        '${File(Platform.resolvedExecutable).parent.path}/croc',
      );
      if (await nextToApp.exists()) return nextToApp.path;
    } catch (e) {
      GatorLog.d('CrocBinaryLocator', 'resolvedExecutable croc: $e');
    }
    const bundled = '/app/bin/croc';
    if (await File(bundled).exists()) return bundled;

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
        if (path.isNotEmpty && await File(path).exists()) return path;
      }
    } catch (e) {
      GatorLog.d('CrocBinaryLocator', 'which croc failed: $e');
    }
    return null;
  }
}
