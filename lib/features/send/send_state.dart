import 'package:gator/models/transfer_state.dart';

class SendItem {
  const SendItem({required this.path, this.sent = false, this.excluded = false});
  final String path;
  final bool sent;
  final bool excluded;

  SendItem copyWith({bool? sent, bool? excluded}) => SendItem(
        path: path,
        sent: sent ?? this.sent,
        excluded: excluded ?? this.excluded,
      );
}

class SendState {
  const SendState({
    this.items = const [],
    this.sendText = '',
    this.transferring = false,
    this.complete = false,
    this.canceled = false,
    this.progress = 0,
    this.phase = TransferPhase.idle,
    this.code = '',
    this.log = const [],
    this.showShellOutput = false,
    this.showQrImage = true,
    this.errorMessage = '',
    this.currentFile,
    this.speed,
    this.eta,
    this.fileIndex,
    this.fileCount,
  });

  static const _unset = Object();

  final List<SendItem> items;
  final String sendText;
  final bool transferring;
  final bool complete;
  final bool canceled;
  final double progress;
  final TransferPhase phase;
  final String code;
  final List<String> log;
  final bool showShellOutput;
  final bool showQrImage;
  final String errorMessage;
  final String? currentFile;
  final String? speed;
  final String? eta;
  final int? fileIndex;
  final int? fileCount;

  bool get canStart =>
      !transferring &&
      (sendText.isNotEmpty || items.any((i) => !i.excluded && !i.sent));

  bool get hasQueue => sendText.isNotEmpty || items.isNotEmpty;

  List<String> get selectedFiles =>
      items.where((i) => !i.excluded).map((i) => i.path).toList();

  List<String> get excludedPaths =>
      items.where((i) => i.excluded).map((i) => i.path).toList();

  SendState copyWith({
    List<SendItem>? items,
    String? sendText,
    bool? transferring,
    bool? complete,
    bool? canceled,
    double? progress,
    TransferPhase? phase,
    String? code,
    List<String>? log,
    bool? showShellOutput,
    bool? showQrImage,
    String? errorMessage,
    Object? currentFile = _unset,
    Object? speed = _unset,
    Object? eta = _unset,
    Object? fileIndex = _unset,
    Object? fileCount = _unset,
  }) =>
      SendState(
        items: items ?? this.items,
        sendText: sendText ?? this.sendText,
        transferring: transferring ?? this.transferring,
        complete: complete ?? this.complete,
        canceled: canceled ?? this.canceled,
        progress: progress ?? this.progress,
        phase: phase ?? this.phase,
        code: code ?? this.code,
        log: log ?? this.log,
        showShellOutput: showShellOutput ?? this.showShellOutput,
        showQrImage: showQrImage ?? this.showQrImage,
        errorMessage: errorMessage ?? this.errorMessage,
        currentFile: identical(currentFile, _unset)
            ? this.currentFile
            : currentFile as String?,
        speed: identical(speed, _unset) ? this.speed : speed as String?,
        eta: identical(eta, _unset) ? this.eta : eta as String?,
        fileIndex:
            identical(fileIndex, _unset) ? this.fileIndex : fileIndex as int?,
        fileCount:
            identical(fileCount, _unset) ? this.fileCount : fileCount as int?,
      );
}
