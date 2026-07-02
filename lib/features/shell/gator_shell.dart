import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/features/preferences/preferences_page.dart';
import 'package:gator/features/receive/receive_notifier.dart';
import 'package:gator/features/receive/receive_page.dart';
import 'package:gator/features/send/send_notifier.dart';
import 'package:gator/features/send/send_page.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/providers/share_intent_provider.dart';
import 'package:gator/services/share_intent_service.dart';
import 'package:gator/widgets/gator_snackbar.dart';

/// Main app shell with bottom navigation between Send and Receive tabs.
class GatorShell extends ConsumerStatefulWidget {
  const GatorShell({super.key});

  @override
  ConsumerState<GatorShell> createState() => _GatorShellState();
}

class _GatorShellState extends ConsumerState<GatorShell> {
  int _index = 0;
  StreamSubscription<SharePayload>? _shareSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initShareIntentHandling();
    });
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  Future<void> _initShareIntentHandling() async {
    final service = ref.read(shareIntentServiceProvider);
    final pending = await service.consumePending();
    if (pending != null && mounted) _handleShare(pending);

    _shareSub = service.stream.listen((payload) {
      if (mounted) _handleShare(payload);
    });
  }

  void _handleShare(SharePayload payload) {
    final notifier = ref.read(sendProvider.notifier);
    if (payload.paths.isNotEmpty) {
      notifier.addFiles(payload.paths);
    }
    if (payload.text != null && payload.text!.isNotEmpty) {
      notifier.setText(payload.text!);
    }
    setState(() => _index = 0);
    showGatorSnackBar(context, 'Added shared content to Send queue');
  }

  void _applySettingsToPages(Map<String, dynamic> settings) {
    ref.read(sendProvider.notifier).configure(
          showShellOutput: settings['show_shell_output'] as bool? ?? false,
          showQrImage: settings['show_qr_image'] as bool? ?? true,
        );
    ref.read(receiveProvider.notifier).configure(
          showShellOutput: settings['show_shell_output'] as bool? ?? false,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider).whenData(_applySettingsToPages);

    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actionsPadding: const EdgeInsets.only(right: 8),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Menu',
            onSelected: (value) {
              switch (value) {
                case 'preferences':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PreferencesPage(),
                    ),
                  );
                case 'about':
                  _showAbout(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'preferences',
                child: Text('Preferences'),
              ),
              const PopupMenuItem(value: 'about', child: Text('About')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [SendPage(), ReceivePage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.upload_outlined),
            selectedIcon: Icon(Icons.upload),
            label: 'Send',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Receive',
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: appName,
      applicationVersion: appVersion,
      applicationLegalese: 'GPL-3.0-or-later',
      children: [
        const Text(
          'Encrypted P2P file transfer powered by croc.',
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://github.com/schollz/croc'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('croc on GitHub'),
        ),
      ],
    );
  }
}