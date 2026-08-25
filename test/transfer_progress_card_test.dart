import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gator/models/transfer_state.dart';
import 'package:gator/widgets/transfer_progress_card.dart';

void main() {
  testWidgets('shows hashing file name and percent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransferProgressCard(
            progress: 0.45,
            phase: TransferPhase.hashing,
            currentFile: 'photo.jpg',
          ),
        ),
      ),
    );
    expect(find.text('Preparing files'), findsOneWidget);
    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
  });

  testWidgets('shows speed and eta', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransferProgressCard(
            progress: 0.2,
            phase: TransferPhase.sending,
            speed: '117 MB/s',
            eta: '1m',
          ),
        ),
      ),
    );
    expect(find.textContaining('117 MB/s'), findsOneWidget);
    expect(find.textContaining('1m'), findsOneWidget);
  });

  testWidgets('receive phase is Receiving not Sending', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransferProgressCard(
            progress: 0.64,
            phase: TransferPhase.receiving,
            currentFile: 'file.tar',
            speed: '8.5 MB/s',
          ),
        ),
      ),
    );
    expect(find.text('Receiving'), findsOneWidget);
    expect(find.text('Sending'), findsNothing);
  });

  testWidgets('error phase uses Error label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransferProgressCard(
            progress: 0,
            phase: TransferPhase.error,
            errorMessage: 'That transfer code is invalid or expired.',
          ),
        ),
      ),
    );
    expect(find.text('Error'), findsOneWidget);
    expect(find.textContaining('invalid or expired'), findsOneWidget);
  });
}
