import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR helpers (black-on-white per GTK theme.py convention).
abstract final class QrService {
  static QrImageView codeWidget(String code, {double size = 256}) {
    return QrImageView(
      data: code,
      size: size,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
  }
}