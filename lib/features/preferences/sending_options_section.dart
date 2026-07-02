import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/features/preferences/preference_widgets.dart';
import 'package:gator/providers/settings_provider.dart';

class SendingOptionsSection extends ConsumerWidget {
  const SendingOptionsSection({super.key, required this.settings});

  final Map<String, dynamic> settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PreferenceSectionHeader('Sending Options'),
        PreferenceTextField(
          title: 'Default custom transfer code',
          subtitle: 'Optional – leave empty for a random code',
          value: settings['default_code'] as String? ?? '',
          onSubmitted: (value) => notifier.updateSetting('default_code', value),
        ),
        PreferenceHashDropdown(
          value: settings['hash'] as String? ?? '',
          onChanged: (value) => notifier.updateSetting('hash', value),
        ),
        PreferenceSwitch(
          title: 'Zip folder before sending',
          value: settings['zip_folder'] as bool? ?? false,
          onChanged: (value) => notifier.updateSetting('zip_folder', value),
        ),
        PreferenceSwitch(
          title: 'Disable local relay',
          value: settings['no_local'] as bool? ?? false,
          onChanged: (value) => notifier.updateSetting('no_local', value),
        ),
        PreferenceSwitch(
          title: 'Disable multiplexing',
          value: settings['no_multi'] as bool? ?? false,
          onChanged: (value) => notifier.updateSetting('no_multi', value),
        ),
        PreferenceSwitch(
          title: 'Respect .gitignore',
          value: settings['git'] as bool? ?? false,
          onChanged: (value) => notifier.updateSetting('git', value),
        ),
        PreferenceTextField(
          title: 'Base port for relay',
          subtitle: '0 = croc default ($crocDefaultPort)',
          value: '${settings['port'] ?? 0}',
          keyboardType: TextInputType.number,
          onSubmitted: (value) =>
              notifier.updateSetting('port', int.tryParse(value) ?? 0),
        ),
        PreferenceTextField(
          title: 'Number of ports for transfers',
          subtitle: '0 = croc default ($crocDefaultTransfers)',
          value: '${settings['transfers'] ?? 0}',
          keyboardType: TextInputType.number,
          onSubmitted: (value) =>
              notifier.updateSetting('transfers', int.tryParse(value) ?? 0),
        ),
        PreferenceSwitch(
          title: 'Show receive code as QR',
          subtitle: 'Shows QR code in shell output',
          value: settings['qr'] as bool? ?? false,
          onChanged: (value) => notifier.updateSetting('qr', value),
        ),
      ],
    );
  }
}