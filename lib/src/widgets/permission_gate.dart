import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

import '../models/user.dart';

/// Gates UI by role permission.
class PermissionGate extends ConsumerWidget {
  final bool Function(User user) permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user != null && permission(user)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}
