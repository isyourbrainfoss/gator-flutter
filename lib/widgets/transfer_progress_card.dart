import 'package:flutter/material.dart';

import 'package:gator/models/transfer_state.dart';

/// Progress display with optional phase label, file, speed, and ETA.
class TransferProgressCard extends StatelessWidget {
  const TransferProgressCard({
    super.key,
    required this.progress,
    this.phase,
    this.showSpinner = false,
    this.complete = false,
    this.currentFile,
    this.speed,
    this.eta,
    this.fileIndex,
    this.fileCount,
    this.errorMessage,
  });

  final double progress;
  final TransferPhase? phase;
  final bool showSpinner;
  final bool complete;
  final String? currentFile;
  final String? speed;
  final String? eta;
  final int? fileIndex;
  final int? fileCount;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isError = phase == TransferPhase.error;
    final hasDeterminate = progress > 0 &&
        phase != TransferPhase.connecting &&
        phase != TransferPhase.waiting &&
        !isError;
    final subtitle = _subtitle();
    final semantics = [
      phaseLabel(phase),
      '${(progress * 100).round()} percent',
      if (currentFile != null && currentFile!.isNotEmpty) currentFile!,
      if (errorMessage != null && errorMessage!.isNotEmpty) errorMessage!,
    ].join(', ');

    return Semantics(
      label: semantics,
      child: Card(
        color: isError ? colorScheme.errorContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (showSpinner && !hasDeterminate && !complete && !isError)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (complete)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.check_circle, color: colorScheme.primary),
                    )
                  else if (isError)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.error, color: colorScheme.error),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhaseLabel(phase: phase),
                        if (currentFile != null && currentFile!.isNotEmpty)
                          Text(
                            fileCount != null && fileIndex != null
                                ? '$currentFile · $fileIndex of $fileCount'
                                : currentFile!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        if (isError &&
                            errorMessage != null &&
                            errorMessage!.isNotEmpty)
                          Text(
                            errorMessage!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                ),
                          ),
                      ],
                    ),
                  ),
                  if (!isError) Text('${(progress * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: hasDeterminate || complete ? progress.clamp(0.0, 1.0) : null,
                color: isError ? colorScheme.error : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _subtitle() {
    final parts = <String>[
      if (speed != null && speed!.isNotEmpty) speed!,
      if (eta != null && eta!.isNotEmpty) '~$eta left',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}

String phaseLabel(TransferPhase? phase) => switch (phase) {
      TransferPhase.hashing => 'Preparing files',
      TransferPhase.connecting => 'Connecting',
      TransferPhase.waiting => 'Waiting for the other device',
      TransferPhase.retrying => 'Retrying',
      TransferPhase.sending => 'Sending',
      TransferPhase.receiving => 'Receiving',
      TransferPhase.complete => 'Complete',
      TransferPhase.error => 'Error',
      _ => 'Transferring',
    };

/// Human-readable transfer phase label.
class PhaseLabel extends StatelessWidget {
  const PhaseLabel({super.key, this.phase});

  final TransferPhase? phase;

  @override
  Widget build(BuildContext context) {
    final isError = phase == TransferPhase.error;
    return Text(
      phaseLabel(phase),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: isError ? Theme.of(context).colorScheme.error : null,
          ),
    );
  }
}
