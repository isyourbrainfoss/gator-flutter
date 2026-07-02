import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    );
  }

  void setProgress(double p, TransferPhase phase) =>
      state = state.copyWith(progress: p, phase: phase);

  void appendLog(String line) =>
      state = state.copyWith(log: [...state.log, line]);

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
    );
  }
}

final receiveProvider =
    NotifierProvider<ReceiveNotifier, ReceiveState>(ReceiveNotifier.new);