import 'dart:ui' as ui;
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'src/preferences.dart';
import 'src/router.dart';

class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<ui.PointerDeviceKind> get dragDevices => {
        ui.PointerDeviceKind.touch,
        ui.PointerDeviceKind.mouse,
        ui.PointerDeviceKind.trackpad,
      };
}

/// Root widget of Atrium. Wires the theme (with Android dynamic color), the
/// persisted theme-mode preference, and the GoRouter.
class AtriumApp extends ConsumerWidget {
  const AtriumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode =
        ref.watch(preferencesProvider.select((Preferences p) => p.themeMode));
    final bool oledBlack =
        ref.watch(preferencesProvider.select((Preferences p) => p.oledBlackEnabled));
    final GoRouter router = ref.watch(routerProvider);

    return AtriumTheme.withDynamicColor(
      builder: (ColorScheme? lightScheme, ColorScheme? darkScheme) {
        return MaterialApp.router(
          title: 'Atrium',
          debugShowCheckedModeBanner: false,
          scrollBehavior: _AppScrollBehavior(),
          theme: AtriumTheme.light(lightScheme),
          darkTheme: AtriumTheme.dark(darkScheme, oledBlack: oledBlack),
          themeMode: themeMode,
          routerConfig: router,
        );
      },
    );
  }
}
