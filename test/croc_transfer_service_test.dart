import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/services/croc_transfer_service.dart';

void main() {
  group('buildSendArgs', () {
    test('omits croc defaults when unset', () {
      final args = buildSendArgs(
        settings: GatorSettings.defaults(),
        files: ['/tmp/a.txt'],
        excluded: [],
        text: '',
      );
      expect(args, isNot(contains('--hash')));
      expect(args, isNot(contains('--port')));
      expect(args, isNot(contains('--transfers')));
    });

    test('includes files and does not put the secret on argv', () {
      final args = buildSendArgs(
        settings: GatorSettings.fromMap({'default_code': 'mycode', 'git': true}),
        files: ['/tmp/a.txt', '/tmp/b'],
        excluded: ['/tmp/ignore'],
        text: '',
      );
      expect(args, contains('send'));
      expect(args, isNot(contains('--code')));
      expect(args, isNot(contains('mycode')));
      expect(args, contains('--git'));
      expect(args, contains('/tmp/a.txt'));
      expect(args, contains('--exclude'));
      expect(args.any((a) => a.contains('ignore')), isTrue);
    });

    test('text mode flag', () {
      final args = buildSendArgs(
        settings: GatorSettings.defaults(),
        files: [],
        excluded: [],
        text: 'hello world',
      );
      expect(args, contains('--text'));
      expect(args, contains('hello world'));
    });
  });

  test('Linux script(1) wrapper returns the croc exit code', () {
    final args = CrocTransferService.linuxScriptArgs("'croc' 'send'");
    expect(args, containsAllInOrder(['-q', '-e', '-c', "'croc' 'send'"]));
    expect(args.last, '/dev/null');
  });

  test(
    'Linux script(1) wrapper propagates a failing exit code',
    () async {
      final script = ['/usr/bin/script', '/bin/script'].firstWhere(
        (p) => File(p).existsSync(),
        orElse: () => '',
      );
      if (script.isEmpty) {
        markTestSkipped('script(1) not installed');
        return;
      }
      final r = await Process.run(
        script,
        CrocTransferService.linuxScriptArgs('exit 3'),
      );
      expect(r.exitCode, 3);
    },
    testOn: 'linux',
  );

  group('buildShellCommand', () {
    test('keeps env names unquoted so sh treats them as assignments', () {
      final cmd = CrocTransferService.buildShellCommand(
        ['croc', 'send'],
        env: {'CROC_SECRET': "a b'c"},
      );
      expect(cmd, startsWith("CROC_SECRET='a b'\\''c' "));
      expect(cmd, isNot(contains("'CROC_SECRET'=")));
    });

    test('skips names that are not valid shell identifiers', () {
      final cmd = CrocTransferService.buildShellCommand(
        ['croc'],
        env: {'BAD-NAME': 'x', '1X': 'y', 'OK_1': 'z'},
      );
      expect(cmd, "OK_1='z' 'croc'");
    });

    test(
      'sh runs the command with the env value applied',
      () async {
        final cmd = CrocTransferService.buildShellCommand(
          ['sh', '-c', r'printf %s "$CROC_SECRET"'],
          env: {'CROC_SECRET': "7342-it's \$HOME `x`"},
        );
        final r = await Process.run('sh', ['-c', cmd]);
        expect(r.exitCode, 0, reason: '${r.stderr}');
        expect(r.stdout, "7342-it's \$HOME `x`");
      },
      testOn: 'linux || mac-os',
    );
  });
}
