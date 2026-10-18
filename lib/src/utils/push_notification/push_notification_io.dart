import 'push_notification_interface.dart';

class IoPushNotificationService implements PushNotificationService {
  @override
  Future<bool> requestPermission() async {
    return true;
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
  }) async {
    // On desktop, in-app toastification notification handles visual alerting.
  }
}

PushNotificationService createPushNotificationService() => IoPushNotificationService();

