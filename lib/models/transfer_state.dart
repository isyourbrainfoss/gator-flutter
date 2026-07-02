/// Transfer phase labels shown in the UI.
enum TransferPhase { idle, hashing, sending, receiving, complete, error }

/// Events emitted by [CrocTransferService] while a transfer runs.
sealed class CrocEvent {
  const CrocEvent();
}

final class CrocLogEvent extends CrocEvent {
  const CrocLogEvent(this.message);
  final String message;
}

final class CrocCodeEvent extends CrocEvent {
  const CrocCodeEvent(this.code);
  final String code;
}

final class CrocProgressEvent extends CrocEvent {
  const CrocProgressEvent(this.fraction);
  final double fraction;
}

final class CrocStatusEvent extends CrocEvent {
  const CrocStatusEvent(this.phase);
  final String phase;
}

final class CrocTextReceivedEvent extends CrocEvent {
  const CrocTextReceivedEvent(this.text);
  final String text;
}

final class CrocTransferCompleteEvent extends CrocEvent {
  const CrocTransferCompleteEvent();
}

final class CrocFinishedEvent extends CrocEvent {
  const CrocFinishedEvent({this.exitCode = 0});
  final int exitCode;
}