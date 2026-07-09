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
    final newItems = [
      ...state.items,
      for (final p in paths)
        if (!existing.contains(p)) SendItem(path: p, excluded: exclude),
    ];
    state = state.copyWith(items: newItems);
  }

  void setText(String text) => state = state.copyWith(sendText: text);

  void removeItem(String path) {
    state = state.copyWith(
      items: state.items.where((i) => i.path != path).toList(),
    );
  }

  void removeText() => state = state.copyWith(sendText: '');

  void clearAll() => state = const SendState(
        showShellOutput: false,
        showQrImage: true,
      ).copyWith(
        showShellOutput: state.showShellOutput,
        showQrImage: state.showQrImage,
      );

  void startTransfer() {
    state = state.copyWith(
      transferring: true,
      complete: false,
      canceled: false,
      progress: 0,
      phase: TransferPhase.sending,
      code: '',
      log: [],
      errorMessage: '',
      currentFile: null,
    );
  }

  void setError(String message) =>
      state = state.copyWith(errorMessage: message);

  void setCode(String code) => state = state.copyWith(code: code);

  void setCurrentFile(String? file) => state = state.copyWith(currentFile: file);

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

  void finishTransfer({required bool canceled}) {
    state = state.copyWith(
      transferring: false,
      complete: !canceled,
      canceled: canceled,
      phase: canceled ? TransferPhase.error : TransferPhase.complete,
      items: state.items
          .map((i) => i.excluded ? i : i.copyWith(sent: !canceled))
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
    );
  }
}

final sendProvider = NotifierProvider<SendNotifier, SendState>(SendNotifier.new);