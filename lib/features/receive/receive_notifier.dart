import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/core/logger.dart';
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
    try {
      final dir = await ref.read(settingsProvider.notifier).resolveSaveDir();
      state = state.copyWith(saveDir: dir);
    } catch (e, st) {
      GatorLog.e('ReceiveNotifier', 'resolveSaveDir failed', e, st);
    }
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
      phase: TransferPhase.connecting,
      log: [],
      currentFile: null,
      receivedText: null,
      pendingCompleteDialog: false,
      errorMessage: '',
      speed: null,
      eta: null,
      fileIndex: null,
      fileCount: null,
    );
  }

  void setError(String message) =>
      state = state.copyWith(errorMessage: message);

  void applyProgress({
    double? fraction,
    TransferPhase? phase,
    String? currentFile,
    String? speed,
    String? eta,
    int? fileIndex,
    int? fileCount,
  }) {
    state = state.copyWith(
      progress: fraction ?? state.progress,
      phase: phase ?? state.phase,
      currentFile: currentFile ?? state.currentFile,
      speed: speed ?? state.speed,
      eta: eta ?? state.eta,
      fileIndex: fileIndex ?? state.fileIndex,
      fileCount: fileCount ?? state.fileCount,
    );
  }

  void appendLog(String line) {
    final next = [...state.log, line];
    state = state.copyWith(
      log: next.length > kMaxLogLines
          ? next.sublist(next.length - kMaxLogLines)
          : next,
    );
  }

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
      receivedText: state.receivedText,
      pendingCompleteDialog: state.pendingCompleteDialog,
    );
  }

  void onTextReceived(String text) {
    state = state.copyWith(receivedText: text);
  }

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

  void resetTransferUi() {
    state = state.copyWith(
      transferring: false,
      complete: false,
      canceled: false,
      progress: 0,
      phase: TransferPhase.idle,
      errorMessage: '',
      currentFile: null,
      speed: null,
      eta: null,
      fileIndex: null,
      fileCount: null,
      receivedText: null,
      pendingCompleteDialog: false,
    );
  }
}

final receiveProvider =
    NotifierProvider<ReceiveNotifier, ReceiveState>(ReceiveNotifier.new);
