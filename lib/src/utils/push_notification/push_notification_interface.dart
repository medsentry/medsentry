abstract class PushNotificationService {
  Future<bool> requestPermission();
  Future<void> showNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
  });
}

