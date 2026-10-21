import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_design_tokens.dart';

/// Where an action button is in its run: waiting to be pressed, working, or
/// finished.
enum ActionPhase { idle, busy, done }

/// True when the platform asks for reduced motion; feedback then changes
/// state without animating.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// The inside of an action button: the label while idle, a spinner with
/// [busyLabel] while working, and a check with [doneLabel] once finished.
/// The change cross-fades and the button resizes smoothly to fit.
class ActionButtonContent extends StatelessWidget {
  const ActionButtonContent({
    super.key,
    required this.phase,
    required this.label,
    this.busyLabel,
    this.doneLabel,
    this.icon,
    this.color,
  });

  final ActionPhase phase;
  final String label;
  final String? busyLabel;
  final String? doneLabel;
  final IconData? icon;

  /// Spinner colour; defaults to the button's text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    final foreground = color ?? DefaultTextStyle.of(context).style.color;

    final Widget child = switch (phase) {
      ActionPhase.idle => Row(
        key: const ValueKey('idle'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
          Text(label),
        ],
      ),
      ActionPhase.busy => Row(
        key: const ValueKey('busy'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foreground,
            ),
          ),
          const SizedBox(width: 10),
          Text(busyLabel ?? label),
        ],
      ),
      ActionPhase.done => Row(
        key: const ValueKey('done'),
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? 1 : 0.4, end: 1),
            duration: still ? Duration.zero : const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: const Icon(Icons.check_rounded, size: 18),
          ),
          const SizedBox(width: 8),
          Text(doneLabel ?? label),
        ],
      ),
    };

    return AnimatedSize(
      duration: still ? Duration.zero : AppDurations.normal,
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: still ? Duration.zero : AppDurations.fast,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Shakes its child sideways each time [trigger] changes, to show that an
/// action failed. Skipped when reduced motion is on.
class ShakeOnChange extends StatefulWidget {
  const ShakeOnChange({super.key, required this.trigger, required this.child});

  final Object? trigger;
  final Widget child;

  @override
  State<ShakeOnChange> createState() => _ShakeOnChangeState();
}

class _ShakeOnChangeState extends State<ShakeOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(ShakeOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && !reduceMotion(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Three decaying swings.
        final dx = math.sin(t * math.pi * 6) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// Dips its child slightly while it is pressed, so a tap is felt before the
/// action's result arrives. The tap itself still goes to the child.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return Listener(
      onPointerDown: widget.enabled ? (_) => _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && widget.enabled && !still ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A small modal that shows [message] with a spinner while [action] runs, for
/// actions that have no confirm step of their own (restore, transfer). It
/// cannot be dismissed until the action finishes, so the action cannot be
/// started twice. Returns the action's result and rethrows its error.
class AppProgressDialog extends StatelessWidget {
  const AppProgressDialog({super.key, required this.message});

  final String message;

  static Future<T> run<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() action,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AppProgressDialog(message: message),
      ),
    );
    try {
      return await action();
    } finally {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark
          ? AppColors.modalSurface
          : AppColors.lightModalSurface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accent(isDark),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Turns an error into one sentence for the person using the app: the
/// message of app errors, without Dart's "Exception:" prefixes.
String describeActionError(Object error) {
  final text = switch (error) {
    StateError(:final message) => message,
    ArgumentError(:final message) => '$message',
    _ => error.toString(),
  };
  return text.replaceFirst(RegExp(r'^(Exception|Bad state|Error):\s*'), '');
}
