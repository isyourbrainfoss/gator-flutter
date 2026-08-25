import 'package:flutter_test/flutter_test.dart';
import 'package:gator/core/constants.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/services/croc_parser.dart';

void main() {
  group('parseProgressFraction', () {
    test('parses progress lines', () {
      expect(parseProgressFraction('Sending  45%'), isNull);
      expect(
        parseProgressFraction(
          'download.zip  20% |████                | (1.7/8.3 GB, 117 MB/s)',
        ),
        0.20,
      );
      expect(parseProgressFraction('Hashing download.zip  99% |█|'), 0.99);
      expect(parseProgressFraction('no progress here'), isNull);
      expect(parseProgressFraction("Resume 'f' (12.5%)?"), isNull);
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
      final args = buildGlobalArgs(GatorSettings.defaults());
      expect(args, contains('--yes'));
      expect(args, contains('--ignore-stdin'));
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

    test('extracts code from croc 11.2.4+ send instructions', () {
      expect(
        extractCrocCodeFromLine('  croc 5015-lucas-valid-balance'),
        '5015-lucas-valid-balance',
      );
      expect(
        extractCrocCodeFromLine(
          '  croc --relay 1.2.3.4:9009 acid-pink-fostered-succeeding',
        ),
        'acid-pink-fostered-succeeding',
      );
      expect(
        extractCrocCodeFromLine('https://getcroc.com/?code=acid-pink'),
        isNull,
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
      expect(detectTransferPhase('download.zip  20% |██'), isNull);
      expect(detectTransferPhase('Receiving file (foo)  50%'), 'receiving');
      expect(detectTransferPhase('Receiving (<-127.0.0.1:1)'), 'receiving');
      expect(detectTransferPhase('Sending (->127.0.0.1:1)'), 'sending');
      expect(detectTransferPhase('Code is: abc'), 'waiting');
      expect(detectTransferPhase('Looking for sender...'), 'connecting');
      expect(detectTransferPhase('Retrying securely...'), 'retrying');
    });
  });

  group('buildReceiveArgs', () {
    test('always passes --yes and --ignore-stdin for the GUI', () {
      final args = buildReceiveArgs(
        GatorSettings.fromMap({'yes': false, 'relay': ''}),
      );
      expect(args.first, crocBinary);
      expect(args, isNot(contains('--relay')));
      expect(args, contains('--yes'));
      expect(args, contains('--ignore-stdin'));
    });

    test('includes yes when enabled', () {
      final args = buildReceiveArgs(GatorSettings.fromMap({'yes': true}));
      expect(args, contains('--yes'));
      expect(args, isNot(contains('abc-code')));
    });

    test('passes --out when provided', () {
      final args = buildReceiveArgs(
        GatorSettings.defaults(),
        out: '/tmp/gator',
      );
      expect(args, contains('--out'));
      expect(args, contains('/tmp/gator'));
    });

    test('passes --rename and omits --overwrite', () {
      final args = buildGlobalArgs(
        GatorSettings.fromMap({'rename': true, 'overwrite': true}),
      );
      expect(args, contains('--rename'));
      expect(args, isNot(contains('--overwrite')));
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
      expect(
        extractFileName(
          'download.zip  20% |████                | (1.7/8.3 GB, 117 MB/s)',
        ),
        'download.zip',
      );
    });
  });

  group('parseProgressLine', () {
    test('parses speed ETA and file index', () {
      final info = parseProgressLine(
        'file.tar  64% |████████████        | (100/153 GB, 8.5 MB/s) [2h59m57s:1h45m0s]  2/5',
      );
      expect(info, isNotNull);
      expect(info!.fraction, closeTo(0.64, 0.001));
      expect(info.fileName, 'file.tar');
      expect(info.speed, '8.5 MB/s');
      expect(info.eta, '1h45m0s');
      expect(info.fileIndex, 2);
      expect(info.fileCount, 5);
    });
  });

  group('isCrocStatusLine', () {
    test('filters v11 status lines', () {
      expect(isCrocStatusLine('Looking for sender...'), isTrue);
      expect(isCrocStatusLine('Authenticating code...'), isTrue);
      expect(isCrocStatusLine('On the other computer, run:'), isTrue);
      expect(isCrocStatusLine('hello from sender'), isFalse);
    });
  });

  group('explainCrocFailure', () {
    test('maps known phrases', () {
      expect(
        explainCrocFailure('code is invalid'),
        contains('invalid or expired'),
      );
      expect(
        explainCrocFailure('unsupported PAKE version'),
        contains('older croc'),
      );
      expect(explainCrocFailure('hello'), isNull);
    });
  });

  group('sendEnvForCode', () {
    test('sets CROC_SECRET and skips empty', () {
      expect(sendEnvForCode('gator-test-code'), {'CROC_SECRET': 'gator-test-code'});
      expect(sendEnvForCode(''), isEmpty);
    });
  });
}