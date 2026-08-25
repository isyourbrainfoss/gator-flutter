import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR helpers (black-on-white per GTK theme.py convention).
abstract final class QrService {
  static Widget codeWidget(String code, {double size = 256}) {
    return Semantics(
      label: 'QR code for transfer code $code',
      image: true,
      child: QrImageView(
        key: ValueKey(code),
        data: code,
        size: size,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
  }
}
