import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/features/send/send_notifier.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/providers/transfer_providers.dart';
import 'package:gator/services/croc_transfer_service.dart';

/// Wires [SendNotifier] to [CrocTransferService].
/// Controllers own the service + subscription but are UI-agnostic.
/// Side effects (snacks, etc.) are driven from pages via ref.listen.
class SendController {
  SendController(this.ref);

  final Ref ref;
  CrocTransferService? _service;
  StreamSubscription<CrocEvent>? _sub;

  Future<void> startTransfer() async {
    final notifier = ref.read(sendProvider.notifier);
    final state = ref.read(sendProvider);
    if (!state.canStart) return;

    _service = await createTransferService(ref);
    if (_service == null) {
      notifier.setError(
        'croc is not available — install croc or check PATH',
      );
      return;
    }

    final settings = ref.read(settingsProvider).value ?? GatorSettings.defaults();
    notifier.startTransfer();

    _sub = _service!.events.listen((event) {
      switch (event) {
        case CrocLogEvent(:final message):
          notifier.appendLog(message);
        case CrocCodeEvent(:final code):
          notifier.setCode(code);
        case CrocProgressEvent(:final fraction):
          notifier.setProgress(fraction, ref.read(sendProvider).phase);
        case CrocStatusEvent(:final phase):
          notifier.setProgress(
            ref.read(sendProvider).progress,
            phaseFromString(phase),
          );
        case CrocFinishedEvent(:final exitCode):
          final canceled = _service!.canceled;
          notifier.finishTransfer(canceled: canceled);
          if (!canceled &&
              exitCode != 0 &&
              ref.read(sendProvider).code.isEmpty) {
            notifier.setError(
              'Transfer failed (exit $exitCode). '
              'See shell output below for details.',
            );
          }
          _cleanup();
        default:
          break;
      }
    });

    try {
      await _service!.startSend(
        settings: settings,
        files: state.selectedFiles,
        excluded: state.excludedPaths,
        text: state.sendText,
      );
    } catch (e) {
      notifier.setError('Failed to start croc: $e');
      notifier.finishTransfer(canceled: true);
      _cleanup();
    }
  }

  Future<void> cancelTransfer() async {
    await _service?.cancel();
    ref.read(sendProvider.notifier).finishTransfer(canceled: true);
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

final sendControllerProvider = Provider.autoDispose<SendController>(
  (ref) {
    final controller = SendController(ref);
    ref.onDispose(controller.dispose);
    return controller;
  },
);