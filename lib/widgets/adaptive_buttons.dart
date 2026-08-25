import 'package:flutter/material.dart';

/// Drops button labels when horizontal space is too tight for icon + text.
class AdaptiveFilledButton extends StatelessWidget {
  const AdaptiveFilledButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.tooltip,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final String tooltip;
  final ButtonStyle? style;

  static const compactBreakpoint = 140.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final button = compact
            ? FilledButton(
                onPressed: onPressed,
                style: (style ?? const ButtonStyle()).copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(48, 40)),
                ),
                child: icon,
              )
            : FilledButton.icon(
                onPressed: onPressed,
                icon: icon,
                label: label,
                style: style,
              );
        return Tooltip(message: tooltip, child: button);
      },
    );
  }
}

/// Outlined variant of [AdaptiveFilledButton].
class AdaptiveOutlinedButton extends StatelessWidget {
  const AdaptiveOutlinedButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.tooltip,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final String tooltip;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < AdaptiveFilledButton.compactBreakpoint;
        final button = compact
            ? OutlinedButton(
                onPressed: onPressed,
                style: (style ?? const ButtonStyle()).copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(48, 40)),
                ),
                child: icon,
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: icon,
                label: label,
                style: style,
              );
        return Tooltip(message: tooltip, child: button);
      },
    );
  }
}
