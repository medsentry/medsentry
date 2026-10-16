import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:toastification/toastification.dart';
import 'routing/app_router.dart';
import 'providers/providers.dart';
import 'theme/shadcn_theme.dart';
import 'utils/browser_branding_stub.dart'
    if (dart.library.js_interop) 'utils/browser_branding_web.dart'
    as browser_branding;

String? _lastBrowserAppName;
String? _lastBrowserLogoDataUri;

void _updateBrowserBrand(String appName, String logoDataUri) {
  if (_lastBrowserAppName == appName &&
      _lastBrowserLogoDataUri == logoDataUri) {
    return;
  }
  _lastBrowserAppName = appName;
  _lastBrowserLogoDataUri = logoDataUri;
  browser_branding.updateBrowserBrand(
    appName: appName,
    logoDataUri: logoDataUri,
  );
}

class MedSentryApp extends ConsumerWidget {
  const MedSentryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncServiceStateProvider);
    ref.listen(systemSettingsProvider, (_, next) {
      next.whenData(
        (settings) =>
            _updateBrowserBrand(settings.appName, settings.logoDataUri),
      );
    });
    final settings = ref.watch(systemSettingsProvider).valueOrNull;
    if (settings != null) {
      _updateBrowserBrand(settings.appName, settings.logoDataUri);
    }
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
        title: settings?.appName ?? 'MedSentry',
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
