import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/features/send/send_notifier.dart';
import 'package:gator/models/transfer_state.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('canStart is false when empty, excluded-only, or already sent', () {
    final notifier = container.read(sendProvider.notifier);
    expect(container.read(sendProvider).canStart, isFalse);
    notifier.addFiles(['/tmp/a'], exclude: true);
    expect(container.read(sendProvider).canStart, isFalse);
    notifier.addFiles(['/tmp/b']);
    expect(container.read(sendProvider).canStart, isTrue);
    notifier.setText('hello');
    expect(container.read(sendProvider).canStart, isTrue);
  });

  test('addFiles dedupes; excluded paths stay out of selectedFiles', () {
    final notifier = container.read(sendProvider.notifier);
    notifier.addFiles(['/tmp/a', '/tmp/a']);
    notifier.addFiles(['/tmp/a']);
    notifier.addFiles(['/tmp/skip'], exclude: true);
    final state = container.read(sendProvider);
    expect(state.items.length, 2);
    expect(state.selectedFiles, ['/tmp/a']);
    expect(state.excludedPaths, ['/tmp/skip']);
  });

  test('appendLog trims to kMaxLogLines', () {
    final notifier = container.read(sendProvider.notifier);
    for (var i = 0; i < kMaxLogLines + 10; i++) {
      notifier.appendLog('line $i');
    }
    expect(container.read(sendProvider).log, hasLength(kMaxLogLines));
    expect(container.read(sendProvider).log.first, 'line 10');
  });

  test('startTransfer then setCurrentFile then start again clears currentFile', () {
    final notifier = container.read(sendProvider.notifier);
    notifier.startTransfer();
    notifier.applyProgress(currentFile: 'photo.jpg');
    expect(container.read(sendProvider).currentFile, 'photo.jpg');
    notifier.startTransfer();
    expect(container.read(sendProvider).currentFile, isNull);
    expect(container.read(sendProvider).errorMessage, isEmpty);
  });

  test('finishTransfer canceled marks error and does not mark items sent', () {
    final notifier = container.read(sendProvider.notifier);
    notifier.addFiles(['/tmp/a']);
    notifier.startTransfer();
    notifier.finishTransfer(canceled: true, exitCode: -1);
    final state = container.read(sendProvider);
    expect(state.phase, TransferPhase.error);
    expect(state.complete, isFalse);
    expect(state.items.single.sent, isFalse);
  });

  test('finishTransfer non-zero exit is error not complete', () {
    final notifier = container.read(sendProvider.notifier);
    notifier.addFiles(['/tmp/a']);
    notifier.startTransfer();
    notifier.setCode('abc');
    notifier.finishTransfer(canceled: false, exitCode: 1);
    final state = container.read(sendProvider);
    expect(state.complete, isFalse);
    expect(state.phase, TransferPhase.error);
    expect(state.items.single.sent, isFalse);
  });

  test('resetTransferUi restores Start without clearing the queue', () {
    final notifier = container.read(sendProvider.notifier);
    notifier.addFiles(['/tmp/a']);
    notifier.startTransfer();
    notifier.finishTransfer(canceled: false, exitCode: 0);
    expect(container.read(sendProvider).complete, isTrue);
    notifier.resetTransferUi();
    final state = container.read(sendProvider);
    expect(state.complete, isFalse);
    expect(state.canStart, isTrue);
    expect(state.items.single.path, '/tmp/a');
  });
}
