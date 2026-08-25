import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
    final showCamera = !kIsWeb && Platform.isAndroid;

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
      String? code = await QrScannerService.scanCamera();
      if (code == null && context.mounted && Platform.isAndroid) {
        // Native scanner unavailable — Flutter fallback.
        code = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const _QrScannerPage()),
        );
      }
      if (code != null) {
        final normalized = normalizeCrocCode(code);
        _codeController.text = normalized;
        notifier.pasteCode(code);
      }
    } on PlatformException catch (e, st) {
      GatorLog.e('ReceivePage', 'QR scan failed', e, st);
      if (context.mounted) {
        showGatorSnackBar(
          context,
          e.code == 'PERMISSION'
              ? 'Camera permission is required to scan QR codes'
              : 'Could not open the camera',
          error: true,
        );
      }
    } catch (e, st) {
      GatorLog.e('ReceivePage', 'QR scan failed', e, st);
      if (context.mounted) {
        showGatorSnackBar(context, 'Could not open the camera', error: true);
      }
    }
  }

  Future<void> _pickQrImage(
    BuildContext context,
    ReceiveNotifier notifier,
  ) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
      );
      if (image == null) return;
      final controller = MobileScannerController();
      try {
        final result = await controller.analyzeImage(image.path);
        final code = result?.barcodes.firstOrNull?.rawValue;
        if (code != null) {
          _codeController.text = normalizeCrocCode(code);
          notifier.pasteCode(code);
        } else if (context.mounted) {
          showGatorSnackBar(context, 'No QR code found in image');
        }
      } finally {
        await controller.dispose();
      }
    } catch (e, st) {
      GatorLog.e('ReceivePage', 'QR from image failed', e, st);
      if (context.mounted) {
        showGatorSnackBar(
          context,
          'Gator needs photo access to scan a QR from an image.',
          error: true,
        );
      }
    }
  }
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  StreamSubscription<Object?>? _subscription;
  bool _found = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
    );
    _subscription = _controller.barcodes.listen(_onDetect);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanner());
  }

  Future<void> _startScanner() async {
    try {
      await _controller.start();
    } on MobileScannerException catch (e) {
      GatorLog.w('QrScannerPage', 'start failed: $e');
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_found) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null && code.isNotEmpty) {
      _found = true;
      Navigator.pop(context, code);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_startScanner());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Toggle torch',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            useAppLifecycleState: false,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error.errorCode.message.toLowerCase().contains('permission')
                      ? 'Camera permission is required to scan QR codes'
                      : (error.errorDetails?.message ?? error.errorCode.message),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white70,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Text(
              'Align the code in the frame',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
