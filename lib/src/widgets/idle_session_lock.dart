import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';

/// Locks the session after the inactivity period set in Settings
/// (Session timeout), so an unattended clinic computer does not stay signed
/// in. Any pointer or keyboard input anywhere in the app counts as activity,
/// including inside dialogs. Locking keeps the account available for PIN or
/// password unlock, exactly like the manual Lock action.
class IdleSessionLock extends ConsumerStatefulWidget {
  const IdleSessionLock({super.key, required this.child});

  final Widget child;

  /// How often inactivity is checked. Short enough to lock within a minute
  /// of the deadline, cheap enough to run continuously.
  static const Duration checkInterval = Duration(seconds: 20);

  @override
  ConsumerState<IdleSessionLock> createState() => _IdleSessionLockState();
}

class _IdleSessionLockState extends ConsumerState<IdleSessionLock> {
  late DateTime _lastActivity;
  Timer? _checkTimer;
  bool _locking = false;

  @override
  void initState() {
    super.initState();
    _lastActivity = clock.now();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
    _checkTimer = Timer.periodic(
      IdleSessionLock.checkInterval,
      (_) => _check(),
    );
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _onPointer(PointerEvent event) => _lastActivity = clock.now();

  bool _onKey(KeyEvent event) {
    _lastActivity = clock.now();
    return false;
  }

  Future<void> _check() async {
    if (_locking || !mounted) return;
    final settings = ref.read(systemSettingsProvider).valueOrNull;
    final minutes = settings?.sessionTimeoutMinutes ?? 0;
    if (minutes <= 0) return;
    if (clock.now().difference(_lastActivity) < Duration(minutes: minutes)) {
      return;
    }

    _locking = true;
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      await ref.read(authRepositoryProvider).lockSession(userId: user.id);
      ref.read(currentUserProvider.notifier).state = null;
      if (mounted) GoRouter.of(context).go('/login?locked=1');
    } finally {
      _locking = false;
      _lastActivity = clock.now();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
