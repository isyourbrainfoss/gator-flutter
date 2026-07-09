import 'package:flutter/foundation.dart';

/// Simple tagged logger for Gator.
/// Uses debugPrint so output is visible in dev and reasonably stripped in release.
class GatorLog {
  GatorLog._();

  static void d(String tag, String message) {
    debugPrint('[$tag] $message');
  }

  static void w(String tag, String message) {
    debugPrint('[$tag][WARN] $message');
  }

  static void e(String tag, String message, [Object? error, StackTrace? stack]) {
    final errPart = error != null ? ' : $error' : '';
    debugPrint('[$tag][ERROR] $message$errPart');
    if (stack != null && kDebugMode) {
      debugPrint(stack.toString());
    }
  }
}
