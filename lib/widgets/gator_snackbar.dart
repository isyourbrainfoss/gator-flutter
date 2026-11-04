import 'package:flutter/material.dart';

/// Root messenger so dialogs can toast above the modal.
final gatorScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Show a short snackbar (replaces GTK Adw.Toast).
void showGatorSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
  SnackBarAction? action,
}) {
  final messenger =
      gatorScaffoldMessengerKey.currentState ?? ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final scheme = Theme.of(context).colorScheme;
  messenger.hideCurrentSnackBar();
  final wide = MediaQuery.sizeOf(context).width > 520;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: error ? TextStyle(color: scheme.onErrorContainer) : null,
      ),
      duration: Duration(seconds: action == null ? 3 : 6),
      action: action,
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
      width: wide ? 420 : null,
      backgroundColor: error ? scheme.errorContainer : null,
    ),
  );
}
