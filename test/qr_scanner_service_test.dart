import 'package:flutter_test/flutter_test.dart';
import 'package:gator/services/qr_scanner_service.dart';

void main() {
  test('native scanner error codes map to user-facing failures', () {
    expect(QrScannerService.failureFromCode('PERMISSION'),
        QrScanFailure.permissionDenied);
    expect(QrScannerService.failureFromCode('PERMISSION_PERMANENT'),
        QrScanFailure.permissionPermanentlyDenied);
    expect(QrScannerService.failureFromCode('NO_CAMERA'),
        QrScanFailure.noCamera);
    expect(QrScannerService.failureFromCode('CAMERA'), QrScanFailure.camera);
    expect(QrScannerService.failureFromCode('DESTROYED'), QrScanFailure.camera);
  });

  test('every failure has a message (never a silent no-op)', () {
    for (final f in QrScanFailure.values) {
      expect(QrScannerService.messageFor(f), isNotEmpty);
    }
    expect(
      QrScannerService.messageFor(QrScanFailure.permissionPermanentlyDenied),
      contains('Settings'),
    );
  });
}
