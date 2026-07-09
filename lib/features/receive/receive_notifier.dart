import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/features/receive/receive_state.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/services/croc_parser.dart';

class ReceiveNotifier extends Notifier<ReceiveState> {
  @override
  ReceiveState build() {
    _loadSaveDir();
    return const ReceiveState();
  }

  Future<void> _loadSaveDir() async {
    final dir = await ref.read(settingsProvider.notifier).resolveSaveDir();
    state = state.copyWith(saveDir: dir);
  }

  void configure({required bool showShellOutput}) {
    state = state.copyWith(showShellOutput: showShellOutput);
  }

  void setCode(String code) => state = state.copyWith(code: code);

  void pasteCode(String raw) =>
      state = state.copyWith(code: normalizeCrocCode(raw));

  Future<void> changeFolder(String path) async {
    state = state.copyWith(saveDir: path);
    await ref.read(settingsProvider.notifier).updateSetting('save_dir', path);
  }

  void startTransfer() {
    state = state.copyWith(
      transferring: true,
      complete: false,
      canceled: false,
      progress: 0,
      phase: TransferPhase.receiving,
      log: [],
      currentFile: null,
      receivedText: null,
      pendingCompleteDialog: false,
    );
  }

  void setProgress(double p, TransferPhase phase) =>
      state = state.copyWith(progress: p, phase: phase);

  void appendLog(String line) {
    final next = [...state.log, line];
    state = state.copyWith(
      log: next.length > kMaxLogLines
          ? next.sublist(next.length - kMaxLogLines)
          : next,
    );
  }

  void setCurrentFile(String? file) => state = state.copyWith(currentFile: file);

  void finishTransfer({required bool canceled, int exitCode = 0}) {
    final success = !canceled && exitCode == 0;
    state = state.copyWith(
      transferring: false,
      complete: success,
      canceled: canceled,
      phase: canceled
          ? TransferPhase.error
          : success
              ? TransferPhase.complete
              : TransferPhase.error,
      // Clear transients on finish too (defensive)
      receivedText: null,
      pendingCompleteDialog: false,
    );
  }

  /// Called by controller on CrocTextReceivedEvent. UI layer listens and shows dialog.
  void onTextReceived(String text) {
    state = state.copyWith(receivedText: text);
  }

  /// Called by controller on CrocTransferCompleteEvent. UI layer listens and shows dialog + optional open.
  void onTransferComplete() {
    state = state.copyWith(pendingCompleteDialog: true);
  }

  void clearReceivedText() {
    if (state.receivedText != null) {
      state = state.copyWith(receivedText: null);
    }
  }

  void clearPendingCompleteDialog() {
    if (state.pendingCompleteDialog) {
      state = state.copyWith(pendingCompleteDialog: false);
    }
  }
}

final receiveProvider =
    NotifierProvider<ReceiveNotifier, ReceiveState>(ReceiveNotifier.new);