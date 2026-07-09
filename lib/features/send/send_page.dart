import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/features/dialogs/add_text_dialog.dart';
import 'package:gator/features/send/send_controller.dart';
import 'package:gator/features/send/send_notifier.dart';
import 'package:gator/features/send/send_state.dart';
import 'package:gator/services/qr_service.dart';
import 'package:gator/widgets/adaptive_buttons.dart';
import 'package:gator/widgets/gator_snackbar.dart';
import 'package:gator/widgets/transfer_progress_card.dart';

class SendPage extends ConsumerWidget {
  const SendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sendProvider.select((s) => s.errorMessage), (prev, next) {
      if (next.isNotEmpty && next != prev) {
        showGatorSnackBar(context, next);
      }
    });

    final state = ref.watch(sendProvider);
    final notifier = ref.read(sendProvider.notifier);
    final controller = ref.read(sendControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ActionButtons(
          onAddFiles: () => _pickFiles(notifier, exclude: false),
          onAddFolder: () => _pickFolder(notifier, exclude: false),
          onAddText: () => _addText(context, notifier),
          onExcludeFiles: () => _pickFiles(notifier, exclude: true),
          onExcludeFolder: () => _pickFolder(notifier, exclude: true),
          onClear: notifier.clearAll,
        ),
        const SizedBox(height: 12),
        _FileList(
          items: state.items,
          sendText: state.sendText,
          onRemove: notifier.removeItem,
          onRemoveText: notifier.removeText,
        ),
        const SizedBox(height: 16),
        if (state.transferring || state.complete)
          TransferProgressCard(
            progress: state.progress,
            phase: state.phase,
            showSpinner: state.transferring,
            complete: state.complete,
            currentFile: state.currentFile,
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
                  tooltip: 'Start Transfer',
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
        if (state.transferring && state.code.isEmpty) ...[
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Waiting for transfer code from croc…'),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (state.code.isNotEmpty) ...[
          const SizedBox(height: 16),
          _CodeSection(
            code: state.code,
            showQr: state.showQrImage,
            onCopy: () => _copyCode(context, state.code),
          ),
        ],
        if ((state.showShellOutput || state.transferring) && state.log.isNotEmpty)
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
}

Future<void> _pickFiles(
  SendNotifier notifier, {
  required bool exclude,
}) async {
  final result = await FilePicker.platform.pickFiles(allowMultiple: true);
  if (result != null) {
    notifier.addFiles(
      result.paths.whereType<String>().toList(),
      exclude: exclude,
    );
  }
}

Future<void> _pickFolder(
  SendNotifier notifier, {
  required bool exclude,
}) async {
  final path = await FilePicker.platform.getDirectoryPath();
  if (path != null) notifier.addFiles([path], exclude: exclude);
}

Future<void> _addText(BuildContext context, SendNotifier notifier) async {
  final text = await showAddTextDialog(context);
  if (text != null && text.isNotEmpty) notifier.setText(text);
}

Future<void> _copyCode(BuildContext context, String code) async {
  await Clipboard.setData(ClipboardData(text: code));
  if (context.mounted) showGatorSnackBar(context, 'Code copied');
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onAddFiles,
    required this.onAddFolder,
    required this.onAddText,
    required this.onExcludeFiles,
    required this.onExcludeFolder,
    required this.onClear,
  });

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
        tooltip: 'Exclude',
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
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
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({
    required this.items,
    required this.sendText,
    required this.onRemove,
    required this.onRemoveText,
  });

  final List<SendItem> items;
  final String sendText;
  final void Function(String) onRemove;
  final VoidCallback onRemoveText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && sendText.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(
                Icons.folder_open,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                'No files or folders selected',
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
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onRemoveText,
              ),
            ),
          for (final item in items)
            ListTile(
              leading: Icon(
                item.excluded ? Icons.block : Icons.insert_drive_file,
                color: item.sent ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(item.path.split('/').last),
              subtitle: Text(
                item.excluded ? 'Excluded' : item.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: item.sent
                  ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
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
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'monospace',
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
              QrService.codeWidget(code),
            ],
          ],
        ),
      ),
    );
  }
}