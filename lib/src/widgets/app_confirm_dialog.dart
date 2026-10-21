import 'package:flutter/material.dart';

import '../config/app_design_tokens.dart';
import '../utils/context_extensions.dart';
import 'action_feedback.dart';

/// Semantic alert level for [AppConfirmDialog].
enum ConfirmDialogType { info, warning, danger }

/// A modern, consistent confirmation dialog widget for MedSentry EMR.
/// Replaces ad-hoc AlertDialogs for destructive or impactful user actions.
///
/// Given an [action], the dialog runs it itself: the confirm button shows a
/// spinner while it works and a check when it is done, Cancel and the barrier
/// are locked meanwhile so it cannot run twice, and a failure shakes the
/// dialog and shows the error inside it so the person can retry or cancel.
class AppConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final Widget? content;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final IconData? icon;
  final ConfirmDialogType type;
  final double maxWidth;

  /// Work to run when confirmed. Without it the dialog only reports the
  /// choice and the caller does the work.
  final Future<void> Function()? action;

  /// Confirm button text while [action] runs, e.g. "Deleting…".
  final String? busyLabel;

  /// Confirm button text once [action] succeeded, e.g. "Deleted".
  final String? doneLabel;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.content,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.icon,
    this.type = ConfirmDialogType.warning,
    this.maxWidth = 480,
    this.action,
    this.busyLabel,
    this.doneLabel,
  });

  /// Displays the dialog and returns true if confirmed (and, with an
  /// [action], once that action has succeeded), false otherwise.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    Widget? content,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
    ConfirmDialogType type = ConfirmDialogType.warning,
    double maxWidth = 480,
    Future<void> Function()? action,
    String? busyLabel,
    String? doneLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: action == null,
      builder: (ctx) => AppConfirmDialog(
        title: title,
        message: message,
        content: content,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        icon: icon,
        type: type,
        maxWidth: maxWidth,
        action: action,
        busyLabel: busyLabel,
        doneLabel: doneLabel,
      ),
    );
    return result ?? false;
  }

  @override
  State<AppConfirmDialog> createState() => _AppConfirmDialogState();
}

class _AppConfirmDialogState extends State<AppConfirmDialog> {
  ActionPhase _phase = ActionPhase.idle;
  String? _error;
  int _failures = 0;

  bool get _locked => _phase != ActionPhase.idle;

  Future<void> _confirm() async {
    final action = widget.action;
    if (action == null) {
      Navigator.of(context).pop(true);
      return;
    }
    if (_locked) return;
    setState(() {
      _phase = ActionPhase.busy;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _phase = ActionPhase.done);
      // Long enough to see the check before the dialog closes.
      await Future<void>.delayed(
        reduceMotion(context)
            ? const Duration(milliseconds: 150)
            : const Duration(milliseconds: 550),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = ActionPhase.idle;
        _error = describeActionError(error);
        _failures++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveType = widget.isDestructive
        ? ConfirmDialogType.danger
        : widget.type;

    final Color badgeColor;
    final Color badgeBg;
    final Color badgeBorder;
    final IconData defaultIcon;

    switch (effectiveType) {
      case ConfirmDialogType.danger:
        badgeColor = context.semanticColors.critical;
        badgeBg = context.semanticColors.criticalBg;
        badgeBorder = badgeColor.withValues(alpha: 0.35);
        defaultIcon = Icons.warning_amber_rounded;
      case ConfirmDialogType.warning:
        badgeColor = context.semanticColors.warning;
        badgeBg = context.semanticColors.warningBg;
        badgeBorder = badgeColor.withValues(alpha: 0.35);
        defaultIcon = Icons.help_outline_rounded;
      case ConfirmDialogType.info:
        badgeColor = theme.colorScheme.primary;
        badgeBg = theme.colorScheme.primaryContainer;
        badgeBorder = badgeColor.withValues(alpha: 0.35);
        defaultIcon = Icons.info_outline_rounded;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final responsiveMaxWidth = screenWidth < 520
        ? screenWidth * 0.94
        : widget.maxWidth;

    final confirmForeground = widget.isDestructive
        ? theme.colorScheme.onError
        : theme.colorScheme.onPrimary;

    return PopScope(
      canPop: !_locked,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ShakeOnChange(
          trigger: _failures,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsiveMaxWidth),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.modalSurface
                    : AppColors.lightModalSurface,
                borderRadius: AppRadius.roundedLg,
                border: Border.all(
                  color: isDark ? AppColors.border : AppColors.lightBorder,
                  width: AppColors.borderWidth,
                ),
                boxShadow: AppShadows.overlay,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header & Body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: badgeBorder),
                          ),
                          child: Icon(
                            widget.icon ?? defaultIcon,
                            color: badgeColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textPrimary
                                      : AppColors.lightTextPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.message,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                  fontSize: 15,
                                  height: 1.45,
                                ),
                              ),
                              if (widget.content != null) ...[
                                const SizedBox(height: 14),
                                widget.content!,
                              ],
                              AnimatedSize(
                                duration: reduceMotion(context)
                                    ? Duration.zero
                                    : AppDurations.normal,
                                curve: Curves.easeOutCubic,
                                child: _error == null
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                          top: 12,
                                        ),
                                        child: _ErrorNote(message: _error!),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons footer
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.sidebarBackground
                          : AppColors.lightElevatedSurface,
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? AppColors.borderSubtle
                              : AppColors.lightBorderSubtle,
                          width: AppColors.borderWidth,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _locked
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.roundedSm,
                            ),
                          ),
                          child: Text(widget.cancelLabel),
                        ),
                        const SizedBox(width: 10),
                        PressScale(
                          enabled: !_locked,
                          child: FilledButton(
                            // Stays coloured while busy or done, so the
                            // spinner and check read as progress, not as a
                            // disabled button.
                            onPressed: _locked ? () {} : _confirm,
                            style: FilledButton.styleFrom(
                              backgroundColor: widget.isDestructive
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              foregroundColor: confirmForeground,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.roundedSm,
                              ),
                              textStyle: const TextStyle(
                                fontFamily: AppType.family,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: ActionButtonContent(
                              phase: _phase,
                              label: _error == null
                                  ? widget.confirmLabel
                                  : 'Try again',
                              busyLabel: widget.busyLabel,
                              doneLabel: widget.doneLabel,
                              color: confirmForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final critical = context.semanticColors.critical;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.semanticColors.criticalBg,
        borderRadius: AppRadius.roundedSm,
        border: Border.all(color: critical.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: critical),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 14, height: 1.4, color: critical),
            ),
          ),
        ],
      ),
    );
  }
}
