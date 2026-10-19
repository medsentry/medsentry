import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/system_settings.dart';
import 'package:medsentry/src/providers/providers.dart';
import 'package:medsentry/src/widgets/startup_loading_screen.dart';
import 'package:medsentry/src/widgets/system_logo.dart';

void main() {
  testWidgets('shows the saved system logo while startup is loading', (
    tester,
  ) async {
    const logoDataUri = 'data:image/png;base64,aGVsbG8=';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemSettingsProvider.overrideWith(
            (ref) =>
                Future.value(const SystemSettings(logoDataUri: logoDataUri)),
          ),
        ],
        child: const MaterialApp(home: StartupLoadingScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Starting MedSentry…'), findsOneWidget);
    expect(
      tester.widget<SystemLogo>(find.byType(SystemLogo)).dataUri,
      logoDataUri,
    );
  });
}
