import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'system_logo.dart';

class StartupLoadingScreen extends ConsumerWidget {
  const StartupLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logo = ref.watch(brandLogoDataUriProvider).valueOrNull ?? '';

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SystemLogo(
              dataUri: logo,
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
