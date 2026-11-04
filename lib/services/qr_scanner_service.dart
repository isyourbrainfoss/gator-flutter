import 'dart:io';

import 'package:flutter/services.dart';

/// Why a QR scan could not run (the user closing the scanner is not one).
enum QrScanFailure { permissionDenied, permissionPermanentlyDenied, noCamera, camera }

/// Platform QR scanning: native CameraX + ZXing on Android.
///
/// ZXing needs no Google Play Services, so this works on de-Googled /
/// microG ROMs (ML Kit did not).
abstract final class QrScannerService {
  static const _channel = MethodChannel('org.gator.gator/qr');

  static bool get isSupported => Platform.isAndroid;

  /// Opens the camera scanner. Returns the decoded text, or null if the user
  /// closed it. Throws [QrScanException] when the camera cannot be used.
  static Future<String?> scanCamera() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('scanQrCode');
    } on PlatformException catch (e) {
      throw QrScanException(failureFromCode(e.code), e.message);
    } on MissingPluginException {
      throw const QrScanException(QrScanFailure.camera, 'Scanner unavailable');
    }
  }

  /// Decodes a QR code from an image file; null if none was found.
  static Future<String?> decodeImage(String path) async {
    if (!isSupported) return null;
    return _channel.invokeMethod<String>('decodeQrImage', {'path': path});
  }

  /// Opens this app's system settings page (to grant camera permission).
  static Future<bool> openAppSettings() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static QrScanFailure failureFromCode(String code) => switch (code) {
        'PERMISSION' => QrScanFailure.permissionDenied,
        'PERMISSION_PERMANENT' => QrScanFailure.permissionPermanentlyDenied,
        'NO_CAMERA' => QrScanFailure.noCamera,
        _ => QrScanFailure.camera,
      };

  /// User-facing text for [failure].
  static String messageFor(QrScanFailure failure) => switch (failure) {
        QrScanFailure.permissionDenied =>
          'Camera permission is required to scan QR codes.',
        QrScanFailure.permissionPermanentlyDenied =>
          'Camera access is turned off for Gator. Allow it in Settings to scan QR codes.',
        QrScanFailure.noCamera => 'No camera found on this device.',
        QrScanFailure.camera =>
          'Could not open the camera. Type the code, or use “Scan QR from Image”.',
      };
}

class QrScanException implements Exception {
  const QrScanException(this.failure, [this.detail]);

  final QrScanFailure failure;
  final String? detail;

  String get message => QrScannerService.messageFor(failure);

  @override
  String toString() => 'QrScanException($failure, $detail)';
}
