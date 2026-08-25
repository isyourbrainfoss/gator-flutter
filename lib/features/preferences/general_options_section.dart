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
          subtitle: '--debug',
          value: settings.debug,
          onChanged: (value) => notifier.updateSetting('debug', value),
        ),
        PreferenceSwitch(
          title: 'Disable compression',
          subtitle: '--no-compress',
          value: settings.noCompress,
          onChanged: (value) => notifier.updateSetting('no_compress', value),
        ),
        PreferenceSwitch(
          title: 'Prompt sender and recipient',
          subtitle: '--ask (the GUI cannot answer croc prompts)',
          value: settings.ask,
          onChanged: (value) => notifier.updateSetting('ask', value),
        ),
        PreferenceSwitch(
          title: 'Force local connections',
          subtitle: '--local',
          value: settings.local,
          onChanged: (value) => notifier.updateSetting('local', value),
        ),
        PreferenceSwitch(
          title: 'Use internal DNS resolver',
          subtitle: '--internal-dns (recommended on Android)',
          value: settings.internalDns,
          onChanged: (value) => notifier.updateSetting('internal_dns', value),
        ),
        PreferenceTextField(
          title: 'Multicast address for local discovery',
          subtitle: 'Leave empty for croc default ($crocDefaultMulticast)',
          value: settings.multicast,
          onSubmitted: (value) => notifier.updateSetting('multicast', value),
        ),
        PreferenceTextField(
          title: 'Set sender IP if known',
          subtitle: '--ip',
          value: settings.ip,
          onSubmitted: (value) => notifier.updateSetting('ip', value),
        ),
        PreferenceTextField(
          title: 'Throttle upload speed',
          subtitle: '--throttleUpload, e.g. 500k',
          value: settings.throttleUpload,
          onSubmitted: (value) =>
              notifier.updateSetting('throttle_upload', value),
        ),
        PreferenceTextField(
          title: 'Transport',
          subtitle: 'Empty = croc default. auto, derp, or relay (--transport)',
          value: settings.transport,
          onSubmitted: (value) => notifier.updateSetting('transport', value),
        ),
      ],
    );
  }
}