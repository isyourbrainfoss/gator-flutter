import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/services/croc_parser.dart';
import 'package:gator/services/croc_transfer_service.dart';

// Captured verbatim from `croc 11.6.2` receiving `croc send --text` through a
// local relay, with stdout and stderr as separate pipes (how Android runs it).
const _pipeStdout = 'Hello from Gator\nsecond line';
const _pipeStderr =
    'connecting...\rlooking for sender...\rwaiting for sender...'
    '\rauthenticating code...\ropening transfer channels...\rwaiting for file '
    'list...    \r                        \r\rReceiving text message (28 B) \n'
    '\nReceiving (172.30.0.2<-127.0.0.1)\n\nA newer croc version is '
    'available: v11.6.3 (current: v11.6.2).\nRun: croc update\n';

// Same croc 11.6.2 receive under script(1) (Linux desktop): one CRLF stream.
const _ptyOutput =
    'connecting...\rlooking for sender...\rwaiting for sender...'
    '\rauthenticating code...\ropening transfer channels...\rwaiting for file '
    'list...    \r                        \r\rReceiving text message (31 B) '
    '\r\n\r\nReceiving (172.30.0.2<-127.0.0.1)\r\n50% off | today\r\nwaiting '
    'for you\r\nA newer croc version is available: v11.6.3 (current: '
    'v11.6.2).\r\nRun: croc update\r\n';

void main() {
  group('received text extraction (croc 11.6)', () {
    test('separate pipes: payload is stdout, status/update notice ignored', () {
      expect(
        extractReceivedTextFromStreams(
          stdout: _pipeStdout,
          stderr: _pipeStderr,
        ),
        'Hello from Gator\nsecond line',
      );
    });

    test('separate pipes: no header means file transfer', () {
      expect(
        extractReceivedTextFromStreams(
          stdout: '',
          stderr:
              'Receiving (172.30.0.2<-127.0.0.1)\n'
              'photo.jpg 100% |████████| (1.0/1.0 MB, 3 MB/s)\n',
        ),
        isNull,
      );
    });

    test('separate pipes: --debug log lines on stdout are dropped', () {
      expect(
        extractReceivedTextFromStreams(
          stdout:
              '[debug]\t12:00:00 croc.go:1: sending close-sender\n'
              'hi there',
          stderr: 'Receiving text message (8 B) \n',
        ),
        'hi there',
      );
    });

    test('PTY: exact payload sliced by byte count, status-like lines kept', () {
      expect(
        extractReceivedText(_ptyOutput),
        '50% off | today\nwaiting for you',
      );
    });

    test('text header is not a status line leaking into text', () {
      expect(isCrocStatusLine('Receiving text message (28 B) '), isTrue);
      expect(isCrocStatusLine('A newer croc version is available: v1'), isTrue);
      expect(isCrocStatusLine('Run: croc update'), isTrue);
    });

    test('"Run: croc update" is never a transfer code', () {
      expect(extractCrocCodeFromLine('Run: croc update'), isNull);
      expect(
        extractCrocCodeFromLine('  croc --relay 127.0.0.1:9109 1234-a-b-c'),
        '1234-a-b-c',
      );
    });
  });

  group('CrocTransferService receive text (Android-style pipes)', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('gator-text-');
      CrocTransferService.debugDirectSpawn = true;
    });

    tearDown(() async {
      CrocTransferService.debugDirectSpawn = false;
      await tmp.delete(recursive: true);
    });

    Future<List<CrocEvent>> receiveWith(
      String crocPath,
      String saveDir, {
      String code = '1234-fake-code',
    }) async {
      final service = CrocTransferService(crocPath: crocPath);
      final events = <CrocEvent>[];
      final sub = service.events.listen(events.add);
      await service.startReceive(
        settings: GatorSettings.defaults(),
        code: code,
        saveDir: saveDir,
        filesBefore: await Directory(
          saveDir,
        ).list().map((e) => e.path.split(Platform.pathSeparator).last).toSet(),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      return events;
    }

    test('fake croc 11.6 text receive emits CrocTextReceivedEvent', () async {
      // Mimics croc: status on stderr, then the text verbatim on stdout
      // (no trailing newline), then the update notice on stderr.
      final fake = File('${tmp.path}/croc');
      final out = Directory('${tmp.path}/out')..createSync();
      await fake.writeAsString('''#!/bin/sh
printf 'connecting...\\rwaiting for file list...    \\r\\rReceiving text message (28 B) \\n\\nReceiving (10.0.0.2<-10.0.0.1)\\n' >&2
sleep 0.2
printf 'Hello from Gator\\nsecond line'
sleep 0.2
printf '\\nA newer croc version is available: v11.6.3 (current: v11.6.2).\\nRun: croc update\\n' >&2
exit 0
''');
      await Process.run('chmod', ['+x', fake.path]);

      final events = await receiveWith(fake.path, out.path);
      final texts = events.whereType<CrocTextReceivedEvent>().toList();
      expect(texts, hasLength(1));
      expect(texts.single.text, 'Hello from Gator\nsecond line');
      expect(events.whereType<CrocTransferCompleteEvent>(), isEmpty);
      expect(events.whereType<CrocFinishedEvent>().single.exitCode, 0);
    }, skip: Platform.isWindows);

    test('failed receive output is not shown as text', () async {
      final fake = File('${tmp.path}/croc');
      final out = Directory('${tmp.path}/out')..createSync();
      await fake.writeAsString('''#!/bin/sh
printf 'connecting...\\nroom not ready\\n' >&2
exit 1
''');
      await Process.run('chmod', ['+x', fake.path]);
      final events = await receiveWith(fake.path, out.path);
      expect(events.whereType<CrocTextReceivedEvent>(), isEmpty);
      expect(events.whereType<CrocFinishedEvent>().single.exitCode, 1);
    }, skip: Platform.isWindows);

    // Opt-in: real croc + relay, e.g.
    //   croc relay --ports 9109,9110,9111,9112,9113 &
    //   GATOR_E2E_CROC=$(which croc) GATOR_E2E_RELAY=127.0.0.1:9109 \
    //     flutter test test/croc_text_receive_test.dart
    final realCroc = Platform.environment['GATOR_E2E_CROC'];
    final relay = Platform.environment['GATOR_E2E_RELAY'];
    test(
      'real croc send --text → Gator receive shows the text (pipes, as on Android)',
      () async {
        final code = '4711-gator-e2e-${DateTime.now().microsecondsSinceEpoch}';
        const message = 'Hei fra Gator!\n50% off | today\nwaiting for you';
        final sender = await Process.start(
          realCroc!,
          [
            '--relay', relay!, '--pass', 'pass123', '--ignore-stdin', //
            'send', '--text', message,
          ],
          environment: {'CROC_SECRET': code},
        );
        await sender.stdin.close();
        unawaited(sender.stdout.drain<void>());
        unawaited(sender.stderr.drain<void>());
        await Future<void>.delayed(const Duration(seconds: 2));
        final out = Directory('${tmp.path}/out')..createSync();
        final service = CrocTransferService(crocPath: realCroc);
        final events = <CrocEvent>[];
        final sub = service.events.listen(events.add);
        await service.startReceive(
          settings: GatorSettings.fromMap({'relay': relay, 'pass': 'pass123'}),
          code: code,
          saveDir: out.path,
          filesBefore: const {},
        );
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        await sender.exitCode.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            sender.kill();
            return -1;
          },
        );
        expect(events.whereType<CrocTextReceivedEvent>().single.text, message);
      },
      skip: realCroc == null || relay == null
          ? 'set GATOR_E2E_CROC and GATOR_E2E_RELAY'
          : false,
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
