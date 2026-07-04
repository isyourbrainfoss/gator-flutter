import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepare_pages_site.sh emits Obtainium-compatible version.json', () async {
    final dir = Directory.systemTemp.createTempSync('gator-version-json');
    addTearDown(() => dir.deleteSync(recursive: true));

    final apk = File('${dir.path}/fake.apk')..writeAsBytesSync(List.filled(64, 0));
    final site = '${dir.path}/site';
    final result = await Process.run(
      'bash',
      [
        'tool/prepare_pages_site.sh',
        apk.path,
        '1.5.4',
        '5',
        site,
      ],
      workingDirectory: '/home/kb/repos/grok_build/Gator-flutter',
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final json = jsonDecode(
      File('$site/version.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(json['version'], '1.5.4');
    expect(json['versionName'], '1.5.4');
    expect(json['versionCode'], 5);
    expect(json['url'], contains('gator-arm64-v8a.apk'));
    expect(json['sha256sum'], isNotEmpty);
    expect(json['uploadTimestamp'], isA<int>());
  });
}