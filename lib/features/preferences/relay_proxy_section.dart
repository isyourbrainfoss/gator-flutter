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
          subtitle: 'Leave empty to use croc’s public relays (--relay)',
          hintText: 'croc public relays',
          value: settings.relay,
          onSubmitted: (v) =>
              ref.read(settingsProvider.notifier).updateSetting('relay', v),
        ),
        PreferenceTextField(
          title: 'IPv6 relay address',
          subtitle: 'Optional; leave empty unless you need IPv6 relay',
          hintText: 'Not set',
          value: settings.relay6,
          onSubmitted: (v) =>
              ref.read(settingsProvider.notifier).updateSetting('relay6', v),
        ),
        PreferenceTextField(
          title: 'Relay password',
          subtitle: 'Leave empty for croc’s default relay password (--pass)',
          hintText: 'croc default',
          value: settings.pass,
          obscure: true,
          onSubmitted: (v) =>
              ref.read(settingsProvider.notifier).updateSetting('pass', v),
        ),
        PreferenceTextField(
          title: 'SOCKS5 proxy',
          subtitle: 'Optional (--socks5)',
          hintText: 'e.g. 127.0.0.1:9050',
          value: settings.socks5,
          onSubmitted: (v) =>
              ref.read(settingsProvider.notifier).updateSetting('socks5', v),
        ),
        PreferenceTextField(
          title: 'HTTP proxy',
          subtitle: 'Optional (--connect)',
          hintText: 'e.g. proxy.example:8080',
          value: settings.connect,
          onSubmitted: (v) =>
              ref.read(settingsProvider.notifier).updateSetting('connect', v),
        ),
      ],
    );
  }
}
