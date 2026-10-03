import 'package:flutter/material.dart';

/// Curfew geofence rules as the warden configures them.
///
/// Mirrors `GeofencePolicy` in `GeofenceEvaluator.kt`, which is what actually
/// enforces this on the student's phone.
class GeofencePolicyModel {
  final String id;
  final String name;
  final TimeOfDay startTime; // e.g. 22:00 (10:00 PM)
  final TimeOfDay endTime; // e.g. 06:00 (06:00 AM)
  final bool isActive;

  /// Lock the phone while the student is outside campus during curfew.
  final bool enforcePhoneLock;
  final int checkIntervalMinutes;

  /// ['Daily'] or weekday names ('Mon', 'Tue', …) — the day the curfew starts.
  final List<String> repeatDays;

  /// Per-student gate pass (only meaningful on `/geofence/policy` for a student).
  final DateTime? exemptUntil;
  final String version;

  const GeofencePolicyModel({
    this.id = 'default_curfew',
    this.name = 'Hostel Night Curfew',
    this.startTime = const TimeOfDay(hour: 22, minute: 0),
    this.endTime = const TimeOfDay(hour: 6, minute: 0),
    this.isActive = true,
    this.enforcePhoneLock = false,
    this.checkIntervalMinutes = 10,
    this.repeatDays = const ['Daily'],
    this.exemptUntil,
    this.version = '',
  });

  static const _dayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  /// Whether [dateTime] falls inside the curfew window, honouring overnight
  /// spans (22:00 → 06:00) and [repeatDays].
  bool isWithinCurfew(DateTime dateTime) {
    if (!isActive) return false;
    final cur = dateTime.hour * 60 + dateTime.minute;
    final start = startTime.hour * 60 + startTime.minute;
    final end = endTime.hour * 60 + endTime.minute;
    if (start == end) return false;

    final overnight = start > end;
    final inWindow = overnight ? (cur >= start || cur < end) : (cur >= start && cur < end);
    if (!inWindow) return false;

    // After midnight in an overnight window, it's still "yesterday's" curfew.
    final day = overnight && cur < end ? dateTime.subtract(const Duration(days: 1)) : dateTime;
    return _matchesDay(day.weekday);
  }

  bool _matchesDay(int weekday) {
    if (repeatDays.isEmpty) return true;
    if (repeatDays.any((d) => d.toLowerCase() == 'daily' || d.toLowerCase() == 'everyday')) return true;
    final name = _dayNames[weekday - 1];
    return repeatDays.any((d) => d.toLowerCase().startsWith(name));
  }

  bool get isExemptNow => exemptUntil != null && exemptUntil!.isAfter(DateTime.now());

  Duration get curfewLength {
    final start = startTime.hour * 60 + startTime.minute;
    final end = endTime.hour * 60 + endTime.minute;
    return Duration(minutes: end > start ? end - start : (24 * 60 - start) + end);
  }

  String formatTimeRange() => '${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)}';

  static String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  GeofencePolicyModel copyWith({
    String? id,
    String? name,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isActive,
    bool? enforcePhoneLock,
    int? checkIntervalMinutes,
    List<String>? repeatDays,
    DateTime? exemptUntil,
    String? version,
  }) {
    return GeofencePolicyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      enforcePhoneLock: enforcePhoneLock ?? this.enforcePhoneLock,
      checkIntervalMinutes: checkIntervalMinutes ?? this.checkIntervalMinutes,
      repeatDays: repeatDays ?? this.repeatDays,
      exemptUntil: exemptUntil ?? this.exemptUntil,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': _hhmm(startTime),
        'endTime': _hhmm(endTime),
        'isActive': isActive,
        'enforcePhoneLock': enforcePhoneLock,
        'lockOnBreach': enforcePhoneLock,
        'checkIntervalMinutes': checkIntervalMinutes,
        'repeatDays': repeatDays,
      };

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  factory GeofencePolicyModel.fromJson(Map<dynamic, dynamic> raw) {
    final data = raw['data'] is Map ? raw['data'] as Map : raw;
    final json = data['policy'] is Map ? data['policy'] as Map : data;

    TimeOfDay parseTime(dynamic v, TimeOfDay fallback) {
      final str = v?.toString();
      if (str == null || !str.contains(':')) return fallback;
      final parts = str.split(':');
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1].substring(0, parts[1].length.clamp(0, 2)));
      if (h == null || m == null || h > 23 || m > 59) return fallback;
      return TimeOfDay(hour: h, minute: m);
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v > 1e12 ? v.toInt() : v.toInt() * 1000);
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    final days = json['repeatDays'] ?? json['repeat_days'];
    return GeofencePolicyModel(
      id: (json['id'] ?? json['_id'] ?? 'default_curfew').toString(),
      name: (json['name'] ?? 'Hostel Night Curfew').toString(),
      startTime: parseTime(json['startTime'] ?? json['start_time'], const TimeOfDay(hour: 22, minute: 0)),
      endTime: parseTime(json['endTime'] ?? json['end_time'], const TimeOfDay(hour: 6, minute: 0)),
      isActive: _toBool(json['isActive'] ?? json['is_active']) ?? true,
      enforcePhoneLock: _toBool(json['lockOnBreach'] ?? json['lock_on_breach'] ?? json['enforcePhoneLock'] ?? json['enforce_phone_lock']) ?? false,
      checkIntervalMinutes: _toInt(json['checkIntervalMinutes'] ?? json['check_interval_minutes']) ?? 10,
      repeatDays: days is List ? days.map((e) => e.toString()).toList() : const ['Daily'],
      exemptUntil: parseDate(json['exemptUntil'] ?? json['exempt_until']),
      version: (json['updatedAt'] ?? json['updated_at'] ?? json['version'] ?? '').toString(),
    );
  }

  static bool? _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v is num) return v.round();
    if (v is String) return num.tryParse(v)?.round();
    return null;
  }
}
