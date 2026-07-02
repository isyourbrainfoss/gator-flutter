import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/features/preferences/preference_widgets.dart';
import 'package:gator/providers/settings_provider.dart';

class GeneralOptionsSection extends ConsumerWidget {
  const GeneralOptionsSection({super.key, required this.settings});

  final Map<String, dynamic> settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PreferenceSectionHeader('General Options'),
        PreferenceSwitch(
          title: 'Debug mode',
          value: settings['debug'] as bool? ?? false,
          onChanged: (value) => notifier.updateSetting('debug', value),
        ),
        PreferenceSwitch(
          title: 'Disable compression',
          value: settings['no_compress'] as bool? ?? false,
          onChanged: (value) => notifier.updateSetting('no_compress', value),
        ),
        PreferenceSwitch(
          title: 'Prompt sender and recipient',
          value: settings['ask'] as bool? ?? false,
          onChanged: (value) => notifier.updateSetting('ask', value),
        ),
        PreferenceSwitch(
          title: 'Force local connections',
          value: settings['local'] as bool? ?? false,
          onChanged: (value) => notifier.updateSetting('local', value),
        ),
        PreferenceSwitch(
          title: 'Use internal DNS resolver',
          value: settings['internal_dns'] as bool? ?? false,
          onChanged: (value) => notifier.updateSetting('internal_dns', value),
        ),
        PreferenceTextField(
          title: 'Multicast address for local discovery',
          subtitle: 'Leave empty for croc default ($crocDefaultMulticast)',
          value: settings['multicast'] as String? ?? '',
          onSubmitted: (value) => notifier.updateSetting('multicast', value),
        ),
        PreferenceTextField(
          title: 'Set sender IP if known',
          value: settings['ip'] as String? ?? '',
          onSubmitted: (value) => notifier.updateSetting('ip', value),
        ),
        PreferenceTextField(
          title: 'Throttle upload speed',
          value: settings['throttle_upload'] as String? ?? '',
          onSubmitted: (value) =>
              notifier.updateSetting('throttle_upload', value),
        ),
      ],
    );
  }
}