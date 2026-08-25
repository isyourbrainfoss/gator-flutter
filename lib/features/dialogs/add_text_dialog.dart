import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<String?> showAddTextDialog(BuildContext context, {String initial = ''}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _AddTextDialog(initial: initial),
  );
}

class _AddTextDialog extends StatefulWidget {
  const _AddTextDialog({required this.initial});
  final String initial;

  @override
  State<_AddTextDialog> createState() => _AddTextDialogState();
}

class _AddTextDialogState extends State<_AddTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.5;
    return AlertDialog(
      icon: const Icon(Icons.notes),
      title: const Text('Add Text to Send'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH, maxWidth: 480),
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 4,
          maxLines: null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter text to send…',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data?.text != null) {
              _controller.text = data!.text!;
              setState(() {});
            }
          },
          child: const Text('Paste'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
