import 'package:flutter/material.dart';

import 'package:gator/models/transfer_state.dart';

/// Progress display with optional phase label and percentage.
class TransferProgressCard extends StatelessWidget {
  const TransferProgressCard({
    super.key,
    required this.progress,
    this.phase,
    this.showSpinner = false,
    this.complete = false,
  });

  final double progress;
  final TransferPhase? phase;
  final bool showSpinner;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (showSpinner)
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
                  ),
                Expanded(
                  child: PhaseLabel(phase: phase),
                ),
                Text('${(progress * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
          ],
        ),
      ),
    );
  }
}

/// Human-readable transfer phase label.
class PhaseLabel extends StatelessWidget {
  const PhaseLabel({super.key, this.phase});

  final TransferPhase? phase;

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      TransferPhase.hashing => 'Hashing',
      TransferPhase.sending => 'Sending',
      TransferPhase.receiving => 'Receiving',
      TransferPhase.complete => 'Complete',
      TransferPhase.error => 'Error',
      _ => 'Transferring',
    };
    return Text(label, style: Theme.of(context).textTheme.titleSmall);
  }
}