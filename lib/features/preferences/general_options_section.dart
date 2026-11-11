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
          subtitle: 'Log extra croc detail for troubleshooting (--debug)',
          value: settings.debug,
          onChanged: (value) => notifier.updateSetting('debug', value),
        ),
        PreferenceSwitch(
          title: 'Disable compression',
          subtitle: 'Send files as-is; faster for already-compressed files (--no-compress)',
          value: settings.noCompress,
          onChanged: (value) => notifier.updateSetting('no_compress', value),
        ),
        PreferenceSwitch(
          title: 'Prompt sender and recipient',
          subtitle:
              'Not recommended: croc would wait for a terminal answer this app '
              'cannot give (--ask)',
          value: settings.ask,
          onChanged: (value) => notifier.updateSetting('ask', value),
        ),
        PreferenceSwitch(
          title: 'Force local connections',
          subtitle:
              'Only connect over the local network, never a relay (--local)',
          value: settings.local,
          onChanged: (value) => notifier.updateSetting('local', value),
        ),
        PreferenceSwitch(
          title: 'Use internal DNS resolver',
          subtitle: 'Recommended on Android if relays fail to resolve (--internal-dns)',
          value: settings.internalDns,
          onChanged: (value) => notifier.updateSetting('internal_dns', value),
        ),
        PreferenceTextField(
          title: 'Multicast address for local discovery',
          subtitle: 'Leave empty for croc default ($crocDefaultMulticast)',
          hintText: crocDefaultMulticast,
          value: settings.multicast,
          onSubmitted: (value) => notifier.updateSetting('multicast', value),
        ),
        PreferenceTextField(
          title: 'Sender IP address',
          subtitle: 'Optional; connect straight to a known sender (--ip)',
          hintText: 'e.g. 192.168.1.20',
          value: settings.ip,
          onSubmitted: (value) => notifier.updateSetting('ip', value),
        ),
        PreferenceTextField(
          title: 'Throttle upload speed',
          subtitle: 'Limit upload speed (--throttleUpload)',
          hintText: 'No limit (e.g. 500k)',
          value: settings.throttleUpload,
          onSubmitted: (value) =>
              notifier.updateSetting('throttle_upload', value),
        ),
        PreferenceTextField(
          title: 'Transport',
          subtitle: 'auto, derp, or relay (--transport)',
          hintText: 'croc default',
          value: settings.transport,
          onSubmitted: (value) => notifier.updateSetting('transport', value),
        ),
      ],
    );
  }
}
