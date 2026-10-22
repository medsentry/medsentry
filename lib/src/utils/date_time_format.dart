import 'package:intl/intl.dart';

String formatTime12h(DateTime dateTime) {
  return DateFormat('h:mm a').format(dateTime.toLocal());
}

String formatDateTime12h(DateTime dateTime) {
  return DateFormat('MMM d, yyyy h:mm a').format(dateTime.toLocal());
}

String formatDateTimeWithSeconds12h(DateTime dateTime) {
  return DateFormat('MMM d, yyyy h:mm:ss a').format(dateTime.toLocal());
}

/// "Just now", "5 min ago", "3 hr ago", then "Oct 22, 9:13 PM".
String formatRelativeTime(DateTime dateTime, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(dateTime);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours} hr ago';
  return DateFormat('MMM d, h:mm a').format(dateTime.toLocal());
}
