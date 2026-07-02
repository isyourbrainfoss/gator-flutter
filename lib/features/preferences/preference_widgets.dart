import 'package:flutter/material.dart';

/// Section title used to group preference rows.
class PreferenceSectionHeader extends StatelessWidget {
  const PreferenceSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

/// Text preference row that saves when the user submits or finishes editing.
class PreferenceTextField extends StatefulWidget {
  const PreferenceTextField({
    super.key,
    required this.title,
    required this.value,
    required this.onSubmitted,
    this.subtitle,
    this.obscure = false,
    this.keyboardType,
  });

  final String title;
  final String? subtitle;
  final String value;
  final void Function(String) onSubmitted;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  State<PreferenceTextField> createState() => _PreferenceTextFieldState();
}

class _PreferenceTextFieldState extends State<PreferenceTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(PreferenceTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => widget.onSubmitted(_controller.text);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) Text(widget.subtitle!),
          TextField(
            controller: _controller,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            decoration: const InputDecoration(isDense: true),
            onSubmitted: (_) => _save(),
            onEditingComplete: _save,
          ),
        ],
      ),
    );
  }
}

/// Boolean preference row backed by [SwitchListTile].
class PreferenceSwitch extends StatelessWidget {
  const PreferenceSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Hash algorithm dropdown matching GTK options plus xxhash.
class PreferenceHashDropdown extends StatelessWidget {
  const PreferenceHashDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final void Function(String) onChanged;

  static const _options = <String, String>{
    '': 'Default (croc)',
    'imohash': 'imohash',
    'md5': 'md5',
    'xxhash': 'xxhash',
  };

  String get _dropdownValue {
    final h = value.trim();
    return _options.containsKey(h) ? h : '';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Hash algorithm'),
      trailing: DropdownButton<String>(
        value: _dropdownValue,
        items: _options.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}