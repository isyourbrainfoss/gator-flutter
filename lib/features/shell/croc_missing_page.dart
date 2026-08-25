import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown when the bundled croc binary cannot be located or verified.
class CrocMissingPage extends StatelessWidget {
  const CrocMissingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final linux = !kIsWeb && Platform.isLinux;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 72, color: colorScheme.error),
              const SizedBox(height: 24),
              Text(
                'croc not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                linux
                    ? 'Gator needs croc 11+ to transfer files.\n\n'
                        'Install croc on PATH, place a croc binary next to the '
                        'Gator executable, or use the Flatpak which bundles it.'
                    : 'Gator bundles croc inside the app (a separate Termux install '
                        'cannot be used due to Android sandboxing).\n\n'
                        'The transfer engine could not start on this device. '
                        'Update to the latest version via Obtainium, or report an '
                        'issue if this persists after updating.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => launchUrl(
                  Uri.parse(
                    linux
                        ? 'https://github.com/isyourbrainfoss/gator-flutter'
                        : 'https://github.com/schollz/croc',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(linux ? 'Open Gator on GitHub' : 'Open croc GitHub page'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
