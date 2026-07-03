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
                'Gator bundles croc inside the app (a separate Termux install '
                'cannot be used due to Android sandboxing).\n\n'
                'The bundled binary failed to start. Try reinstalling from '
                'Obtainium, or report an issue if this persists.',
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