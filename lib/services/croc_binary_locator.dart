import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Locates and extracts the bundled croc binary for the current Android ABI.
class CrocBinaryLocator {
  CrocBinaryLocator({this._cachedPath});

  String? _cachedPath;

  static const _assetMap = {
    'arm64': 'assets/croc/arm64-v8a/croc',
    'arm64-v8a': 'assets/croc/arm64-v8a/croc',
    'x86_64': 'assets/croc/x86_64/croc',
    'armeabi-v7a': 'assets/croc/armeabi-v7a/croc',
  };

  /// Returns the path to an executable croc binary, or null if unavailable.
  Future<String?> locate() async {
    if (_cachedPath != null) return _cachedPath;

    if (kIsWeb) return null;

    if (!Platform.isAndroid) {
      // Desktop dev: resolve full path (GUI apps often have minimal PATH).
      final resolved = await _resolveDesktopCroc();
      return _cachedPath = resolved;
    }

    final abi = await _currentAbi();
    final assetPath = _assetMap[abi] ?? _assetMap['arm64-v8a'];
    if (assetPath == null) return null;

    try {
      final bytes = await rootBundle.load(assetPath);
      final dir = await getApplicationSupportDirectory();
      final crocFile = File('${dir.path}/croc');
      await crocFile.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      await Process.run('chmod', ['+x', crocFile.path]);
      _cachedPath = crocFile.path;
      return _cachedPath;
    } on FlutterError {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Verify croc runs and return version string, or null on failure.
  Future<String?> verify() async {
    final path = await locate();
    if (path == null) return null;
    try {
      final result = await Process.run(path, ['--version']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
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

  Future<String> _currentAbi() async {
    const channel = MethodChannel('org.gator.gator/abi');
    try {
      final abi = await channel.invokeMethod<String>('getAbi');
      if (abi != null && abi.isNotEmpty) return abi;
    } catch (_) {
      // Fall through.
    }
    return 'arm64-v8a';
  }
}