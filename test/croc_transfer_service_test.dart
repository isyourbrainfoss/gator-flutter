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

    test('relay password is never on argv', () {
      final args = buildSendArgs(
        settings: GatorSettings.defaults().copyWith(pass: 's3cr3t'),
        files: ['/tmp/a.txt'],
        excluded: [],
        text: '',
      );
      expect(args, isNot(contains('--pass')));
      expect(args, isNot(contains('s3cr3t')));
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
    test('single-quotes every arg and never inlines env', () {
      final cmd = CrocTransferService.buildShellCommand([
        'croc',
        "a b'c",
        'send',
      ]);
      expect(cmd, "'croc' 'a b'\\''c' 'send'");
      expect(cmd, isNot(contains('CROC_SECRET')));
    });

    test(
      'secrets reach the child via the environment, not the command line',
      () async {
        const secret = "7342-it's \$HOME `x`";
        final cmd = CrocTransferService.buildShellCommand([
          'sh',
          '-c',
          r'printf %s "$CROC_SECRET"',
        ]);
        expect(cmd, isNot(contains('7342')));
        final r = await Process.run(
          'sh',
          ['-c', cmd],
          environment: {'CROC_SECRET': secret},
        );
        expect(r.exitCode, 0, reason: '${r.stderr}');
        expect(r.stdout, secret);
      },
      testOn: 'linux || mac-os',
    );
  });
}
