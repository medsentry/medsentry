import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'push_notification_interface.dart';

class WebPushNotificationService implements PushNotificationService {
  @override
  Future<bool> requestPermission() async {
    try {
      final perm = web.Notification.permission;
      if (perm == 'granted') return true;
      if (perm == 'denied') return false;
      final result = await web.Notification.requestPermission().toDart;
      return result.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
  }) async {
    try {
      if (web.Notification.permission == 'granted') {
        web.Notification(
          title,
          web.NotificationOptions(
            body: body,
            icon: icon ?? '/icons/Icon-192.png',
            tag: tag ?? '',
          ),
        );
      }
    } catch (_) {}
  }
}

PushNotificationService createPushNotificationService() => WebPushNotificationService();

