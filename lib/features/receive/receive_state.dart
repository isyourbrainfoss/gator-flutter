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
    this.currentFile,
    this.receivedText,
    this.pendingCompleteDialog = false,
    this.errorMessage = '',
    this.speed,
    this.eta,
    this.fileIndex,
    this.fileCount,
  });

  static const _unset = Object();

  final String code;
  final String saveDir;
  final bool transferring;
  final bool complete;
  final bool canceled;
  final double progress;
  final TransferPhase phase;
  final List<String> log;
  final bool showShellOutput;
  final String? currentFile;
  final String? receivedText;
  final bool pendingCompleteDialog;
  final String errorMessage;
  final String? speed;
  final String? eta;
  final int? fileIndex;
  final int? fileCount;

  bool get canStart =>
      !transferring && code.trim().isNotEmpty && saveDir.isNotEmpty;

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
    Object? currentFile = _unset,
    Object? receivedText = _unset,
    bool? pendingCompleteDialog,
    String? errorMessage,
    Object? speed = _unset,
    Object? eta = _unset,
    Object? fileIndex = _unset,
    Object? fileCount = _unset,
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
        currentFile: identical(currentFile, _unset)
            ? this.currentFile
            : currentFile as String?,
        receivedText: identical(receivedText, _unset)
            ? this.receivedText
            : receivedText as String?,
        pendingCompleteDialog:
            pendingCompleteDialog ?? this.pendingCompleteDialog,
        errorMessage: errorMessage ?? this.errorMessage,
        speed: identical(speed, _unset) ? this.speed : speed as String?,
        eta: identical(eta, _unset) ? this.eta : eta as String?,
        fileIndex:
            identical(fileIndex, _unset) ? this.fileIndex : fileIndex as int?,
        fileCount:
            identical(fileCount, _unset) ? this.fileCount : fileCount as int?,
      );
}
