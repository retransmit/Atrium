import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'src/preferences.dart';
import 'src/router.dart';

/// Root widget of Atrium. Wires the theme (with Android dynamic color), the
/// persisted theme-mode preference, and the GoRouter.
class AtriumApp extends ConsumerWidget {
  const AtriumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode =
        ref.watch(preferencesProvider.select((Preferences p) => p.themeMode));
    final GoRouter router = ref.watch(routerProvider);

    return AtriumTheme.withDynamicColor(
      builder: (ColorScheme? lightScheme, ColorScheme? darkScheme) {
        return MaterialApp.router(
          title: 'Atrium',
          debugShowCheckedModeBanner: false,
          theme: AtriumTheme.light(lightScheme),
          darkTheme: AtriumTheme.dark(darkScheme),
          themeMode: themeMode,
          routerConfig: router,
        );
      },
    );
  }
}
