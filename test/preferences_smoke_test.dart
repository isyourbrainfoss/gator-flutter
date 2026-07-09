import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gator/features/preferences/preferences_page.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/services/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = await SettingsRepository.create();
  });

  group('PreferencesPage smoke', () {
    testWidgets('renders GTK-parity section headers and key settings',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 5000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: PreferencesPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Basic sections and settings always visible
      expect(find.text('General Options'), findsOneWidget);
      expect(find.text('Sending Options'), findsOneWidget);
      expect(find.text('Debug mode'), findsOneWidget);
      expect(find.text('Zip folder before sending'), findsOneWidget);
      expect(find.text('Automatically accept incoming transfers'),
          findsOneWidget);

      // Advanced toggle present (off by default, hides complexity)
      expect(find.text('Show advanced options'), findsOneWidget);
      expect(find.text('Relay and Proxy'), findsNothing);
      expect(find.text('SOCKS5 proxy'), findsNothing);

      // Toggle on to reveal advanced sections/options
      await tester.tap(find.text('Show advanced options'));
      await tester.pumpAndSettle();

      expect(find.text('Relay and Proxy'), findsOneWidget);
      expect(find.text('SOCKS5 proxy'), findsOneWidget);
      expect(find.text('HTTP proxy'), findsOneWidget);
    });
  });
}