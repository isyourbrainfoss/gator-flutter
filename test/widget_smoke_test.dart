import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gator/features/receive/receive_page.dart';
import 'package:gator/features/send/send_notifier.dart';
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
      expect(find.text('Nothing to send yet'), findsOneWidget);
      expect(
        find.textContaining('Tap Add to pick files'),
        findsOneWidget,
      );
      expect(find.text('Exclude'), findsNothing);
      expect(find.text('Clear All'), findsNothing);
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
      expect(find.byIcon(Icons.remove), findsNothing);
    });

    testWidgets('New transfer restores Start Transfer after complete',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: Scaffold(body: SendPage())),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SendPage)),
      );
      final notifier = container.read(sendProvider.notifier);
      notifier.addFiles(['/tmp/a.txt']);
      notifier.startTransfer();
      notifier.finishTransfer(canceled: false, exitCode: 0);
      await tester.pump();

      expect(find.text('New transfer'), findsOneWidget);
      await tester.tap(find.text('New transfer'));
      await tester.pump();
      expect(find.text('Start Transfer'), findsOneWidget);
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
      expect(find.text('Scan QR from Image'), findsOneWidget);
      expect(find.text('Scan QR Code'), findsNothing);
      expect(find.text('Start Receiving'), findsOneWidget);
      expect(
        find.textContaining('Ask the sender for their Gator/croc code'),
        findsOneWidget,
      );
    });
  });

  group('GatorShell smoke', () {
    testWidgets('uses a navigation rail on a wide window', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

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