import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gator/features/receive/receive_page.dart';
import 'package:gator/features/send/send_page.dart';
import 'package:gator/features/shell/gator_shell.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/services/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = await SettingsRepository.create();
  });

  group('SendPage smoke', () {
    testWidgets('renders add button and start transfer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: Scaffold(body: SendPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Start Transfer'), findsOneWidget);
      expect(find.text('No files or folders selected'), findsOneWidget);
    });

    testWidgets('does not overflow on a narrow viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(200, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: Scaffold(body: SendPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });
  });

  group('ReceivePage smoke', () {
    testWidgets('renders code field and receive actions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: Scaffold(body: ReceivePage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transfer code'), findsOneWidget);
      expect(find.text('Paste from Clipboard'), findsOneWidget);
      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.text('Start Receiving'), findsOneWidget);
    });
  });

  group('GatorShell smoke', () {
    testWidgets('renders menu without debug banner', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: GatorShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Banner), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });
}