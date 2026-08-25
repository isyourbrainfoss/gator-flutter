import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/features/send/send_state.dart';
import 'package:gator/models/transfer_state.dart';

class SendNotifier extends Notifier<SendState> {
  @override
  SendState build() => const SendState();

  void configure({required bool showShellOutput, required bool showQrImage}) {
    state = state.copyWith(
      showShellOutput: showShellOutput,
      showQrImage: showQrImage,
    );
  }

  void addFiles(List<String> paths, {bool exclude = false}) {
    final existing = state.items.map((i) => i.path).toSet();
    final newItems = [...state.items];
    for (final p in paths) {
      if (existing.add(p)) {
        newItems.add(SendItem(path: p, excluded: exclude));
      }
    }
    state = state.copyWith(items: newItems);
  }

  void setText(String text) => state = state.copyWith(sendText: text);

  void removeItem(String path) {
    state = state.copyWith(
      items: state.items.where((i) => i.path != path).toList(),
    );
  }

  void removeText() => state = state.copyWith(sendText: '');

  void clearAll() => state = SendState(
        showShellOutput: state.showShellOutput,
        showQrImage: state.showQrImage,
      );

  void startTransfer() {
    state = state.copyWith(
      transferring: true,
      complete: false,
      canceled: false,
      progress: 0,
      phase: TransferPhase.connecting,
      code: '',
      log: [],
      errorMessage: '',
      currentFile: null,
      speed: null,
      eta: null,
      fileIndex: null,
      fileCount: null,
    );
  }

  void setError(String message) =>
      state = state.copyWith(errorMessage: message);

  void setCode(String code) => state = state.copyWith(code: code);

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
      items: state.items
          .map((i) => i.excluded ? i : i.copyWith(sent: success))
          .toList(),
    );
  }

  void resetTransferUi() {
    state = state.copyWith(
      transferring: false,
      complete: false,
      canceled: false,
      progress: 0,
      phase: TransferPhase.idle,
      code: '',
      errorMessage: '',
      currentFile: null,
      speed: null,
      eta: null,
      fileIndex: null,
      fileCount: null,
      items: state.items.map((i) => i.copyWith(sent: false)).toList(),
    );
  }
}

final sendProvider = NotifierProvider<SendNotifier, SendState>(SendNotifier.new);
