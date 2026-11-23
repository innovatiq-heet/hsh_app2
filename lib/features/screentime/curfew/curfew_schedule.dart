/// Curfew schedule maths, identical to the backend
/// (`src/modules/screentime/screentime.sessions.ts`).
///
/// * Times are IST wall-clock `HH:mm`.
/// * A window whose end is before its start crosses midnight and belongs to
///   the day it **starts** on: a Monday-only 22:00–06:00 session runs
///   Mon 22:00 → Tue 06:00.
/// * A phone blocks while **any** of its curfews is running.
library;

const List<String> kDayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const List<String> kDayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// IST is UTC+05:30 all year (no daylight saving).
const Duration kIstOffset = Duration(hours: 5, minutes: 30);

/// "now" as IST wall-clock fields, independent of the phone's time zone.
DateTime istNow([DateTime? now]) => (now ?? DateTime.now()).toUtc().add(kIstOffset);

int _minutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// One curfew window as the phone enforces it.
class CurfewWindow {
  const CurfewWindow({required this.startTime, required this.endTime, required this.days});

  /// `HH:mm`
  final String startTime;

  /// `HH:mm`
  final String endTime;

  /// Subset of [kDayKeys].
  final List<String> days;

  bool get crossesMidnight => _minutes(endTime) < _minutes(startTime);

  bool _hasDay(int weekdayIndex) => days.contains(kDayKeys[(weekdayIndex + 7) % 7]);

  /// Whether the window covers [now] (defaults to the current time).
  bool isRunning([DateTime? now]) {
    final ist = istNow(now);
    final weekday = ist.weekday - 1; // DateTime.monday == 1 → 0
    final m = ist.hour * 60 + ist.minute;
    final start = _minutes(startTime);
    final end = _minutes(endTime);
    if (start < end) return _hasDay(weekday) && m >= start && m < end;
    return (_hasDay(weekday) && m >= start) || (_hasDay(weekday - 1) && m < end);
  }

  /// Next start strictly after [now], as a UTC instant.
  DateTime? nextStart([DateTime? now]) {
    final ist = istNow(now);
    final weekday = ist.weekday - 1;
    final m = ist.hour * 60 + ist.minute;
    final start = _minutes(startTime);
    final istMidnight = DateTime.utc(ist.year, ist.month, ist.day);
    for (var d = 0; d <= 7; d++) {
      if (_hasDay(weekday + d) && (d > 0 || start > m)) {
        return istMidnight.add(Duration(days: d, minutes: start)).subtract(kIstOffset);
      }
    }
    return null;
  }

  /// When the run in progress ends (UTC), or null when not running.
  DateTime? currentEnd([DateTime? now]) {
    if (!isRunning(now)) return null;
    final ist = istNow(now);
    final m = ist.hour * 60 + ist.minute;
    final endsTomorrow = crossesMidnight && m >= _minutes(startTime);
    final istMidnight = DateTime.utc(ist.year, ist.month, ist.day);
    return istMidnight
        .add(Duration(days: endsTomorrow ? 1 : 0, minutes: _minutes(endTime)))
        .subtract(kIstOffset);
  }
}

/// "every day", "Mon–Fri", "Sat–Sun" or "Mon, Wed, Fri" (same as the server).
String describeDays(List<String> days) {
  final idx = [for (var i = 0; i < 7; i++) if (days.contains(kDayKeys[i])) i];
  if (idx.length == 7) return 'every day';
  if (idx.isEmpty) return 'no days';
  var consecutive = true;
  for (var k = 1; k < idx.length; k++) {
    if (idx[k] != idx[k - 1] + 1) consecutive = false;
  }
  if (consecutive && idx.length >= 2) return '${kDayLabels[idx.first]}–${kDayLabels[idx.last]}';
  return idx.map((i) => kDayLabels[i]).join(', ');
}

/// Union of every curfew the phone must enforce. Build it from the policy
/// with [PhoneCurfewSet.fromPolicy] on every policy response (long-poll,
/// ping echo, `/policies/me`).
class PhoneCurfewSet {
  const PhoneCurfewSet(this.windows);

  final List<CurfewWindow> windows;

  /// Reads `policy.curfew_sessions`; falls back to the single legacy
  /// `bedtime_start/end` when talking to an older server.
  factory PhoneCurfewSet.fromPolicy(Map<String, dynamic> policy) {
    final raw = policy['curfew_sessions'];
    if (raw is List) {
      return PhoneCurfewSet([
        for (final c in raw.whereType<Map>())
          CurfewWindow(
            startTime: c['start_time'] as String,
            endTime: c['end_time'] as String,
            days: (c['days'] as List).cast<String>(),
          ),
      ]);
    }
    final start = policy['bedtime_start'] as String?;
    final end = policy['bedtime_end'] as String?;
    if (start == null || end == null) return const PhoneCurfewSet([]);
    return PhoneCurfewSet([
      CurfewWindow(startTime: start.substring(0, 5), endTime: end.substring(0, 5), days: kDayKeys),
    ]);
  }

  bool get isEmpty => windows.isEmpty;

  /// Block apps now?
  bool isInCurfew([DateTime? now]) => windows.any((w) => w.isRunning(now));

  /// When the phone should re-check: the earliest start or end ahead.
  /// Schedule an alarm / WorkManager job for this instant so blocking starts
  /// and stops on time even when the app is in the background.
  DateTime? nextChange([DateTime? now]) {
    DateTime? best;
    for (final w in windows) {
      for (final t in [w.nextStart(now), w.currentEnd(now)]) {
        if (t != null && (best == null || t.isBefore(best))) best = t;
      }
    }
    return best;
  }
}
