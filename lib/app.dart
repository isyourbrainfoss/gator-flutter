import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/core/constants.dart';
import 'package:gator/core/theme/gator_theme.dart';
import 'package:gator/features/shell/croc_missing_page.dart';
import 'package:gator/features/shell/gator_shell.dart';
import 'package:gator/providers/croc_provider.dart';
import 'package:gator/providers/settings_provider.dart';

class GatorApp extends ConsumerWidget {
  const GatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final crocStatus = ref.watch(crocAvailableProvider);

    final themeMode = settings.when(
      data: (s) => switch (s.colorScheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      loading: () => ThemeMode.system,
      error: (_, _) => ThemeMode.system,
    );

    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: GatorTheme.light(),
      darkTheme: GatorTheme.dark(),
      home: crocStatus.when(
        data: (version) => version != null
            ? const GatorShell()
            : const CrocMissingPage(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const CrocMissingPage(),
      ),
    );
  }
}