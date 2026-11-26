import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/demo/demo_overlay.dart';
import '../ui/tema/tema.dart';
import 'router.dart';

class LavanderonApp extends ConsumerWidget {
  const LavanderonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Lavanderon',
        debugShowCheckedModeBanner: false,
        theme: temaLavanderon(),
        routerConfig: ref.watch(routerProvider),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => DemoOverlay(child: child ?? const SizedBox()),
      );
}
