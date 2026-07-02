import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gator/core/theme/gator_theme.dart';

void main() {
  group('GatorTheme', () {
    test('light() uses Material 3 and expected primary color', () {
      final theme = GatorTheme.light();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, const Color(0xFF3584E4));
    });

    test('dark() uses Material 3 and expected primary color', () {
      final theme = GatorTheme.dark();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, const Color(0xFF78AEED));
    });
  });

  group('debug banner', () {
    testWidgets('MaterialApp with debugShowCheckedModeBanner false shows no Banner',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<String>(
                  itemBuilder: (context) => const [],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Banner), findsNothing);
    });
  });
}