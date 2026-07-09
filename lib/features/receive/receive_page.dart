import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/features/dialogs/received_text_dialog.dart';
import 'package:gator/features/dialogs/transfer_complete_dialog.dart';
import 'package:gator/features/receive/receive_controller.dart';
import 'package:gator/features/receive/receive_notifier.dart';
import 'package:gator/services/folder_opener.dart';
import 'package:gator/services/qr_scanner_service.dart';
import 'package:gator/widgets/adaptive_buttons.dart';
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
    ref.listen(receiveProvider.select((s) => (s.complete, s.canceled)), (prev, next) {
      if (next.$1 && !next.$2 && (prev == null || !prev.$1)) {
        showGatorSnackBar(context, 'Transfer finished');
      }
    });

    // Listen for side-effect events from controller-orchestrated transfers.
    // Dialogs (and any snack) live in the Page; controllers remain context-free.
    ref.listen(receiveProvider.select((s) => s.receivedText), (prev, next) {
      if (next != null && next.isNotEmpty && next != prev) {
        showReceivedTextDialog(context, next).then((_) {
          if (mounted) {
            ref.read(receiveProvider.notifier).clearReceivedText();
          }
        });
      }
    });

    ref.listen(receiveProvider.select((s) => s.pendingCompleteDialog), (prev, next) {
      if (next == true && prev != true) {
        showTransferCompleteDialog(context).then((open) async {
          if (open && mounted) {
            final dir = ref.read(receiveProvider).saveDir;
            await FolderOpener.open(dir);
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _codeController,
          decoration: InputDecoration(
            labelText: 'Transfer code',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.check),
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
              : (_) => controller.startTransfer(),
          onChanged: notifier.setCode,
        ),
        const SizedBox(height: 12),
        AdaptiveOutlinedButton(
          onPressed: state.transferring ? null : () => _pasteCode(notifier),
          icon: const Icon(Icons.content_paste),
          label: const Text('Paste from Clipboard'),
          tooltip: 'Paste from Clipboard',
        ),
        const SizedBox(height: 8),
        AdaptiveOutlinedButton(
          onPressed: state.transferring ? null : () => _scanCamera(context, notifier),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan QR Code'),
          tooltip: 'Scan QR Code',
        ),
        const SizedBox(height: 8),
        AdaptiveOutlinedButton(
          onPressed: state.transferring ? null : () => _pickQrImage(context, notifier),
          icon: const Icon(Icons.image),
          label: const Text('Scan QR from Image'),
          tooltip: 'Scan QR from Image',
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        const SizedBox(height: 16),
        if (state.transferring || state.complete)
          TransferProgressCard(
            progress: state.progress,
            phase: state.phase,
            showSpinner: state.transferring,
            complete: state.complete,
          )
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SizedBox(
                width: double.infinity,
                child: AdaptiveFilledButton(
                  onPressed: state.canStart
                      ? () => controller.startTransfer()
                      : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Start Receiving'),
                  tooltip: 'Start Receiving',
                ),
              ),
            ),
          ),
        if (state.transferring)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: controller.cancelTransfer,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Cancel'),
              ),
            ),
          ),
        if (state.showShellOutput && state.log.isNotEmpty)
          ExpansionTile(
            title: Text(
              'Shell output${state.log.length >= kMaxLogLines ? " (trimmed)" : ""}',
            ),
            initiallyExpanded: true,
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
    );
  }

  Future<void> _pasteCode(ReceiveNotifier notifier) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _codeController.text = data!.text!;
      notifier.pasteCode(data.text!);
    }
  }

  Future<void> _changeFolder(ReceiveNotifier notifier) async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) await notifier.changeFolder(path);
  }

  Future<void> _openFolder(String path) async {
    final opened = await FolderOpener.open(path);
    if (!opened && mounted) {
      showGatorSnackBar(context, 'Could not open folder');
    }
  }

  Future<void> _scanCamera(BuildContext context, ReceiveNotifier notifier) async {
    String? code = await QrScannerService.scanCamera();
    if (code == null && context.mounted) {
      code = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const _QrScannerPage()),
      );
    }
    if (code != null) {
      _codeController.text = code;
      notifier.pasteCode(code);
    }
  }

  Future<void> _pickQrImage(BuildContext context, ReceiveNotifier notifier) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final controller = MobileScannerController();
    try {
      final result = await controller.analyzeImage(image.path);
      final code = result?.barcodes.firstOrNull?.rawValue;
      if (code != null) {
        _codeController.text = code;
        notifier.pasteCode(code);
      } else if (context.mounted) {
        showGatorSnackBar(context, 'No QR code found in image');
      }
    } catch (e) {
      if (context.mounted) {
        showGatorSnackBar(context, 'Could not read QR from image');
      }
    } finally {
      await controller.dispose();
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
    } on MobileScannerException {
      // Error state is surfaced by the controller / errorBuilder.
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
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        controller: _controller,
        useAppLifecycleState: false,
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error.errorDetails?.message ?? error.errorCode.message,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}