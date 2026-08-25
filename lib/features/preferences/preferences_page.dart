import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/features/dialogs/confirm_dialog.dart';
import 'package:gator/features/preferences/general_options_section.dart';
import 'package:gator/features/preferences/preference_widgets.dart';
import 'package:gator/features/preferences/relay_proxy_section.dart';
import 'package:gator/features/preferences/sending_options_section.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/widgets/constrained_content.dart';

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => ConstrainedContent(
          child: ListView(
            children: [
              const PreferenceSectionHeader('Appearance'),
              ListTile(
                title: const Text('Color scheme'),
                trailing: DropdownButton<String>(
                  value: settings.colorScheme,
                  items: const [
                    DropdownMenuItem(
                      value: 'default',
                      child: Text('System'),
                    ),
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateSetting('color_scheme', v);
                    }
                  },
                ),
              ),
              const PreferenceSectionHeader('Interface'),
              PreferenceSwitch(
                title: 'Show transfer-code QR on Send',
                subtitle: 'QR of the PAKE code, not the croc web URL',
                value: settings.showQrImage,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .updateSetting('show_qr_image', v),
              ),
              PreferenceSwitch(
                title: 'Show shell output',
                subtitle: 'Show detailed output from the croc command',
                value: settings.showShellOutput,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .updateSetting('show_shell_output', v),
              ),
              PreferenceSwitch(
                title: 'Show advanced options',
                subtitle:
                    'Reveal relay/proxy and power-user settings (e.g. throttle, hash, git)',
                value: settings.showAdvancedSettings,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .updateSetting('show_advanced_settings', v),
              ),
              const PreferenceSectionHeader('Receiving'),
              ListTile(
                title: const Text('Default save folder'),
                subtitle: Text(
                  settings.saveDir ?? getDefaultSaveDirLabel(),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Change folder',
                  onPressed: () async {
                    final path = await FilePicker.platform.getDirectoryPath();
                    if (path != null) {
                      await ref
                          .read(settingsProvider.notifier)
                          .updateSetting('save_dir', path);
                    }
                  },
                ),
              ),
              const PreferenceSwitch(
                title: 'Automatically accept incoming transfers',
                subtitle:
                    'Always on: the GUI cannot type Y/n into croc, so Receive '
                    'always passes --yes after you tap Start.',
                value: true,
                onChanged: null,
              ),
              PreferenceSwitch(
                title: 'Overwrite existing files without prompt',
                subtitle: 'Passes --overwrite to croc',
                value: settings.overwrite,
                onChanged: (v) async {
                  if (v) {
                    final ok = await showGatorConfirmDialog(
                      context,
                      title: 'Replace existing files?',
                      message:
                          'Incoming files with the same name will overwrite files in the save folder.',
                      confirmLabel: 'Overwrite',
                      destructive: true,
                    );
                    if (!ok) return;
                    await ref
                        .read(settingsProvider.notifier)
                        .updateMany({'overwrite': true, 'rename': false});
                  } else {
                    await ref
                        .read(settingsProvider.notifier)
                        .updateSetting('overwrite', false);
                  }
                },
              ),
              if (settings.showAdvancedSettings) ...[
                PreferenceSwitch(
                  title: 'Rename on conflict',
                  subtitle: 'Passes --rename (file (1).ext) instead of overwrite',
                  value: settings.rename,
                  onChanged: (v) async {
                    if (v) {
                      await ref.read(settingsProvider.notifier).updateMany({
                        'rename': true,
                        'overwrite': false,
                      });
                    } else {
                      await ref
                          .read(settingsProvider.notifier)
                          .updateSetting('rename', false);
                    }
                  },
                ),
                GeneralOptionsSection(settings: settings),
                RelayProxySection(settings: settings),
                SendingOptionsSection(settings: settings),
              ],
              const PreferenceSectionHeader('Reset'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await showGatorConfirmDialog(
                      context,
                      title: 'Reset all settings?',
                      message:
                          'Theme, save folder, relay, and transfer options go back to defaults.',
                      confirmLabel: 'Reset',
                      destructive: true,
                    );
                    if (ok) {
                      await ref
                          .read(settingsProvider.notifier)
                          .resetToDefaults();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Reset all settings to default'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
