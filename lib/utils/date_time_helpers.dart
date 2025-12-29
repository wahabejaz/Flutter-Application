import 'package:intl/intl.dart';

/// Utility functions for date and time formatting
class DateTimeHelpers {
  /// Convert 24-hour time string (HH:mm) to 12-hour format (h:mm a)
  /// Example: "14:30" -> "2:30 PM"
  static String formatTime12Hour(String time24Hour) {
    final parts = time24Hour.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final dateTime = DateTime(2024, 1, 1, hour, minute);
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Convert 24-hour time string to DateTime for the current day
  static DateTime parseTimeString(String time24Hour) {
    final parts = time24Hour.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}