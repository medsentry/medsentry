import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/system_settings.dart';
import '../providers/providers.dart';
import 'system_logo.dart';

class StartupLoadingScreen extends ConsumerWidget {
  const StartupLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SystemLogo(
              dataUri: settings.logoDataUri,
              size: 56,
              backgroundColor: AppColors.primaryEmeraldSubtle,
              iconColor: AppColors.primaryEmerald,
              iconSize: 28,
              borderRadius: AppRadius.lg,
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Starting MedSentry…'),
          ],
        ),
      ),
    );
  }
}
