import 'package:flutter/material.dart';

Future<bool> showTransferCompleteDialog(BuildContext context) {
  return showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Transfer Complete'),
          content: const Text('Files received successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Folder'),
            ),
          ],
        ),
      ).then((v) => v ?? false);
}