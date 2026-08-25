import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android foreground-service keepalive so transfers can continue in the background.
abstract final class TransferKeepalive {
  static const _channel = MethodChannel('org.gator.gator/keepalive');

  static Future<void> start() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('start');
    } catch (_) {
      // Best-effort; transfers still run without an FGS.
    }
  }

  static Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // Ignore.
    }
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
