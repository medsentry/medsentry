import 'package:intl/intl.dart';

String formatTime12h(DateTime dateTime) {
  return DateFormat('h:mm a').format(dateTime.toLocal());
}

String formatDateTime12h(DateTime dateTime) {
  return DateFormat('MMM d, yyyy h:mm a').format(dateTime.toLocal());
}
