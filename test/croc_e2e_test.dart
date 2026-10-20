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

  test(
    'multi-line text with status-lookalike lines and a relay password; '
    'no secret on any command line',
    () async {
      final tmp = await Directory.systemTemp.createTemp('gator-e2e-');
      addTearDown(() => tmp.delete(recursive: true));
      // croc derives the relay room from the leading digits; use a prefix the
      // other tests (7342-…) don't share so a cancelled run can't collide.
      final code = '6158-gator-lines-${DateTime.now().millisecondsSinceEpoch}';
      const text = '50% off | today\nwaiting for you\n\nsending love';
      // The default public relay password works against `croc relay` too.
      final base = GatorSettings.defaults().copyWith(
        relay: relay,
        pass: 'pass123',
      );
      final sender = CrocTransferService(crocPath: croc!);
      final receiver = CrocTransferService(crocPath: croc);
      final leaks = <String>[];
      final sniff = Timer.periodic(const Duration(milliseconds: 100), (_) {
        for (final e in Directory('/proc').listSync()) {
          try {
            final cmd = File('${e.path}/cmdline').readAsStringSync();
            if (cmd.contains(code) || cmd.contains('pass123')) leaks.add(cmd);
          } catch (_) {}
        }
      });
      addTearDown(sniff.cancel);
      final sendDone = run(
        sender,
        () => sender.startSend(
          settings: base.copyWith(defaultCode: code),
          files: const [],
          excluded: const [],
          text: text,
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
      final sendEvents = await sendDone;
      sniff.cancel();
      expect(recvEvents.whereType<CrocFinishedEvent>().single.exitCode, 0);
      expect(recvEvents.whereType<CrocTextReceivedEvent>().map((e) => e.text), [
        text,
      ]);
      expect(leaks, isEmpty, reason: 'secret visible in /proc/*/cmdline');
      final logs = [
        ...sendEvents,
        ...recvEvents,
      ].whereType<CrocLogEvent>().map((e) => e.message);
      expect(logs.where((l) => l.contains('pass123')), isEmpty);
    },
    skip: skip ?? (Platform.isLinux ? null : '/proc sniff is Linux-only'),
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
