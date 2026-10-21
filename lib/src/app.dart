import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:toastification/toastification.dart';
import 'routing/app_router.dart';
import 'providers/providers.dart';
import 'services/public_branding_service.dart';
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

class MedSentryApp extends ConsumerStatefulWidget {
  const MedSentryApp({super.key});

  @override
  ConsumerState<MedSentryApp> createState() => _MedSentryAppState();
}

class _MedSentryAppState extends ConsumerState<MedSentryApp> {
  @override
  void initState() {
    super.initState();
    // Warm up the background synchronization service once at startup without rebuilding root
    ref.read(syncServiceProvider);
    unawaited(refreshPublicBranding(ref.read(databaseProvider)));
  }

  @override
  Widget build(BuildContext context) {
    final appName = ref.watch(
      systemSettingsProvider.select(
        (s) => s.valueOrNull?.appName ?? 'MedSentry',
      ),
    );
    void syncBrowserBrand() {
      final logo = ref.read(brandLogoDataUriProvider).valueOrNull;
      final name =
          ref.read(systemSettingsProvider).valueOrNull?.appName ?? 'MedSentry';
      if (logo != null) _updateBrowserBrand(name, logo);
    }

    ref.listen(systemSettingsProvider, (_, _) => syncBrowserBrand());
    ref.listen(brandLogoDataUriProvider, (_, _) => syncBrowserBrand());
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
        title: appName,
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
