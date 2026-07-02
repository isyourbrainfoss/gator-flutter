import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gator/widgets/gator_snackbar.dart';

Future<void> showReceivedTextDialog(BuildContext context, String text) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Received Text'),
      content: SizedBox(
        width: double.maxFinite,
        child: SelectableText(text),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              showGatorSnackBar(context, 'Copied to clipboard');
            }
          },
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}