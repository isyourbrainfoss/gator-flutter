import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gator/features/dialogs/received_text_dialog.dart';
import 'package:gator/features/dialogs/transfer_complete_dialog.dart';
import 'package:gator/features/receive/receive_notifier.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/providers/transfer_providers.dart';
import 'package:gator/services/croc_transfer_service.dart';
import 'package:gator/services/folder_opener.dart';

/// Wires [ReceiveNotifier] to [CrocTransferService].
class ReceiveController {
  ReceiveController(this.ref);

  final Ref ref;
  CrocTransferService? _service;
  StreamSubscription<CrocEvent>? _sub;

  Future<void> startTransfer(BuildContext context) async {
    final notifier = ref.read(receiveProvider.notifier);
    final state = ref.read(receiveProvider);
    if (!state.canStart) return;

    _service = await createTransferService(ref);
    if (_service == null) return;

    final settings = ref.read(settingsProvider).value ?? {};
    final filesBefore = await snapshotDir(state.saveDir);
    notifier.startTransfer();

    _sub = _service!.events.listen((event) async {
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
          if (context.mounted) {
            await showReceivedTextDialog(context, text);
          }
        case CrocTransferCompleteEvent():
          if (context.mounted) {
            final open = await showTransferCompleteDialog(context);
            if (open && context.mounted) {
              await FolderOpener.open(state.saveDir);
            }
          }
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
}

final receiveControllerProvider = Provider<ReceiveController>(
  (ref) => ReceiveController(ref),
);