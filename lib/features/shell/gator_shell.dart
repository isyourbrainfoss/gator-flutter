import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gator/core/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/features/preferences/preferences_page.dart';
import 'package:gator/features/receive/receive_controller.dart';
import 'package:gator/features/receive/receive_notifier.dart';
import 'package:gator/features/send/send_controller.dart';
import 'package:gator/features/send/send_notifier.dart';
import 'package:gator/features/shell/help_page.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/providers/app_version_provider.dart';
import 'package:gator/features/receive/receive_page.dart';
import 'package:gator/features/send/send_page.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/providers/share_intent_provider.dart';
import 'package:gator/services/share_intent_service.dart';
import 'package:gator/widgets/gator_snackbar.dart';

const _wideBreakpoint = 800.0;

/// Main app shell with bottom navigation between Send and Receive tabs.
class GatorShell extends ConsumerStatefulWidget {
  const GatorShell({super.key});

  @override
  ConsumerState<GatorShell> createState() => _GatorShellState();
}

class _GatorShellState extends ConsumerState<GatorShell>
    with WidgetsBindingObserver {
  int _index = 0;
  StreamSubscription<SharePayload>? _shareSub;
  SharePayload? _queuedShare;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initShareIntentHandling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    GatorLog.d('GatorShell', 'App lifecycle: $state');
    final sending = ref.read(sendProvider).transferring;
    final receiving = ref.read(receiveProvider).transferring;
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        (sending || receiving) &&
        mounted) {
      showGatorSnackBar(
        context,
        'Keep Gator open until the transfer finishes.',
      );
    }
    if (state == AppLifecycleState.detached) {
      unawaited(ref.read(sendControllerProvider).cancelTransfer());
      unawaited(ref.read(receiveControllerProvider).cancelTransfer());
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _initShareIntentHandling() async {
    final service = ref.read(shareIntentServiceProvider);
    try {
      final pending = await service.consumePending();
      if (pending != null && mounted) _handleShare(pending);
    } catch (e, st) {
      GatorLog.e('GatorShell', 'consumePending failed', e, st);
    }

    _shareSub = service.stream.listen(
      (payload) {
        if (mounted) _handleShare(payload);
      },
      onError: (e, st) {
        GatorLog.e('GatorShell', 'share stream error', e, st);
      },
    );
  }

  void _handleShare(SharePayload payload) {
    if (payload.isEmpty) return;
    if (ref.read(sendProvider).transferring) {
      _queuedShare = payload;
      showGatorSnackBar(context, 'Wait for the current send to finish.');
      return;
    }
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

  void _applySettingsToPages(GatorSettings settings) {
    ref.read(sendProvider.notifier).configure(
          showShellOutput: settings.showShellOutput,
          showQrImage: settings.showQrImage,
        );
    ref.read(receiveProvider.notifier).configure(
          showShellOutput: settings.showShellOutput,
        );
  }

  void _openPreferences() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PreferencesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sendControllerProvider);
    ref.watch(receiveControllerProvider);

    ref.listen(settingsProvider, (previous, next) {
      next.whenData(_applySettingsToPages);
    });

    ref.listen(sendProvider.select((s) => s.transferring), (prev, next) {
      if (prev == true && next == false && _queuedShare != null) {
        final payload = _queuedShare!;
        _queuedShare = null;
        _handleShare(payload);
      }
    });

    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final body = IndexedStack(
      index: _index,
      children: const [SendPage(), ReceivePage()],
    );

    final destinations = const [
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
    ];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            setState(() => _index = 0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            setState(() => _index = 1),
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            _openPreferences,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): () {
          final code = ref.read(sendProvider).code;
          if (code.isEmpty) return;
          Clipboard.setData(ClipboardData(text: code));
          showGatorSnackBar(context, 'Code copied');
        },
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () {
          if (_index != 1) return;
          Clipboard.getData(Clipboard.kTextPlain).then((data) {
            final text = data?.text;
            if (text == null || text.trim().isEmpty || !mounted) return;
            ref.read(receiveProvider.notifier).pasteCode(text);
          });
        },
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (_index == 0) {
            unawaited(ref.read(sendControllerProvider).startTransfer());
          } else {
            unawaited(ref.read(receiveControllerProvider).startTransfer());
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(appName),
            actionsPadding: const EdgeInsets.only(right: 8),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Preferences and About',
                onSelected: (value) {
                  switch (value) {
                    case 'preferences':
                      _openPreferences();
                    case 'help':
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpPage()),
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
                  const PopupMenuItem(value: 'help', child: Text('Help')),
                  const PopupMenuItem(value: 'about', child: Text('About')),
                ],
              ),
            ],
          ),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.upload_outlined),
                          selectedIcon: Icon(Icons.upload),
                          label: Text('Send'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.download_outlined),
                          selectedIcon: Icon(Icons.download),
                          label: Text('Receive'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: destinations,
                ),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final versionAsync = ref.read(appVersionProvider);
    final version = versionAsync.value;

    showAboutDialog(
      context: context,
      applicationName: appName,
      applicationVersion: version,
      applicationLegalese: 'GPL-3.0-or-later · croc $crocVersion',
      children: [
        const Text(
          'Send: add files → Start Transfer → share the code or QR.\n'
          'Receive: enter or paste that code → Start Receiving.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Linux: Ctrl+1 Send, Ctrl+2 Receive, Ctrl+, Preferences.',
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://github.com/isyourbrainfoss/gator-flutter'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Gator on GitHub'),
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
