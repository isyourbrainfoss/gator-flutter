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
        if (compact) {
          return IconButton.filled(
            onPressed: onPressed,
            icon: icon,
            tooltip: tooltip,
          );
        }
        return FilledButton.icon(
          onPressed: onPressed,
          icon: icon,
          label: label,
          style: style,
        );
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
        if (compact) {
          return IconButton.outlined(
            onPressed: onPressed,
            icon: icon,
            tooltip: tooltip,
            style: style != null
                ? IconButton.styleFrom(
                    foregroundColor: style!.foregroundColor?.resolve({}),
                  )
                : null,
          );
        }
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon,
          label: label,
          style: style,
        );
      },
    );
  }
}