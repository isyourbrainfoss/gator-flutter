import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/core/logger.dart';
import 'package:gator/features/dialogs/add_text_dialog.dart';
import 'package:gator/features/dialogs/confirm_dialog.dart';
import 'package:gator/features/send/send_controller.dart';
import 'package:gator/features/send/send_notifier.dart';
import 'package:gator/features/send/send_state.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/services/qr_service.dart';
import 'package:gator/widgets/adaptive_buttons.dart';
import 'package:gator/widgets/constrained_content.dart';
import 'package:gator/widgets/gator_snackbar.dart';
import 'package:gator/widgets/transfer_progress_card.dart';

class SendPage extends ConsumerWidget {
  const SendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sendProvider.select((s) => s.errorMessage), (prev, next) {
      if (next.isNotEmpty && next != prev) {
        showGatorSnackBar(context, next, error: true);
      }
    });

    final state = ref.watch(sendProvider);
    final notifier = ref.read(sendProvider.notifier);
    final controller = ref.read(sendControllerProvider);
    final showProgress = state.transferring ||
        state.complete ||
        state.phase == TransferPhase.error ||
        state.errorMessage.isNotEmpty;

    return ConstrainedContent(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ActionButtons(
            showExclude: state.items.isNotEmpty,
            showClear: state.hasQueue,
            onAddFiles: () => _pickFiles(context, notifier, exclude: false),
            onAddFolder: () => _pickFolder(context, notifier, exclude: false),
            onAddText: () => _addText(context, notifier),
            onExcludeFiles: () => _pickFiles(context, notifier, exclude: true),
            onExcludeFolder: () => _pickFolder(context, notifier, exclude: true),
            onClear: () => _confirmClear(context, notifier),
          ),
          const SizedBox(height: 12),
          _FileList(
            items: state.items,
            sendText: state.sendText,
            onRemove: notifier.removeItem,
            onRemoveText: notifier.removeText,
            onEditText: () => _addText(context, notifier, initial: state.sendText),
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
                    onPressed: state.canStart ? controller.startTransfer : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Start Transfer'),
                    tooltip: state.canStart
                        ? 'Start Transfer'
                        : 'Add files or text first',
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
                label: const Text('New transfer'),
                tooltip: 'New transfer',
              ),
            ),
          if (state.code.isNotEmpty) ...[
            const SizedBox(height: 16),
            _CodeSection(
              code: state.code,
              showQr: state.showQrImage,
              onCopy: () => _copyCode(context, state.code),
            ),
          ],
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
}

Future<void> _confirmClear(BuildContext context, SendNotifier notifier) async {
  final ok = await showGatorConfirmDialog(
    context,
    title: 'Clear send queue?',
    message: 'This removes all files, folders, and text from the list.',
    cancelLabel: 'Keep',
    confirmLabel: 'Clear',
    destructive: true,
  );
  if (ok) notifier.clearAll();
}

Future<void> _confirmCancel(
  BuildContext context,
  SendController controller,
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

Future<void> _pickFiles(
  BuildContext context,
  SendNotifier notifier, {
  required bool exclude,
}) async {
  try {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      notifier.addFiles(
        result.paths.whereType<String>().toList(),
        exclude: exclude,
      );
    }
  } catch (e, st) {
    GatorLog.e('SendPage', 'File picker failed', e, st);
    if (context.mounted) {
      showGatorSnackBar(context, 'Could not open the file picker', error: true);
    }
  }
}

Future<void> _pickFolder(
  BuildContext context,
  SendNotifier notifier, {
  required bool exclude,
}) async {
  try {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) notifier.addFiles([path], exclude: exclude);
  } catch (e, st) {
    GatorLog.e('SendPage', 'Folder picker failed', e, st);
    if (context.mounted) {
      showGatorSnackBar(context, 'Could not open the folder picker', error: true);
    }
  }
}

Future<void> _addText(
  BuildContext context,
  SendNotifier notifier, {
  String initial = '',
}) async {
  final text = await showAddTextDialog(context, initial: initial);
  if (text != null && text.isNotEmpty) notifier.setText(text);
}

