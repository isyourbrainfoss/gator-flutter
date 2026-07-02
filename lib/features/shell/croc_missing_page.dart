import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown when the bundled croc binary cannot be located or verified.
class CrocMissingPage extends StatelessWidget {
  const CrocMissingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                'The croc command-line tool is required to use this app.\n'
                'Please reinstall or rebuild with bundled croc assets.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://github.com/schollz/croc'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Open croc GitHub page'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}