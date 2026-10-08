import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:toastification/toastification.dart';
import 'routing/app_router.dart';
import 'providers/providers.dart';
import 'theme/shadcn_theme.dart';

class MedSentryApp extends ConsumerWidget {
  const MedSentryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncServiceStateProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accentTheme = ref.watch(accentThemeProvider);

    final shadThemeLight = buildShadcnTheme(
      Brightness.light,
      accentTheme: accentTheme,
    );
    final shadThemeDark = buildShadcnTheme(
      Brightness.dark,
      accentTheme: accentTheme,
    );

    return ToastificationWrapper(
      child: MaterialApp.router(
        title: 'MedSentry',
        debugShowCheckedModeBanner: false,
        theme: buildMedSentryTheme(Brightness.light, accentTheme: accentTheme),
        darkTheme: buildMedSentryTheme(
          Brightness.dark,
          accentTheme: accentTheme,
        ),
        themeMode: themeMode,
        routerConfig: router,
        builder: (context, child) {
          return shad.ShadcnLayer(
            theme: shadThemeLight,
            darkTheme: shadThemeDark,
            themeMode: toShadThemeMode(themeMode),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
