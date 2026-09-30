import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/config/supabase_config.dart';
import 'src/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('UNCAUGHT ASYNC ERROR: $error\n$stack');
    return true;
  };

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    final isConnected = await SupabaseService.testConnection();
    if (isConnected) {
      debugPrint('Supabase connected successfully');
    } else {
      debugPrint('Supabase connection failed');
    }
  } catch (e) {
    debugPrint('Supabase init warning: $e');
  }

  runApp(const ProviderScope(child: MedSentryApp()));
}
