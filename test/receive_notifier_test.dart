import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/features/receive/receive_notifier.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/services/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final repo = await SettingsRepository.create();
    container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);
  });

  test('pasteCode normalizes Code is: 1234 lion stop', () {
    final notifier = container.read(receiveProvider.notifier);
    notifier.pasteCode('Code is: 1234 lion stop');
    expect(container.read(receiveProvider).code, '1234-lion-stop');
  });

  test('canStart requires code and saveDir and not transferring', () {
    final notifier = container.read(receiveProvider.notifier);
    expect(container.read(receiveProvider).canStart, isFalse);
    notifier.setCode('abc');
    notifier.changeFolder('/tmp');
    expect(container.read(receiveProvider).canStart, isTrue);
    notifier.startTransfer();
    expect(container.read(receiveProvider).canStart, isFalse);
  });

  test('onTextReceived then clearReceivedText leaves receivedText null', () {
    final notifier = container.read(receiveProvider.notifier);
    notifier.onTextReceived('hello');
    expect(container.read(receiveProvider).receivedText, 'hello');
    notifier.clearReceivedText();
    expect(container.read(receiveProvider).receivedText, isNull);
  });

  test('onTransferComplete then clearPendingCompleteDialog', () {
    final notifier = container.read(receiveProvider.notifier);
    notifier.onTransferComplete();
    expect(container.read(receiveProvider).pendingCompleteDialog, isTrue);
    notifier.clearPendingCompleteDialog();
    expect(container.read(receiveProvider).pendingCompleteDialog, isFalse);
  });

  test('appendLog trims to kMaxLogLines', () {
    final notifier = container.read(receiveProvider.notifier);
    for (var i = 0; i < kMaxLogLines + 5; i++) {
      notifier.appendLog('$i');
    }
    expect(container.read(receiveProvider).log, hasLength(kMaxLogLines));
  });

  test('finishTransfer failed is error not complete', () {
    final notifier = container.read(receiveProvider.notifier);
    notifier.startTransfer();
    notifier.finishTransfer(canceled: false, exitCode: 2);
    final state = container.read(receiveProvider);
    expect(state.complete, isFalse);
    expect(state.phase, TransferPhase.error);
  });
}
