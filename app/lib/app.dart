import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/custom_theme_providers.dart';
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
    final String? fontFamily =
        ref.watch(preferencesProvider.select((Preferences p) => p.fontFamily));
    final GoRouter router = ref.watch(routerProvider);

    // Mirror the active profile's global headers into the networking layer
    // so every instance request carries them. Writes are guarded by a map
    // compare so redundant profile refreshes don't churn the Dio providers.
    void syncGlobalHeaders(Profile? profile) {
      final Map<String, String> next =
          profile?.globalHeaders ?? const <String, String>{};
      if (!mapEquals(ref.read(globalHeadersProvider), next)) {
        ref.read(globalHeadersProvider.notifier).state = next;
      }
    }

    ref.listen<Profile?>(
      activeProfileProvider,
      (Profile? prev, Profile? next) => syncGlobalHeaders(next),
    );
    // One-time initial set so headers apply on cold start, not only when the
    // profile changes after this widget is built.
    syncGlobalHeaders(ref.read(activeProfileProvider));

    String? resolvedFontFamily = fontFamily;
    if (fontFamily != null && fontFamily != 'JetBrainsMono Nerd Font') {
      try {
        resolvedFontFamily = GoogleFonts.getFont(fontFamily).fontFamily;
      } catch (_) {}
    }

    final Preferences prefs = ref.watch(preferencesProvider);
    final (ColorScheme customLight, ColorScheme customDark) = ref.watch(customColorSchemeProvider);

    return AtriumTheme.withDynamicColor(
      builder: (ColorScheme? lightScheme, ColorScheme? darkScheme) {
        final ColorScheme activeLight = prefs.themeSource == ThemeSource.system
            ? (lightScheme ?? ColorScheme.fromSeed(seedColor: AtriumTheme.seed))
            : customLight;
        final ColorScheme activeDark = prefs.themeSource == ThemeSource.system
            ? (darkScheme ?? ColorScheme.fromSeed(seedColor: AtriumTheme.seed, brightness: Brightness.dark))
            : customDark;

        return MaterialApp.router(
          title: 'Atrium',
          debugShowCheckedModeBanner: false,
          theme: AtriumTheme.light(activeLight, fontFamily: resolvedFontFamily),
          darkTheme: AtriumTheme.dark(activeDark, fontFamily: resolvedFontFamily),
          themeMode: themeMode,
          routerConfig: router,
          // Overlay the opt-in biometric lock above every route.
          builder: (BuildContext context, Widget? child) =>
              _BiometricLockGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// Wraps the routed UI in the opt-in biometric / device-credential lock.
///
/// When [Preferences.biometricEnabled] is on, the app locks at launch and again
/// whenever it returns from the background, prompting via [BiometricGate]. The
/// lock overlay sits above the router so no screen is reachable until unlocked.
class _BiometricLockGate extends ConsumerStatefulWidget {
  const _BiometricLockGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends ConsumerState<_BiometricLockGate>
    with WidgetsBindingObserver {
  final BiometricGate _gate = BiometricGate();
  bool _locked = false;
  bool _authenticating = false;
  bool _promptOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lock synchronously so the UI never flashes before the prompt.
    _locked = ref.read(preferencesProvider).biometricEnabled;
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptUnlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ignore the lifecycle blips caused by the system auth prompt itself.
    if (_authenticating) {
      return;
    }
    if (!ref.read(preferencesProvider).biometricEnabled) {
      return;
    }
    if (state == AppLifecycleState.paused) {
      _promptOnResume = true;
      if (!_locked && mounted) {
        setState(() => _locked = true);
      }
    } else if (state == AppLifecycleState.resumed &&
        _locked &&
        _promptOnResume) {
      _promptOnResume = false;
      _promptUnlock();
    }
  }

  Future<void> _promptUnlock() async {
    if (_authenticating || !mounted) {
      return;
    }
    setState(() => _authenticating = true);
    final bool ok = await _gate.authenticate();
    if (!mounted) {
      return;
    }
    setState(() {
      _authenticating = false;
      if (ok) {
        _locked = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = ref.watch(
      preferencesProvider.select((Preferences p) => p.biometricEnabled),
    );
    return Stack(
      children: <Widget>[
        widget.child,
        if (enabled && _locked)
          _LockScreen(
            authenticating: _authenticating,
            onUnlock: _promptUnlock,
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.authenticating, required this.onUnlock});

  final bool authenticating;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Atrium is locked', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Unlock to continue',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            if (authenticating)
              const ExpressiveProgressIndicator()
            else
              FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
          ],
        ),
      ),
    );
  }
}
