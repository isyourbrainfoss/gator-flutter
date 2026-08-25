import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/core/theme/gator_theme.dart';
import 'package:gator/features/shell/croc_missing_page.dart';
import 'package:gator/features/shell/gator_shell.dart';
import 'package:gator/providers/croc_provider.dart';
import 'package:gator/providers/settings_provider.dart';
import 'package:gator/widgets/gator_snackbar.dart';

class GatorApp extends ConsumerWidget {
  const GatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      settingsProvider.select(
        (s) => s.maybeWhen(
          data: (v) => switch (v.colorScheme) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          orElse: () => ThemeMode.system,
        ),
      ),
    );
    final crocStatus = ref.watch(crocAvailableProvider);

    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: gatorScaffoldMessengerKey,
      themeMode: themeMode,
      theme: GatorTheme.light(),
      darkTheme: GatorTheme.dark(),
      home: crocStatus.when(
        data: (path) =>
            path != null ? const GatorShell() : const CrocMissingPage(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const CrocMissingPage(),
      ),
    );
  }
}
