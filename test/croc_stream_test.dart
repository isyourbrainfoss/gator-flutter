@Tags(['integration'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/services/croc_transfer_service.dart';

/// Integration test: requires croc on PATH and network access.
void main() {
  test('CrocTransferService captures send code from stderr', () async {
    final testFile = File('/tmp/gator-stream-test.txt');
    await testFile.writeAsString('hello gator stream test');

    final codes = <String>[];
    final codeSeen = Completer<void>();
    final service = CrocTransferService(crocPath: '/usr/bin/croc');
    final sub = service.events.listen((event) {
      if (event is CrocCodeEvent) {
        codes.add(event.code);
        if (!codeSeen.isCompleted) codeSeen.complete();
      }
    });

    unawaited(
      service.startSend(
        settings: GatorSettings.defaults(),
        files: [testFile.path],
        excluded: const [],
        text: '',
      ),
    );

    await codeSeen.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
    await service.cancel();
    await sub.cancel();

    expect(
      codes,
      isNotEmpty,
      reason: 'croc send should emit a code event within 5 seconds',
    );
  }, skip: 'Manual check: dart run tool/debug_croc_send.dart');
}