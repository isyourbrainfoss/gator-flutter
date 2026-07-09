import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gator/features/receive/receive_notifier.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/providers/transfer_providers.dart';
import 'package:gator/services/croc_transfer_service.dart';

/// Wires [ReceiveNotifier] to [CrocTransferService].
/// Controllers own the service + subscription but are UI-agnostic (no BuildContext).
/// Side effects like dialogs are driven from pages via ref.listen on notifier state.
class ReceiveController {
  ReceiveController(this.ref);

  final Ref ref;
  CrocTransferService? _service;
  StreamSubscription<CrocEvent>? _sub;

  Future<void> startTransfer() async {
    final notifier = ref.read(receiveProvider.notifier);
    final state = ref.read(receiveProvider);
    if (!state.canStart) return;

    _service = await createTransferService(ref);
    if (_service == null) return;

    final settings = ref.read(settingsProvider).value ?? GatorSettings.defaults();
    final filesBefore = await snapshotDir(state.saveDir);
    notifier.startTransfer();

    _sub = _service!.events.listen((event) {
      switch (event) {
        case CrocLogEvent(:final message):
          notifier.appendLog(message);
        case CrocProgressEvent(:final fraction):
          notifier.setProgress(fraction, ref.read(receiveProvider).phase);
        case CrocStatusEvent(:final phase):
          notifier.setProgress(
            ref.read(receiveProvider).progress,
            phaseFromString(phase),
          );
        case CrocTextReceivedEvent(:final text):
          notifier.onTextReceived(text);
        case CrocTransferCompleteEvent():
          notifier.onTransferComplete();
        case CrocFinishedEvent(:final exitCode):
          notifier.finishTransfer(
            canceled: _service!.canceled,
            exitCode: exitCode,
          );
          _cleanup();
        default:
          break;
      }
    });

    await _service!.startReceive(
      settings: settings,
      code: state.code,
      saveDir: state.saveDir,
      filesBefore: filesBefore,
    );
  }

  Future<void> cancelTransfer() async {
    await _service?.cancel();
    ref.read(receiveProvider.notifier).finishTransfer(canceled: true);
    _cleanup();
  }

  void _cleanup() {
    _sub?.cancel();
    _sub = null;
    _service?.dispose();
    _service = null;
  }

  /// Called via Riverpod ref.onDispose for proper lifecycle.
  void dispose() {
    _cleanup();
  }
}

final receiveControllerProvider = Provider.autoDispose<ReceiveController>(
  (ref) {
    final controller = ReceiveController(ref);
    ref.onDispose(controller.dispose);
    return controller;
  },
);