import 'package:intl/intl.dart';

/// Every API timestamp is ISO-8601 UTC; convert to IST before display.
class DateFormatting {
  DateFormatting._();

  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  static DateTime utcToIst(DateTime utc) => utc.toUtc().add(istOffset);

  static String dateOnly(DateTime dt) =>
      DateFormat('dd MMM yyyy').format(utcToIst(dt));

  static String time(DateTime dt) => DateFormat('hh:mm a').format(utcToIst(dt));

  static String dateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(utcToIst(dt));

  static String dayOfWeek(DateTime dt) =>
      DateFormat('EEE').format(utcToIst(dt));

  /// "just now", "4 min ago", "3 h ago", "2 d ago".
  static String relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  static bool isToday(DateTime dt) {
    final ist = utcToIst(dt);
    final now = utcToIst(DateTime.now().toUtc());
    return ist.year == now.year && ist.month == now.month && ist.day == now.day;
  }
}
