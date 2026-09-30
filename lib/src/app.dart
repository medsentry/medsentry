import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import 'routing/app_router.dart';
import 'providers/providers.dart';

class MedSentryApp extends ConsumerWidget {
  const MedSentryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ToastificationWrapper(
      child: MaterialApp.router(
        title: 'MedSentry',
        debugShowCheckedModeBanner: false,
        theme: buildMedSentryTheme(Brightness.light),
        darkTheme: buildMedSentryTheme(Brightness.dark),
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}
