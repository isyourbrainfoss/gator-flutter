import 'dart:io';

import 'package:flutter/services.dart';

/// Platform QR camera scanning (native CameraX on Android).
abstract final class QrScannerService {
  static const _channel = MethodChannel('org.gator.gator/qr');

  static Future<String?> scanCamera() async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('scanQrCode');
  }
}