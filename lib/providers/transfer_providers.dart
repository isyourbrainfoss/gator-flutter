import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/models/transfer_state.dart';
import 'package:gator/providers/croc_provider.dart';
import 'package:gator/services/croc_transfer_service.dart';

/// Creates a transfer service once croc path is known.
Future<CrocTransferService?> createTransferService(Ref ref) async {
  final locator = ref.read(crocBinaryLocatorProvider);
  final path = await locator.locate();
  if (path == null) return null;
  return CrocTransferService(crocPath: path);
}

TransferPhase phaseFromString(String? phase) => switch (phase) {
      'hashing' => TransferPhase.hashing,
      'sending' => TransferPhase.sending,
      'receiving' => TransferPhase.receiving,
      _ => TransferPhase.idle,
    };

/// List files in [dir] before a receive transfer (for post-process diff).
Future<Set<String>> snapshotDir(String dir) async {
  try {
    final d = Directory(dir);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d
        .list()
        .map((e) => e.path.split(Platform.pathSeparator).last)
        .toSet();
  } catch (_) {
    return {};
  }
}