Future<void> _copyCode(BuildContext context, String code) async {
  await Clipboard.setData(ClipboardData(text: code));
  if (context.mounted) {
    showGatorSnackBar(
      context,
      'Code copied. Recipient enters this on Receive.',
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.showExclude,
    required this.showClear,
    required this.onAddFiles,
    required this.onAddFolder,
    required this.onAddText,
    required this.onExcludeFiles,
    required this.onExcludeFolder,
    required this.onClear,
  });

  final bool showExclude;
  final bool showClear;
  final VoidCallback onAddFiles;
  final VoidCallback onAddFolder;
  final VoidCallback onAddText;
  final VoidCallback onExcludeFiles;
  final VoidCallback onExcludeFolder;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final addButton = MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: onAddFiles,
          child: const Text('Add Files'),
        ),
        MenuItemButton(
          onPressed: onAddFolder,
          child: const Text('Add Folder'),
        ),
        MenuItemButton(
          onPressed: onAddText,
          child: const Text('Add Text'),
        ),
      ],
      builder: (context, controller, child) => AdaptiveFilledButton(
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        tooltip: 'Add',
      ),
    );

    final excludeButton = MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: onExcludeFiles,
          child: const Text('Exclude Files'),
        ),
        MenuItemButton(
          onPressed: onExcludeFolder,
          child: const Text('Exclude Folder'),
        ),
      ],
      builder: (context, controller, child) => AdaptiveOutlinedButton(
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        icon: const Icon(Icons.remove),
        label: const Text('Exclude'),
        tooltip: 'Skip paths when sending a folder',
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (!showExclude) return addButton;
            final stackButtons = constraints.maxWidth < 360;
            if (stackButtons) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  addButton,
                  const SizedBox(height: 8),
                  excludeButton,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: addButton),
                const SizedBox(width: 8),
                Expanded(child: excludeButton),
              ],
            );
          },
        ),
        if (showClear) ...[
          const SizedBox(height: 8),
          AdaptiveOutlinedButton(
            onPressed: onClear,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear All'),
            tooltip: 'Clear All',
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({
    required this.items,
    required this.sendText,
    required this.onRemove,
    required this.onRemoveText,
    required this.onEditText,
  });

  final List<SendItem> items;
  final String sendText;
  final void Function(String) onRemove;
  final VoidCallback onRemoveText;
  final VoidCallback onEditText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && sendText.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            children: [
              Icon(
                Icons.folder_open,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                'Nothing to send yet',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap Add to pick files, a folder, or text. Then Start Transfer — '
                'Gator will show a short code (and QR) for the other person.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (sendText.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: Text(
                sendText.length > 60
                    ? '${sendText.substring(0, 60)}…'
                    : sendText,
              ),
              subtitle: const Text('Text to send'),
              onTap: onEditText,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove from queue',
                onPressed: onRemoveText,
              ),
            ),
          for (final item in items)
            ListTile(
              leading: Icon(
                item.excluded
                    ? Icons.block
                    : item.path.contains('.')
                        ? Icons.insert_drive_file
                        : Icons.folder,
                color: item.sent ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(item.path.split('/').last),
              subtitle: Text(
                item.excluded ? 'Excluded from this send' : item.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: item.sent
                  ? Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary)
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove from queue',
                      onPressed: () => onRemove(item.path),
                    ),
            ),
        ],
      ),
    );
  }
}

class _CodeSection extends StatelessWidget {
  const _CodeSection({
    required this.code,
    required this.showQr,
    required this.onCopy,
  });

  final String code;
  final bool showQr;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Share this code',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'On the other device, open Receive and enter or scan it.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy code',
                  onPressed: onCopy,
                ),
              ],
            ),
            if (showQr) ...[
              const SizedBox(height: 16),
              const Text('Scan this code on the other device'),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = (constraints.maxWidth - 32).clamp(160.0, 256.0);
                  return QrService.codeWidget(code, size: size);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
