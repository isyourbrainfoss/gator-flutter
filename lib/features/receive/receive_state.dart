import 'package:gator/models/transfer_state.dart';

class ReceiveState {
  const ReceiveState({
    this.code = '',
    this.saveDir = '',
    this.transferring = false,
    this.complete = false,
    this.canceled = false,
    this.progress = 0,
    this.phase = TransferPhase.idle,
    this.log = const [],
    this.showShellOutput = false,
  });

  final String code;
  final String saveDir;
  final bool transferring;
  final bool complete;
  final bool canceled;
  final double progress;
  final TransferPhase phase;
  final List<String> log;
  final bool showShellOutput;

  bool get canStart => code.trim().isNotEmpty && saveDir.isNotEmpty;

  ReceiveState copyWith({
    String? code,
    String? saveDir,
    bool? transferring,
    bool? complete,
    bool? canceled,
    double? progress,
    TransferPhase? phase,
    List<String>? log,
    bool? showShellOutput,
  }) =>
      ReceiveState(
        code: code ?? this.code,
        saveDir: saveDir ?? this.saveDir,
        transferring: transferring ?? this.transferring,
        complete: complete ?? this.complete,
        canceled: canceled ?? this.canceled,
        progress: progress ?? this.progress,
        phase: phase ?? this.phase,
        log: log ?? this.log,
        showShellOutput: showShellOutput ?? this.showShellOutput,
      );
}