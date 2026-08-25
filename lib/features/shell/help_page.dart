import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Send', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Add files, a folder, or text. Tap Start Transfer. Share the code '
            'or QR with the other person. Codes look like word-word-word.',
          ),
          const SizedBox(height: 16),
          Text('Receive', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Enter or paste that code (spaces are fine) and tap Start Receiving. '
            'You can also scan the sender’s QR.',
          ),
          const SizedBox(height: 16),
          Text('Exclude', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Exclude skips named files or folders when sending a larger folder.',
          ),
          const SizedBox(height: 16),
          Text('Keyboard (Linux)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Ctrl+1 Send · Ctrl+2 Receive · Ctrl+, Preferences · '
            'Ctrl+C copy send code · Escape cancels a dialog.',
          ),
        ],
      ),
    );
  }
}
