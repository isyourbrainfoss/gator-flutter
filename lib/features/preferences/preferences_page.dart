import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/features/preferences/general_options_section.dart';
import 'package:gator/features/preferences/preference_widgets.dart';
import 'package:gator/features/preferences/relay_proxy_section.dart';
import 'package:gator/features/preferences/sending_options_section.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/providers/settings_provider.dart';

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (settings) => Scaffold(
        appBar: AppBar(title: const Text('Preferences')),
        body: ListView(
          children: [
            const PreferenceSectionHeader('Appearance'),
            ListTile(
              title: const Text('Color scheme'),
              trailing: DropdownButton<String>(
                value: settings['color_scheme'] as String? ?? 'default',
                items: const [
                  DropdownMenuItem(
                    value: 'default',
                    child: Text('Default (follow system)'),
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
              title: 'Show QR image',
              subtitle: 'Display the QR code for the generated transfer code',
              value: settings['show_qr_image'] as bool? ?? true,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .updateSetting('show_qr_image', v),
            ),
            PreferenceSwitch(
              title: 'Show shell output',
              subtitle: 'Show detailed output from the croc command',
              value: settings['show_shell_output'] as bool? ?? false,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .updateSetting('show_shell_output', v),
            ),
            const PreferenceSectionHeader('Receiving'),
            ListTile(
              title: const Text('Default save folder'),
              subtitle: Text(
                settings['save_dir'] as String? ?? getDefaultSaveDirLabel(),
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
            PreferenceSwitch(
              title: 'Automatically accept incoming transfers',
              subtitle: 'Passes --yes to croc; skips all confirmation prompts',
              value: settings['yes'] as bool? ?? true,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).updateSetting('yes', v),
            ),
            PreferenceSwitch(
              title: 'Overwrite existing files without prompt',
              subtitle: 'Passes --overwrite to croc',
              value: settings['overwrite'] as bool? ?? false,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .updateSetting('overwrite', v),
            ),
            GeneralOptionsSection(settings: settings),
            RelayProxySection(settings: settings),
            SendingOptionsSection(settings: settings),
            const PreferenceSectionHeader('Reset'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(settingsProvider.notifier).resetToDefaults(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Reset all settings to default'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}