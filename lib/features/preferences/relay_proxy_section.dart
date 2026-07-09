import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/features/preferences/preference_widgets.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/providers/settings_provider.dart';

class RelayProxySection extends ConsumerWidget {
  const RelayProxySection({super.key, required this.settings});

  final GatorSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PreferenceSectionHeader('Relay and Proxy'),
        PreferenceTextField(
          title: 'Relay address',
          subtitle: 'Leave empty to use the croc default relay',
          value: settings.relay,
          onSubmitted: (v) =>
              ref.read(settingsProvider.notifier).updateSetting('relay', v),
        ),
        PreferenceTextField(
          title: 'IPv6 relay address',
          subtitle: 'Optional; leave empty unless you need IPv6 relay',
          value: settings.relay6,
          onSubmitted: (v) =>
              ref.read(settingsProvider.notifier).updateSetting('relay6', v),
        ),
        PreferenceTextField(
          title: 'Relay password',
          subtitle: 'Default: pass123',
          value: settings.pass,
          obscure: true,
          onSubmitted: (v) =>
              ref.read(settingsProvider.notifier).updateSetting('pass', v),
        ),
        PreferenceTextField(
          title: 'SOCKS5 proxy',
          value: settings.socks5,
          onSubmitted: (v) =>
              ref.read(settingsProvider.notifier).updateSetting('socks5', v),
        ),
        PreferenceTextField(
          title: 'HTTP proxy',
          value: settings.connect,
          onSubmitted: (v) =>
              ref.read(settingsProvider.notifier).updateSetting('connect', v),
        ),
      ],
    );
  }
}