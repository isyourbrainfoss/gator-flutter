import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/services/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('gatorDefaults', () {
    test('defaults present', () {
      expect(gatorDefaults['port'], defaultPort);
      expect(gatorDefaults['transfers'], defaultTransfers);
      expect(gatorDefaults['multicast'], defaultMulticast);
      expect(gatorDefaults['hash'], defaultHash);
      expect(gatorDefaults['curve'], defaultCurve);
      expect(gatorDefaults['color_scheme'], 'default');
    });
  });

  group('validateSettings', () {
    test('clamps port', () {
      expect(validateSettings({'port': 999999})['port'], 65535);
      expect(validateSettings({'port': 0})['port'], 0);
    });

    test('validates hash', () {
      expect(validateSettings({'hash': 'foo'})['hash'], defaultHash);
      expect(validateSettings({'hash': ''})['hash'], '');
      expect(validateSettings({'hash': 'imohash'})['hash'], 'imohash');
      expect(validateSettings({'hash': 'highway'})['hash'], 'highway');
    });
  });

  group('mergeWithDefaults', () {
    test('merges user overrides and ignores unknown keys', () {
      final merged = mergeWithDefaults({'port': 1234, 'foo': 'bar'});
      expect(merged['port'], 1234);
      expect(merged['color_scheme'], 'default');
      expect(merged.containsKey('foo'), isFalse);
    });
  });

  group('SettingsRepository', () {
    test('load save roundtrip', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await SettingsRepository.create();
      await repo.save(GatorSettings.fromMap({'port': 4321, 'debug': true}));
      final loaded = repo.load();
      expect(loaded.port, 4321);
      expect(loaded.debug, isTrue);
    });
  });

  group('getDefaultSaveDirLabel', () {
    test('returns non-empty string', () {
      expect(getDefaultSaveDirLabel(), isNotEmpty);
    });
  });

  group('migrateStaleSettings', () {
    test('clears legacy relays only', () {
      final migrated = migrateStaleSettings({
        'relay': legacyRelay,
        'relay6': legacyRelay6,
        'hash': 'xxhash',
      });
      expect(migrated['relay'], '');
      expect(migrated['relay6'], '');
      expect(migrated['hash'], 'xxhash');
    });
  });

  group('toDiffMap', () {
    test('includes show_advanced_settings when true', () {
      final diff = GatorSettings.fromMap({'show_advanced_settings': true})
          .toDiffMap();
      expect(diff['show_advanced_settings'], isTrue);
      expect(diff.containsKey('yes'), isFalse);
    });
  });
}