import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/features/preferences/preference_widgets.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/providers/settings_provider.dart';

class GeneralOptionsSection extends ConsumerWidget {
  const GeneralOptionsSection({super.key, required this.settings});

  final GatorSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PreferenceSectionHeader('General Options'),
        PreferenceSwitch(
          title: 'Debug mode',
          value: settings.debug,
          onChanged: (value) => notifier.updateSetting('debug', value),
        ),
        PreferenceSwitch(
          title: 'Disable compression',
          value: settings.noCompress,
          onChanged: (value) => notifier.updateSetting('no_compress', value),
        ),
        PreferenceSwitch(
          title: 'Prompt sender and recipient',
          value: settings.ask,
          onChanged: (value) => notifier.updateSetting('ask', value),
        ),
        PreferenceSwitch(
          title: 'Force local connections',
          value: settings.local,
          onChanged: (value) => notifier.updateSetting('local', value),
        ),
        PreferenceSwitch(
          title: 'Use internal DNS resolver',
          value: settings.internalDns,
          onChanged: (value) => notifier.updateSetting('internal_dns', value),
        ),
        if (settings.showAdvancedSettings) ...[
          PreferenceTextField(
            title: 'Multicast address for local discovery',
            subtitle: 'Leave empty for croc default ($crocDefaultMulticast)',
            value: settings.multicast,
            onSubmitted: (value) => notifier.updateSetting('multicast', value),
          ),
          PreferenceTextField(
            title: 'Set sender IP if known',
            value: settings.ip,
            onSubmitted: (value) => notifier.updateSetting('ip', value),
          ),
          PreferenceTextField(
            title: 'Throttle upload speed',
            value: settings.throttleUpload,
            onSubmitted: (value) =>
                notifier.updateSetting('throttle_upload', value),
          ),
        ],
      ],
    );
  }
}