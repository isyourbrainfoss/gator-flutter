import 'dart:async';
import 'dart:io';

import 'package:gator/models/transfer_state.dart';
import 'package:gator/services/croc_transfer_service.dart';

Future<void> main() async {
  final f = File('/tmp/gator-debug.txt')..writeAsStringSync('debug');
  final service = CrocTransferService(crocPath: '/usr/bin/croc');
  final codeSeen = Completer<void>();
  final sub = service.events.listen((e) {
    switch (e) {
      case CrocLogEvent(:final message):
        print('LOG: $message');
      case CrocCodeEvent(:final code):
        print('CODE: $code');
        if (!codeSeen.isCompleted) codeSeen.complete();
      default:
        print('EVENT: $e');
    }
  });

  unawaited(
    service.startSend(
      settings: {'yes': true},
      files: [f.path],
      excluded: [],
      text: '',
    ),
  );

  await codeSeen.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () => print('TIMEOUT: no code within 10s'),
  );
  await service.cancel();
  await service.dispose();
  await sub.cancel();
}