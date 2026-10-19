// Opt-in end-to-end transfer through a real croc relay.
//
//   croc relay --ports 9109,9110,9111,9112,9113 &
//   GATOR_E2E_RELAY=127.0.0.1:9109 flutter test test/croc_e2e_test.dart
@TestOn('linux || mac-os')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/services/croc_transfer_service.dart';

String? _which(String name) {
  for (final dir in (Platform.environment['PATH'] ?? '').split(':')) {
    if (dir.isEmpty) continue;
    final f = File('$dir/$name');
    if (f.existsSync()) return f.path;
  }
  return null;
}

void main() {
  final relay = Platform.environment['GATOR_E2E_RELAY'] ?? '';
  final croc = _which('croc');
  final skip = relay.isEmpty || croc == null
      ? 'set GATOR_E2E_RELAY and put croc on PATH'
      : null;

  Future<List<CrocEvent>> run(
    CrocTransferService service,
    Future<void> Function() start,
  ) async {
    final events = <CrocEvent>[];
    final sub = service.events.listen(events.add);
    await start().timeout(const Duration(seconds: 60));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    if (Platform.environment['GATOR_E2E_VERBOSE'] == '1') {
      for (final e in events.whereType<CrocLogEvent>()) {
        // ignore: avoid_print
        print('[croc] ${e.message}');
      }
    }
    return events;
  }

  test('send with a custom code, receive files', () async {
    final tmp = await Directory.systemTemp.createTemp('gator-e2e-');
    addTearDown(() => tmp.delete(recursive: true));
    final src = File('${tmp.path}/payload.bin')
      ..writeAsBytesSync(List.generate(200000, (i) => i % 251));
    final out = Directory('${tmp.path}/out')..createSync();
    final code = '7342-gator-e2e-${DateTime.now().millisecondsSinceEpoch}';
    final base = GatorSettings.defaults().copyWith(relay: relay);

    final sender = CrocTransferService(crocPath: croc!);
    final receiver = CrocTransferService(crocPath: croc);
    final sendDone = run(
      sender,
      () => sender.startSend(
        settings: base.copyWith(defaultCode: code),
        files: [src.path],
        excluded: const [],
        text: '',
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    final recvEvents = await run(
      receiver,
      () => receiver.startReceive(
        settings: base,
        code: code,
        saveDir: out.path,
        filesBefore: const {},
      ),
    );
    final sendEvents = await sendDone;

    expect(
      sendEvents.whereType<CrocCodeEvent>().map((e) => e.code),
      everyElement(code),
    );
    expect(sendEvents.whereType<CrocFinishedEvent>().single.exitCode, 0);
    expect(recvEvents.whereType<CrocFinishedEvent>().single.exitCode, 0);
    expect(recvEvents.whereType<CrocTextReceivedEvent>(), isEmpty);
    expect(recvEvents.whereType<CrocTransferCompleteEvent>(), isNotEmpty);
    expect(
      File('${out.path}/payload.bin').readAsBytesSync(),
      src.readAsBytesSync(),
    );
  }, skip: skip, timeout: const Timeout(Duration(seconds: 90)));

  test('send text, receive text', () async {
    final tmp = await Directory.systemTemp.createTemp('gator-e2e-');
    addTearDown(() => tmp.delete(recursive: true));
    final code = '7342-gator-text-${DateTime.now().millisecondsSinceEpoch}';
    final base = GatorSettings.defaults().copyWith(relay: relay);
    final sender = CrocTransferService(crocPath: croc!);
    final receiver = CrocTransferService(crocPath: croc);
    final sendDone = run(
      sender,
      () => sender.startSend(
        settings: base.copyWith(defaultCode: code),
        files: const [],
        excluded: const [],
        text: 'Hello from gator e2e 42',
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    final recvEvents = await run(
      receiver,
      () => receiver.startReceive(
        settings: base,
        code: code,
        saveDir: tmp.path,
        filesBefore: const {},
      ),
    );
    await sendDone;
    expect(recvEvents.whereType<CrocFinishedEvent>().single.exitCode, 0);
    expect(
      recvEvents.whereType<CrocTextReceivedEvent>().map((e) => e.text),
      ['Hello from gator e2e 42'],
    );
  }, skip: skip, timeout: const Timeout(Duration(seconds: 90)));

  test('an unanswered code never reports received text', () async {
    final tmp = await Directory.systemTemp.createTemp('gator-e2e-');
    addTearDown(() => tmp.delete(recursive: true));
    final receiver = CrocTransferService(crocPath: croc!);
    // croc waits for a sender for a long time; cancel like the user would.
    Timer(const Duration(seconds: 8), receiver.cancel);
    final events = await run(
      receiver,
      () => receiver.startReceive(
        settings: GatorSettings.defaults().copyWith(relay: relay),
        code: '7342-nobody-sends-this-${DateTime.now().millisecondsSinceEpoch}',
        saveDir: tmp.path,
        filesBefore: const {},
      ),
    );
    expect(receiver.canceled, isTrue);
    expect(events.whereType<CrocTextReceivedEvent>(), isEmpty);
    expect(events.whereType<CrocTransferCompleteEvent>(), isEmpty);
  }, skip: skip);
}
