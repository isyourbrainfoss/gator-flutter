import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/core/logger.dart';
import 'package:gator/features/dialogs/confirm_dialog.dart';
import 'package:gator/features/dialogs/received_text_dialog.dart';
import 'package:gator/features/dialogs/transfer_complete_dialog.dart';
import 'package:gator/features/receive/receive_controller.dart';
import 'package:gator/features/receive/receive_notifier.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/services/croc_parser.dart';
import 'package:gator/services/folder_opener.dart';
import 'package:gator/services/qr_scanner_service.dart';
import 'package:gator/widgets/adaptive_buttons.dart';
import 'package:gator/widgets/constrained_content.dart';
import 'package:gator/widgets/gator_snackbar.dart';
import 'package:gator/widgets/transfer_progress_card.dart';

class ReceivePage extends ConsumerStatefulWidget {
  const ReceivePage({super.key});

  @override
  ConsumerState<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends ConsumerState<ReceivePage> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(receiveProvider.select((s) => s.code), (prev, next) {
      if (next != _codeController.text) {
        _codeController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    ref.listen(receiveProvider.select((s) => s.errorMessage), (prev, next) {
      if (next.isNotEmpty && next != prev) {
        showGatorSnackBar(context, next, error: true);
      }
    });

    ref.listen(receiveProvider.select((s) => (s.complete, s.canceled)),
        (prev, next) {
      if (next.$1 && !next.$2 && (prev == null || !prev.$1)) {
        // Dialog (files) or received-text handles success; skip extra snack.
      }
    });

    ref.listen(receiveProvider.select((s) => s.receivedText), (prev, next) {
      if (next != null && next.isNotEmpty && next != prev) {
        showReceivedTextDialog(context, next).then((_) {
          if (mounted) {
            ref.read(receiveProvider.notifier).clearReceivedText();
          }
        });
      }
    });

    ref.listen(receiveProvider.select((s) => s.pendingCompleteDialog),
        (prev, next) {
      if (next == true && prev != true) {
        showTransferCompleteDialog(context).then((open) async {
          if (open && mounted) {
            final dir = ref.read(receiveProvider).saveDir;
            await _openFolder(dir);
          }
          if (mounted) {
            ref.read(receiveProvider.notifier).clearPendingCompleteDialog();
          }
        });
      }
    });

    final state = ref.watch(receiveProvider);
    final notifier = ref.read(receiveProvider.notifier);
    final controller = ref.read(receiveControllerProvider);
    final showProgress = state.transferring ||
        state.complete ||
        state.phase == TransferPhase.error ||
        state.errorMessage.isNotEmpty;
    final showCamera = !kIsWeb && QrScannerService.isSupported;

    return ConstrainedContent(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _codeController,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              letterSpacing: 0.4,
            ),
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.go,
            decoration: InputDecoration(
              labelText: 'Transfer code',
              hintText: 'cactus-lion-pizza',
              helperText:
                  'Ask the sender for their Gator/croc code, or scan their QR.',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check),
                tooltip: state.saveDir.isEmpty
                    ? 'Waiting for save folder…'
                    : 'Start receiving',
                onPressed: state.transferring
                    ? null
                    : () {
                        notifier.setCode(_codeController.text);
                        controller.startTransfer();
                      },
              ),
            ),
            enabled: !state.transferring,
            onSubmitted: state.transferring
                ? null
                : (_) {
                    notifier.setCode(_codeController.text);
                    controller.startTransfer();
                  },
            onChanged: notifier.setCode,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AdaptiveOutlinedButton(
                onPressed:
                    state.transferring ? null : () => _pasteCode(notifier),
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste from Clipboard'),
                tooltip: 'Paste from Clipboard',
              ),
              if (showCamera)
                AdaptiveOutlinedButton(
                  onPressed: state.transferring
                      ? null
                      : () => _scanCamera(context, notifier),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code'),
                  tooltip: 'Scan QR Code',
                ),
              if (showCamera)
                AdaptiveOutlinedButton(
                  onPressed: state.transferring
                      ? null
                      : () => _pickQrImage(context, notifier),
                  icon: const Icon(Icons.image),
                  label: const Text('Scan QR from Image'),
                  tooltip: 'Scan QR from Image',
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: state.complete
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : const Icon(Icons.folder),
            title: Text(
              state.complete ? 'Received successfully' : 'Save to folder',
            ),
            subtitle: Text(
              state.saveDir.isEmpty ? 'Loading…' : state.saveDir,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: state.complete
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        tooltip: 'Open received folder',
                        onPressed: state.saveDir.isEmpty
                            ? null
                            : () => _openFolder(state.saveDir),
                      ),
                      IconButton(
                        icon: const Icon(Icons.drive_folder_upload),
                        tooltip: 'Change save folder',
                        onPressed: state.transferring
                            ? null
                            : () => _changeFolder(notifier),
                      ),
                    ],
                  )
                : IconButton(
                    icon: const Icon(Icons.folder_open),
                    tooltip: 'Change save folder',
                    onPressed: state.transferring
                        ? null
                        : () => _changeFolder(notifier),
                  ),
            tileColor: state.complete
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 16),
          if (showProgress)
            TransferProgressCard(
              progress: state.progress,
              phase: state.phase,
              showSpinner: state.transferring,
              complete: state.complete,
              currentFile: state.currentFile,
              speed: state.speed,
              eta: state.eta,
              fileIndex: state.fileIndex,
              fileCount: state.fileCount,
              errorMessage: state.errorMessage,
            )
          else
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SizedBox(
                  width: double.infinity,
                  child: AdaptiveFilledButton(
                    onPressed: state.canStart
                        ? () {
                            notifier.setCode(_codeController.text);
                            controller.startTransfer();
                          }
                        : null,
                    icon: const Icon(Icons.download),
                    label: const Text('Start Receiving'),
                    tooltip: state.saveDir.isEmpty
                        ? 'Waiting for save folder…'
                        : 'Start Receiving',
                  ),
                ),
              ),
            ),
          if (state.transferring)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => _confirmCancel(context, controller),
                  style: FilledButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    minimumSize: const Size(48, 40),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          if (!state.transferring &&
              (state.complete ||
                  state.canceled ||
                  state.phase == TransferPhase.error))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AdaptiveFilledButton(
                onPressed: notifier.resetTransferUi,
                icon: const Icon(Icons.refresh),
                label: const Text('Receive another'),
                tooltip: 'Receive another',
              ),
            ),
          if (state.showShellOutput && state.log.isNotEmpty)
            ExpansionTile(
              title: Text(
                'Shell output${state.log.length >= kMaxLogLines ? " (trimmed)" : ""}',
              ),
              initiallyExpanded: state.phase == TransferPhase.error,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: SelectableText(
                    state.log.join('\n'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    ReceiveController controller,
  ) async {
    final ok = await showGatorConfirmDialog(
      context,
      title: 'Cancel this transfer?',
      message: 'The other person will be disconnected.',
      cancelLabel: 'Keep transferring',
      confirmLabel: 'Cancel transfer',
      destructive: true,
    );
    if (ok) await controller.cancelTransfer();
  }

  Future<void> _pasteCode(ReceiveNotifier notifier) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      final normalized = normalizeCrocCode(data.text!);
      _codeController.text = normalized;
      notifier.pasteCode(data.text!);
      if (mounted) {
        showGatorSnackBar(context, 'Code pasted. Tap Start receiving.');
      }
    } else if (mounted) {
      showGatorSnackBar(context, 'Clipboard is empty');
    }
  }

  Future<void> _changeFolder(ReceiveNotifier notifier) async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path != null) await notifier.changeFolder(path);
    } catch (e, st) {
      GatorLog.e('ReceivePage', 'Folder picker failed', e, st);
      if (mounted) {
        showGatorSnackBar(context, 'Could not open the folder picker',
            error: true);
      }
    }
  }

  Future<void> _openFolder(String path) async {
    final opened = await FolderOpener.open(path);
    if (!opened && mounted) {
      showGatorSnackBar(context, 'Could not open folder', error: true);
    }
  }

  Future<void> _scanCamera(
    BuildContext context,
    ReceiveNotifier notifier,
  ) async {
    try {
      final code = await QrScannerService.scanCamera();
      // null: the user closed the scanner — nothing to do.
      if (code != null) _applyScannedCode(code, notifier);
    } on QrScanException catch (e) {
      GatorLog.w('ReceivePage', 'QR scan failed: $e');
      if (!context.mounted) return;
      showGatorSnackBar(
        context,
        e.message,
        error: true,
        action: e.failure == QrScanFailure.permissionPermanentlyDenied
            ? SnackBarAction(
                label: 'Settings',
                onPressed: () => unawaited(QrScannerService.openAppSettings()),
              )
            : null,
      );
    } catch (e, st) {
      GatorLog.e('ReceivePage', 'QR scan failed', e, st);
      if (context.mounted) {
        showGatorSnackBar(
          context,
          QrScannerService.messageFor(QrScanFailure.camera),
          error: true,
        );
      }
    }
  }

  void _applyScannedCode(String code, ReceiveNotifier notifier) {
    _codeController.text = normalizeCrocCode(code);
    notifier.pasteCode(code);
  }

  Future<void> _pickQrImage(
    BuildContext context,
    ReceiveNotifier notifier,
  ) async {
    final XFile? image;
    try {
      image = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (e, st) {
      GatorLog.e('ReceivePage', 'Image picker failed', e, st);
      if (context.mounted) {
        showGatorSnackBar(
          context,
          'Gator needs photo access to scan a QR from an image.',
          error: true,
        );
      }
      return;
    }
    if (image == null) return;
    try {
      final code = await QrScannerService.decodeImage(image.path);
      if (code != null && code.isNotEmpty) {
        _applyScannedCode(code, notifier);
      } else if (context.mounted) {
        showGatorSnackBar(context, 'No QR code found in image');
      }
    } catch (e, st) {
      GatorLog.e('ReceivePage', 'QR from image failed', e, st);
      if (context.mounted) {
        showGatorSnackBar(context, 'Could not read that image', error: true);
      }
    }
  }
}
