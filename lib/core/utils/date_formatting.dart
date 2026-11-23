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

  // --- Calendar dates from the student directory (birthdays, anniversaries) ---

  /// A date as the directory stores it: `yyyy-MM-dd` (or a full ISO string),
  /// `dd-MM-yyyy`, or epoch milliseconds (midnight IST). Null when unreadable.
  static DateTime? parseCalendarDate(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty || v == 'null') return null;
    final ms = int.tryParse(v);
    if (ms != null) {
      if (ms <= 0 && !v.startsWith('-')) return null;
      final ist = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).add(istOffset);
      return DateTime(ist.year, ist.month, ist.day);
    }
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(v);
    if (iso != null) {
      return _valid(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
    }
    final dmy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$').firstMatch(v);
    if (dmy != null) {
      return _valid(int.parse(dmy.group(3)!), int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
    }
    return null;
  }

  static DateTime? _valid(int y, int m, int d) =>
      (m < 1 || m > 12 || d < 1 || d > 31) ? null : DateTime(y, m, d);

  /// Whole years completed from [date] until [now] (today); null when that is
  /// not a sensible count (0 or less, or over 120).
  static int? yearsSince(DateTime date, {DateTime? now}) {
    final today = now ?? DateTime.now();
    var years = today.year - date.year;
    if (today.month < date.month || (today.month == date.month && today.day < date.day)) years--;
    return years > 0 && years <= 120 ? years : null;
  }

  /// "19 Mar 1971" for a directory date; [raw] as is when it can't be read.
  static String calendarDate(String? raw) {
    final dt = parseCalendarDate(raw);
    return dt == null ? (raw ?? '').trim() : DateFormat('d MMM yyyy').format(dt);
  }

  /// "19 Mar 1971 (54 yrs)": the date the way a student's birth date is shown,
  /// with the whole years since (age, or years married for an anniversary).
  static String calendarDateWithYears(String? raw, {DateTime? now}) {
    final dt = parseCalendarDate(raw);
    if (dt == null) return (raw ?? '').trim();
    final years = yearsSince(dt, now: now);
    final date = DateFormat('d MMM yyyy').format(dt);
    return years == null ? date : '$date ($years yrs)';
  }
}
