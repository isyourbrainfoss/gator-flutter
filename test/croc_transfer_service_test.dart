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

    test('includes files and code', () {
      final args = buildSendArgs(
        settings: GatorSettings.fromMap({'default_code': 'mycode', 'git': true}),
        files: ['/tmp/a.txt', '/tmp/b'],
        excluded: ['/tmp/ignore'],
        text: '',
      );
      expect(args, contains('send'));
      expect(args, contains('--code'));
      expect(args, contains('mycode'));
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
}