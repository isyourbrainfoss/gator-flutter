import 'package:flutter_test/flutter_test.dart';
import 'package:gator/core/constants.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/services/croc_parser.dart';

void main() {
  group('parseProgressFraction', () {
    test('parses progress lines', () {
      expect(parseProgressFraction('Sending  45%'), 0.45);
      expect(
        parseProgressFraction(
          'download.zip  20% |████                | (1.7/8.3 GB, 117 MB/s)',
        ),
        0.20,
      );
      expect(parseProgressFraction('Hashing download.zip  99%'), 0.99);
      expect(parseProgressFraction('no progress here'), isNull);
    });
  });

  group('splitCrocOutput', () {
    test('handles carriage returns', () {
      const chunk = 'download.zip  10% |██\rdownload.zip  20% |████\r';
      final (buf, segments) = splitCrocOutput(chunk);
      expect(buf, '');
      expect(segments.map((s) => s.$1).toList(), [
        'download.zip  10% |██',
        'download.zip  20% |████',
      ]);
      expect(segments.every((s) => !s.$2), isTrue);
    });

    test('handles mixed newlines and carriage returns', () {
      const chunk =
          'Code is: abc\nSending (->127.0.0.1:1)\ndownload.zip  5% |█\r';
      final (buf, segments) = splitCrocOutput(chunk);
      expect(buf, '');
      expect(segments, [
        ('Code is: abc', true),
        ('Sending (->127.0.0.1:1)', true),
        ('download.zip  5% |█', false),
      ]);
    });

    test('preserves partial line', () {
      final (buf, segments) = splitCrocOutput('4', buffer: 'download.zip  ');
      expect(buf, 'download.zip  4');
      expect(segments, isEmpty);
    });
  });

  group('buildGlobalArgs', () {
    test('basic defaults omit flags', () {
      // defaults() has yes=true (so includes --yes), but omits empty/zero/falsy optionals
      final args = buildGlobalArgs(GatorSettings.defaults());
      expect(args, contains('--yes'));
      expect(args, isNot(contains('--relay')));
      expect(args, isNot(contains('--multicast')));
      expect(args, isNot(contains('--curve')));
      expect(args, isNot(contains('--debug')));
    });

    test('omits empty relay', () {
      final args = buildGlobalArgs(GatorSettings.defaults());
      expect(args, isNot(contains('--relay')));
      expect(args, isNot(contains('--relay6')));
    });

    test('includes overrides', () {
      final args = buildGlobalArgs(
        GatorSettings.fromMap({
          'yes': true,
          'overwrite': true,
          'debug': true,
          'relay': '1.2.3.4:9009',
          'pass': 's3cr3t',
          'port': 9999,
        }),
      );
      expect(args, contains('--yes'));
      expect(args, contains('--overwrite'));
      expect(args, contains('--debug'));
      expect(args, contains('--relay'));
      expect(args, contains('1.2.3.4:9009'));
      expect(args, contains('--pass'));
      expect(args, contains('s3cr3t'));
      expect(args, isNot(contains('--port')));
    });
  });

  group('extractCrocCodeFromLine', () {
    test('extracts code from stderr-style line', () {
      expect(
        extractCrocCodeFromLine('Code is: 5015-lucas-valid-balance'),
        '5015-lucas-valid-balance',
      );
      expect(
        extractCrocCodeFromLine('  code is: 1234-lion-stop-sofia  '),
        '1234-lion-stop-sofia',
      );
    });
  });

  group('normalizeCrocCode', () {
    test('normalizes codes', () {
      expect(normalizeCrocCode('1234-lion-stop-sofia'), '1234-lion-stop-sofia');
      expect(
        normalizeCrocCode('Code is: 1234-lion-stop-sofia'),
        '1234-lion-stop-sofia',
      );
      expect(normalizeCrocCode('1234 lion stop sofia'), '1234-lion-stop-sofia');
    });
  });

  group('detectTransferPhase', () {
    test('detects phases', () {
      expect(detectTransferPhase('Hashing download.zip  45%'), 'hashing');
      expect(detectTransferPhase('download.zip  20% |██'), 'sending');
      expect(detectTransferPhase('Receiving file (foo)  50%'), 'receiving');
      expect(detectTransferPhase('Code is: abc'), isNull);
    });
  });

  group('buildReceiveArgs', () {
    test('respects yes pref false', () {
      final args = buildReceiveArgs(
        GatorSettings.fromMap({'yes': false, 'relay': ''}),
      );
      expect(args.first, crocBinary);
      expect(args, isNot(contains('--relay')));
      expect(args, isNot(contains('--yes')));
      expect(args.length, 1);
    });

    test('includes yes when enabled', () {
      final args = buildReceiveArgs(GatorSettings.fromMap({'yes': true}));
      expect(args, contains('--yes'));
      expect(args, isNot(contains('abc-code')));
    });
  });

  group('receiveEnvForCode', () {
    test('sets CROC_SECRET', () {
      expect(
        receiveEnvForCode('Code is: 1234 test code'),
        {'CROC_SECRET': '1234-test-code'},
      );
    });
  });

  group('isCrocStatusLine', () {
    test('filters CLI output', () {
      expect(isCrocStatusLine('connecting...'), isTrue);
      expect(isCrocStatusLine('securing channel...'), isTrue);
      expect(
        isCrocStatusLine("Accept 'wg0.conf_ivpn' (303 B)? (Y/n)"),
        isTrue,
      );
      expect(isCrocStatusLine('Receiving (<-83.109.115.4:35166)'), isTrue);
      expect(
        isCrocStatusLine(
          'On UNIX systems, to receive with croc you either need',
        ),
        isTrue,
      );
      expect(isCrocStatusLine('hello from sender'), isFalse);
      expect(isCrocStatusLine('Line one of a note'), isFalse);
    });
  });

  group('extractFileName', () {
    test('extracts filename from croc lines', () {
      expect(
        extractFileName('Receiving file (document.pdf)  45%'),
        'document.pdf',
      );
      expect(
        extractFileName('Sending file (photo.jpg) ...'),
        'photo.jpg',
      );
      expect(extractFileName('some other log line'), isNull);
      expect(extractFileName('Receiving file (file-with-dashes.txt)'), 'file-with-dashes.txt');
    });
  });
}