import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medsentry/src/app.dart';
import 'package:medsentry/src/config/supabase_config.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final secureValues = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final arguments = Map<String, dynamic>.from(
            call.arguments as Map? ?? {},
          );
          final key = arguments['key'] as String?;

          switch (call.method) {
            case 'read':
              return key == null ? null : secureValues[key];
            case 'write':
              if (key != null) secureValues[key] = arguments['value'] as String;
              return null;
            case 'delete':
              if (key != null) secureValues.remove(key);
              return null;
            case 'deleteAll':
              secureValues.clear();
              return null;
            case 'readAll':
              return secureValues;
            case 'containsKey':
              return key != null && secureValues.containsKey(key);
            default:
              return null;
          }
        });
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    await Supabase.instance.client.auth.signOut();
    await const FlutterSecureStorage().delete(key: 'medsentry.current_user_id');
  });

  testWidgets('shows the login screen on app start', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MedSentryApp()));
    await tester.pump();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
