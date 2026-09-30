import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class AppNotification {
  AppNotification._();

  /// Displays a success toast notification banner.
  static ToastificationItem success({
    required String title,
    String? message,
    Duration autoCloseDuration = const Duration(seconds: 4),
  }) {
    return toastification.show(
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      alignment: Alignment.topRight,
      autoCloseDuration: autoCloseDuration,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      description: message != null ? Text(message) : null,
      borderRadius: BorderRadius.circular(12),
      showProgressBar: true,
      dragToClose: true,
    );
  }

  /// Displays an error toast notification banner.
  static ToastificationItem error({
    required String title,
    String? message,
    Duration autoCloseDuration = const Duration(seconds: 5),
  }) {
    return toastification.show(
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      alignment: Alignment.topRight,
      autoCloseDuration: autoCloseDuration,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      description: message != null ? Text(message) : null,
      borderRadius: BorderRadius.circular(12),
      showProgressBar: true,
      dragToClose: true,
    );
  }

  /// Displays an informational toast notification banner.
  static ToastificationItem info({
    required String title,
    String? message,
    Duration autoCloseDuration = const Duration(seconds: 4),
  }) {
    return toastification.show(
      type: ToastificationType.info,
      style: ToastificationStyle.flatColored,
      alignment: Alignment.topRight,
      autoCloseDuration: autoCloseDuration,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      description: message != null ? Text(message) : null,
      borderRadius: BorderRadius.circular(12),
      showProgressBar: true,
      dragToClose: true,
    );
  }

  /// Displays a warning toast notification banner.
  static ToastificationItem warning({
    required String title,
    String? message,
    Duration autoCloseDuration = const Duration(seconds: 4),
  }) {
    return toastification.show(
      type: ToastificationType.warning,
      style: ToastificationStyle.flatColored,
      alignment: Alignment.topRight,
      autoCloseDuration: autoCloseDuration,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      description: message != null ? Text(message) : null,
      borderRadius: BorderRadius.circular(12),
      showProgressBar: true,
      dragToClose: true,
    );
  }

  /// Dismisses all active toast notifications.
  static void dismissAll({bool delayForAnimation = true}) {
    toastification.dismissAll(delayForAnimation: delayForAnimation);
  }
}
