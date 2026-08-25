import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gator/core/logger.dart';
import 'package:gator/features/receive/receive_notifier.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/providers/transfer_providers.dart';
import 'package:gator/services/croc_parser.dart';
import 'package:gator/services/croc_transfer_service.dart';
import 'package:gator/services/transfer_keepalive.dart';

/// Wires [ReceiveNotifier] to [CrocTransferService].
class ReceiveController {
  ReceiveController(this.ref);

  final Ref ref;
  CrocTransferService? _service;
  StreamSubscription<CrocEvent>? _sub;
  bool _starting = false;

  Future<void> startTransfer() async {
    if (_starting || _service != null) return;
    final notifier = ref.read(receiveProvider.notifier);
    final state = ref.read(receiveProvider);
    if (!state.canStart) return;

    _starting = true;
    notifier.startTransfer();
    try {
      _service = await createTransferService(ref);
      if (_service == null) {
        notifier.setError(
          'croc is not available — install croc or check PATH',
        );
        notifier.finishTransfer(canceled: true, exitCode: 1);
        return;
      }

      final settings =
          ref.read(settingsProvider).value ?? GatorSettings.defaults();
      final filesBefore = await snapshotDir(state.saveDir);

      _sub = _service!.events.listen((event) {
        switch (event) {
          case CrocLogEvent(:final message):
            notifier.appendLog(message);
            final file = extractFileName(message);
            if (file != null) notifier.applyProgress(currentFile: file);
          case CrocProgressEvent(
              :final fraction,
              :final fileName,
              :final speed,
              :final eta,
              :final fileIndex,
              :final fileCount,
              :final hashing,
            ):
            notifier.applyProgress(
              fraction: fraction,
              phase: hashing ? TransferPhase.hashing : TransferPhase.receiving,
              currentFile: fileName,
              speed: speed,
              eta: eta,
              fileIndex: fileIndex,
              fileCount: fileCount,
            );
          case CrocStatusEvent(:final phase):
            final mapped = phaseFromString(phase);
            if (mapped != TransferPhase.idle) {
              notifier.applyProgress(phase: mapped);
            }
          case CrocTextReceivedEvent(:final text):
            notifier.onTextReceived(text);
          case CrocTransferCompleteEvent():
            notifier.onTransferComplete();
          case CrocFinishedEvent(:final exitCode):
            final canceled = _service?.canceled ?? false;
            if (!canceled && exitCode != 0) {
              notifier.setError(
                explainFromLogs(ref.read(receiveProvider).log) ??
                    'Transfer failed. Check the code, network, and try again.',
              );
            }
            notifier.finishTransfer(
              canceled: canceled,
              exitCode: exitCode,
            );
            unawaited(_cleanup());
          default:
            break;
        }
      });

      await TransferKeepalive.start();
      await _service!.startReceive(
        settings: settings,
        code: state.code,
        saveDir: state.saveDir,
        filesBefore: filesBefore,
      );
    } catch (e, st) {
      GatorLog.e('ReceiveController', 'Failed to start transfer', e, st);
      notifier.setError(
        'Could not start receiving. Check the save folder and try again.',
      );
      notifier.finishTransfer(canceled: true, exitCode: 1);
      await _cleanup();
    } finally {
      _starting = false;
    }
  }

  Future<void> cancelTransfer() async {
    await _service?.cancel();
    ref
        .read(receiveProvider.notifier)
        .finishTransfer(canceled: true, exitCode: -1);
    await _cleanup();
  }

  Future<void> _cleanup() async {
    await _sub?.cancel();
    _sub = null;
    final svc = _service;
    _service = null;
    await TransferKeepalive.stop();
    if (svc != null) {
      await svc.dispose();
    }
  }

  void dispose() {
    unawaited(_cleanup());
  }
}

final receiveControllerProvider = Provider<ReceiveController>(
  (ref) {
    final controller = ReceiveController(ref);
    ref.onDispose(controller.dispose);
    return controller;
  },
);
