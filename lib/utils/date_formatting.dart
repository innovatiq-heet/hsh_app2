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

  static bool isToday(DateTime dt) {
    final ist = utcToIst(dt);
    final now = utcToIst(DateTime.now().toUtc());
    return ist.year == now.year && ist.month == now.month && ist.day == now.day;
  }
}
