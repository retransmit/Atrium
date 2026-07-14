import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'src/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Use the classic pull-to-refresh style globally.
  EasyRefresh.defaultHeaderNotifier.value = const ClassicHeader();
  EasyRefresh.defaultFooterNotifier.value = const ClassicFooter();
  // Never fetch fonts from the network; only bundled assets are used.
  GoogleFonts.config.allowRuntimeFetching = false;
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final List<Override> overrides = await bootstrap();

  runApp(ProviderScope(overrides: overrides, child: const AtriumApp()));
}
