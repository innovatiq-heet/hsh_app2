import 'dart:convert';

import '../../../enums/attendance_type.dart';

String? _normHHMM(dynamic raw) {
  final s = raw?.toString().trim();
  if (s == null || s.isEmpty || s == 'null') return null;
  return s.length >= 5 ? s.substring(0, 5) : s;
}

Map<String, dynamic>? _extractTodaySlot(dynamic rawDaySchedules) {
  List<dynamic>? parsed;
  if (rawDaySchedules is List) {
    parsed = rawDaySchedules;
  } else if (rawDaySchedules is String && rawDaySchedules.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(rawDaySchedules);
      if (decoded is List) parsed = decoded;
    } catch (_) {}
  }
  if (parsed == null || parsed.isEmpty) return null;

  const weekdayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  final todayShort = weekdayNames[DateTime.now().weekday - 1];
  for (final slot in parsed) {
    if (slot is Map && slot['days'] is List) {
      final days = slot['days'] as List;
      if (days.any((d) {
        final s = d.toString().trim().toLowerCase();
        return s.length >= 3 && s.substring(0, 3) == todayShort;
      })) {
        return Map<String, dynamic>.from(slot);
      }
    }
  }
  return null;
}

/// Checks if `now` (defaults to local time) falls inside an `[startHHMM, endHHMM]` window,
/// including overnight windows where `end < start`.
bool isHHMMInWindow(String? startHHMM, String? endHHMM, [DateTime? now]) {
  final start = _normHHMM(startHHMM);
  final end = _normHHMM(endHHMM);
  if (start == null || end == null) return false;
  if (start == '00:00' && end == '00:00') return false;

  final sParts = start.split(':');
  final eParts = end.split(':');
  if (sParts.length < 2 || eParts.length < 2) return false;
  final sH = int.tryParse(sParts[0]);
  final sM = int.tryParse(sParts[1]);
  final eH = int.tryParse(eParts[0]);
  final eM = int.tryParse(eParts[1]);
  if (sH == null || sM == null || eH == null || eM == null) return false;

  final cur = now ?? DateTime.now();
  final nowMins = cur.hour * 60 + cur.minute;
  final startMins = sH * 60 + sM;
  final endMins = eH * 60 + eM;
  if (startMins == endMins) return false;
  if (startMins < endMins) {
    return nowMins >= startMins && nowMins <= endMins;
  }
  return nowMins >= startMins || nowMins <= endMins;
}

/// Returns true once the `[startHHMM, endHHMM]` window has finished for `now`.
bool hasHHMMWindowEnded(String? startHHMM, String? endHHMM, [DateTime? now]) {
  final start = _normHHMM(startHHMM);
  final end = _normHHMM(endHHMM);
  if (start == null || end == null) return false;
  if (start == '00:00' && end == '00:00') return false;

  final sParts = start.split(':');
  final eParts = end.split(':');
  if (sParts.length < 2 || eParts.length < 2) return false;
  final sH = int.tryParse(sParts[0]);
  final sM = int.tryParse(sParts[1]);
  final eH = int.tryParse(eParts[0]);
  final eM = int.tryParse(eParts[1]);
  if (sH == null || sM == null || eH == null || eM == null) return false;

  final cur = now ?? DateTime.now();
  final nowMins = cur.hour * 60 + cur.minute;
  final startMins = sH * 60 + sM;
  final endMins = eH * 60 + eM;
  if (startMins < endMins) {
    return nowMins > endMins;
  }
  if (startMins > endMins) {
    return nowMins > endMins && nowMins < startMins;
  }
  return false;
}

/// Single attendance record returned by the backend (spec v2.0.0).
/// Supports both student self-scans and operator/admin manual entries.
class AttendanceRecord {
  final dynamic id;
  final String? aadhar;
  final DateTime date;
  final DateTime time;
  final AttendanceType type;
  final bool viaCode;
  final String? ip;
  final int? phase;
  final bool isLate;
  final String? message;
  final String? _sessionKey;

  const AttendanceRecord({
    required this.id,
    this.aadhar,
    required this.date,
    required this.time,
    required this.type,
    required this.viaCode,
    this.ip,
    this.phase,
    this.isLate = false,
    this.message,
    String? sessionKey,
  }) : _sessionKey = sessionKey;

  /// Convenience getter matching previous `AttendanceLogEntry.markedAt` interface.
  DateTime get markedAt => time;

  /// Getter for session key from backend payload or fallback to [type].
  String get sessionKey {
    final sk = _sessionKey;
    return (sk != null && sk.isNotEmpty) ? sk : type.apiValue;
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v.toUtc();
      if (v is String) return DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    final rawType = json['session_key']?.toString() ??
        json['sessionKey']?.toString() ??
        json['type']?.toString() ??
        json['session_type']?.toString() ??
        'aarti';
    final dateVal = parseDate(json['date'] ?? json['session_date'] ?? json['marked_at']);
    DateTime timeVal;
    if (json['time'] != null || json['marked_at'] != null) {
      final parsedTime = parseDate(json['time'] ?? json['marked_at']);
      if (parsedTime.year <= 1970) {
        timeVal = DateTime.utc(
          dateVal.year,
          dateVal.month,
          dateVal.day,
          parsedTime.hour,
          parsedTime.minute,
          parsedTime.second,
          parsedTime.millisecond,
        );
      } else {
        timeVal = parsedTime;
      }
    } else {
      timeVal = dateVal;
    }

    final rawPhase = json['phase'];
    final int? parsedPhase = rawPhase is num
        ? rawPhase.toInt()
        : int.tryParse(rawPhase?.toString() ?? '');

    return AttendanceRecord(
      id: json['id'] ?? json['_id'] ?? 0,
      aadhar: json['aadhar']?.toString() ?? json['student_code']?.toString() ?? json['bank_code']?.toString(),
      date: dateVal,
      time: timeVal,
      type: AttendanceTypeX.fromApi(rawType),
      viaCode: json['viaCode'] == true,
      ip: json['ip']?.toString(),
      phase: parsedPhase,
      isLate: json['is_late'] == true || json['is_late'] == 1 || json['isLate'] == true,
      message: json['message']?.toString(),
      sessionKey: rawType,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (aadhar != null) 'aadhar': aadhar,
    'date': date.toIso8601String(),
    'time': time.toIso8601String(),
    if (phase != null) 'phase': phase,
    if (isLate) 'is_late': isLate,
    if (message != null) 'message': message,
    'type': type.apiValue,
    'viaCode': viaCode,
    if (ip != null) 'ip': ip,
  };
}

extension AttendanceScheduleItemPhaseX on AttendanceScheduleItem {
  bool get isPhase1Marked => firstAttendance?['is_marked'] == true;
  bool get isPhase2Marked => secondAttendance?['is_marked'] == true;
  bool get isPhase1Late => firstAttendance?['is_late'] == true;
  bool get isPhase2Late => secondAttendance?['is_late'] == true;
  String get phase1Status => firstAttendance?['status']?.toString() ?? '';
  String get phase2Status => secondAttendance?['status']?.toString() ?? '';

  /// Returns true if Phase 1 is open now (server payload when [now] is omitted, else [now]).
  bool isPhase1WindowOpen([DateTime? now]) {
    if (!isScheduledToday) return false;
    if (now == null && firstAttendance != null && firstAttendance!['is_open_now'] is bool) {
      return firstAttendance!['is_open_now'] as bool;
    }
    return isHHMMInWindow(startTime, endTime, now);
  }

  /// Returns true if Phase 2 is open now (server payload when [now] is omitted, else [now]).
  bool isPhase2WindowOpen([DateTime? now]) {
    if (!isScheduledToday || !hasMultipleAttendance) return false;
    if (now == null && secondAttendance != null && secondAttendance!['is_open_now'] is bool) {
      return secondAttendance!['is_open_now'] as bool;
    }
    return isHHMMInWindow(phase2StartTime, phase2EndTime, now);
  }

  /// Returns the currently active/open phase (`1` or `2`), or `null` if closed.
  int? currentOpenPhase([DateTime? now]) {
    if (!isScheduledToday) return null;
    if (hasMultipleAttendance) {
      if (isPhase1WindowOpen(now)) return 1;
      if (isPhase2WindowOpen(now)) return 2;
      if (now == null && (activePhase == 1 || activePhase == 2)) return activePhase;
      return null;
    }
    return isHHMMInWindow(startTime, endTime, now) ? 1 : null;
  }

  /// True when the student missed Phase 1 and is blocked from Phase 2.
  bool isPhase2Ineligible([DateTime? now]) {
    if (!hasMultipleAttendance || !isScheduledToday) return false;
    if (phase2Status == 'not_eligible') return true;
    if (secondAttendance?['is_eligible'] == false && !isPhase1Marked) return true;
    if (!isPhase1Marked && hasHHMMWindowEnded(startTime, endTime, now)) {
      return true;
    }
    return false;
  }

  /// True after Phase 1 is marked while waiting for Phase 2 to open.
  bool isWaitingForPhase2([DateTime? now]) {
    if (!hasMultipleAttendance || !isScheduledToday) return false;
    if (isPhase2Marked || isPhase2WindowOpen(now) || isPhase2Ineligible(now)) {
      return false;
    }
    if (hasHHMMWindowEnded(phase2StartTime, phase2EndTime, now)) {
      return false;
    }
    if (now == null && phase1Status.isNotEmpty && phase2Status == 'upcoming') {
      return isPhase1Marked && !isPhase1WindowOpen();
    }
    return isPhase1Marked && hasHHMMWindowEnded(startTime, endTime, now);
  }

  /// True when today's attendance requirements for this session are completely fulfilled.
  bool isCompletedToday({bool fallbackSingleMarked = false}) {
    if (hasMultipleAttendance) {
      return overallStatus == 'complete' || (isPhase1Marked && isPhase2Marked);
    }
    return overallStatus == 'marked' ||
        overallStatus == 'complete' ||
        isPhase1Marked ||
        fallbackSingleMarked;
  }

  /// True when the student can mark attendance right now for this session.
  bool canMarkPhaseNow({bool fallbackSingleMarked = false, DateTime? now}) {
    if (!isScheduledToday) return false;
    if (overallStatus == 'leave') return false;
    if (hasMultipleAttendance) {
      if (now == null && canMark != null) return canMark!;
      final openPhase = currentOpenPhase(now);
      if (openPhase == 1) return !isPhase1Marked && !fallbackSingleMarked;
      if (openPhase == 2) return isPhase1Marked && !isPhase2Marked;
      return false;
    }
    if (now == null && canMark != null) return canMark!;
    return !fallbackSingleMarked && isHHMMInWindow(startTime, endTime, now);
  }

  String? get activeOutOfRangeMessage {
    if (!hasMultipleAttendance) return null;
    final p = currentOpenPhase();
    if (p == 2) {
      final msg = secondAttendance?['out_of_range_message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    } else if (p == 1) {
      final msg = firstAttendance?['out_of_range_message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return null;
  }
}

/// Single schedule session configuration from `/api/schedule-data` or `/attendance/schedule`
class AttendanceScheduleItem {
  final int? id;
  final String sessionKey;
  final String sessionName;
  final String iconName;
  final String startTime;
  final String endTime;
  final String? lateTime;
  final bool isForAllStudents;
  final bool isActive;
  final bool isScheduledToday;
  final bool hasMultipleAttendance;
  final String? phase2StartTime;
  final String? phase2EndTime;
  final String? phase2LateTime;
  final int? activePhase;
  final bool? canMark;
  final String? overallStatus;
  final Map<String, dynamic>? firstAttendance;
  final Map<String, dynamic>? secondAttendance;

  const AttendanceScheduleItem({
    this.id,
    required this.sessionKey,
    required this.sessionName,
    this.iconName = 'moon',
    required this.startTime,
    required this.endTime,
    this.lateTime,
    this.isForAllStudents = true,
    this.isActive = true,
    this.isScheduledToday = true,
    this.hasMultipleAttendance = false,
    this.phase2StartTime,
    this.phase2EndTime,
    this.phase2LateTime,
    this.activePhase,
    this.canMark,
    this.overallStatus,
    this.firstAttendance,
    this.secondAttendance,
  });

  AttendanceType get attendanceType => AttendanceTypeX.fromApi(sessionKey);

  factory AttendanceScheduleItem.fromJson(Map<String, dynamic> json) {
    String rawStart = (json['start_time'] ?? json['start'] ?? '00:00').toString();
    String rawEnd = (json['end_time'] ?? json['end'] ?? '00:00').toString();
    String? rawLate = json['late_time']?.toString();

    // Check day_schedules to pick today's specific timing slot
    final daySchedules = json['day_schedules'];
    bool isScheduledToday = true;
    if (daySchedules is List && daySchedules.isNotEmpty) {
      const weekdayNames = ['', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      final todayWeekday = DateTime.now().weekday;
      final todayName = (todayWeekday >= 1 && todayWeekday <= 7)
          ? weekdayNames[todayWeekday]
          : 'fri';
      bool foundTodaySlot = false;

      for (final slot in daySchedules) {
        if (slot is Map) {
          final days = slot['days'];
          if (days is List &&
              days.any((d) {
                final s = d.toString().trim().toLowerCase();
                return s.length >= 3 && s.substring(0, 3) == todayName;
              })) {
            foundTodaySlot = true;
            final sTime = slot['startTime'] ?? slot['start_time'];
            final eTime = slot['endTime'] ?? slot['end_time'];
            final lTime = slot['lateTime'] ?? slot['late_time'];

            if (sTime != null && sTime.toString().isNotEmpty) {
              rawStart = sTime.toString();
            }
            if (eTime != null && eTime.toString().isNotEmpty) {
              rawEnd = eTime.toString();
            }
            if (lTime != null &&
                lTime.toString().isNotEmpty &&
                lTime.toString() != 'null') {
              rawLate = lTime.toString();
            } else {
              rawLate = null;
            }
            break;
          }
        }
      }

      if (!foundTodaySlot) {
        isScheduledToday = false;
        // Fallback timing for display if top-level was unconfigured (00:00)
        if (rawStart == '00:00' && rawEnd == '00:00') {
          final firstSlot = daySchedules.first;
          if (firstSlot is Map) {
            final sTime = firstSlot['startTime'] ?? firstSlot['start_time'];
            final eTime = firstSlot['endTime'] ?? firstSlot['end_time'];
            if (sTime != null && sTime.toString().isNotEmpty) {
              rawStart = sTime.toString();
            }
            if (eTime != null && eTime.toString().isNotEmpty) {
              rawEnd = eTime.toString();
            }
          }
        }
      }
    }

    return AttendanceScheduleItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      sessionKey: (json['session_key'] ?? json['key'] ?? 'aarti').toString().toLowerCase(),
      sessionName: (json['session_name'] ?? json['name'] ?? 'Session').toString(),
      iconName: (json['icon_name'] ?? 'moon').toString(),
      startTime: rawStart.length >= 5 ? rawStart.substring(0, 5) : rawStart,
      endTime: rawEnd.length >= 5 ? rawEnd.substring(0, 5) : rawEnd,
      lateTime: rawLate != null && rawLate.isNotEmpty && rawLate != 'null'
          ? (rawLate.length >= 5 ? rawLate.substring(0, 5) : rawLate)
          : null,
      isForAllStudents: json['is_for_all_students'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      isScheduledToday: isScheduledToday,
      hasMultipleAttendance: json['has_multiple_attendance'] == true ||
          json['has_multiple_attendance'] == 1 ||
          (_extractTodaySlot(json['day_schedules'])?['hasMultipleAttendance'] == true) ||
          (_extractTodaySlot(json['day_schedules'])?['has_multiple_attendance'] == true),
      phase2StartTime: _normHHMM(
        json['phase2_start_time'] ??
            _extractTodaySlot(json['day_schedules'])?['phase2StartTime'] ??
            _extractTodaySlot(json['day_schedules'])?['phase2_start_time'],
      ),
      phase2EndTime: _normHHMM(
        json['phase2_end_time'] ??
            _extractTodaySlot(json['day_schedules'])?['phase2EndTime'] ??
            _extractTodaySlot(json['day_schedules'])?['phase2_end_time'],
      ),
      phase2LateTime: _normHHMM(
        json['phase2_late_time'] ??
            _extractTodaySlot(json['day_schedules'])?['phase2LateTime'] ??
            _extractTodaySlot(json['day_schedules'])?['phase2_late_time'],
      ),
      activePhase: json['active_phase'] is num
          ? (json['active_phase'] as num).toInt()
          : int.tryParse(json['active_phase']?.toString() ?? ''),
      canMark: json['can_mark'] == null ? null : (json['can_mark'] == true || json['can_mark'] == 1),
      overallStatus: json['overall_status']?.toString(),
      firstAttendance: json['first_attendance'] is Map ? Map<String, dynamic>.from(json['first_attendance'] as Map) : null,
      secondAttendance: json['second_attendance'] is Map ? Map<String, dynamic>.from(json['second_attendance'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'session_key': sessionKey,
    'session_name': sessionName,
    'icon_name': iconName,
    'start_time': startTime,
    'end_time': endTime,
    if (lateTime != null) 'late_time': lateTime,
    'is_for_all_students': isForAllStudents,
    'is_active': isActive,
    'has_multiple_attendance': hasMultipleAttendance,
    if (phase2StartTime != null) 'phase2_start_time': phase2StartTime,
    if (phase2EndTime != null) 'phase2_end_time': phase2EndTime,
    if (phase2LateTime != null) 'phase2_late_time': phase2LateTime,
    if (activePhase != null) 'active_phase': activePhase,
    if (canMark != null) 'can_mark': canMark,
    if (overallStatus != null) 'overall_status': overallStatus,
    if (firstAttendance != null) 'first_attendance': firstAttendance,
    if (secondAttendance != null) 'second_attendance': secondAttendance,
  };
}

/// Status payload returned by `GET /api/attendance/my-status`
class StudentAttendanceStatus {
  final bool alreadyMarked;
  final bool attendanceActive;
  final String? activeSessionType;
  final String sessionName;
  final String startTime;
  final String endTime;
  final List<AttendanceScheduleItem> allSchedules;
  final Map<String, dynamic> rawSchedules;

  const StudentAttendanceStatus({
    required this.alreadyMarked,
    required this.attendanceActive,
    this.activeSessionType,
    required this.sessionName,
    required this.startTime,
    required this.endTime,
    required this.allSchedules,
    this.rawSchedules = const {},
  });

  AttendanceType? get activeType =>
      activeSessionType != null ? AttendanceTypeX.fromApi(activeSessionType!) : null;

  factory StudentAttendanceStatus.fromJson(Map<String, dynamic> json) {
    List schedulesList = [];
    Map<String, dynamic> rawSchedulesMap = {};
    if (json['all_schedules'] is List) {
      schedulesList = json['all_schedules'] as List;
    } else if (json['schedules'] is Map) {
      rawSchedulesMap = Map<String, dynamic>.from(json['schedules'] as Map);
      schedulesList = rawSchedulesMap.entries.map((e) {
        final val = e.value is Map ? e.value as Map : {};
        return {
          'session_key': e.key,
          'session_name': val['name'] ?? e.key.toString().toUpperCase(),
          'start_time': val['start'] ?? '00:00',
          'end_time': val['end'] ?? '00:00',
        };
      }).toList();
    }

    final parsedSchedules = schedulesList
        .map((e) => AttendanceScheduleItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return StudentAttendanceStatus(
      alreadyMarked: json['already_marked'] == true,
      attendanceActive: json['attendance_active'] == true,
      activeSessionType: json['active_session_type']?.toString(),
      sessionName: (json['session_name'] ?? 'Attendance').toString(),
      startTime: (json['start_time'] ?? '00:00').toString(),
      endTime: (json['end_time'] ?? '00:00').toString(),
      allSchedules: parsedSchedules,
      rawSchedules: rawSchedulesMap,
    );
  }
}

/// Response returned by `GET /api/attendance/qr-token?type={type}`.
/// Dynamic signed JWT token valid for 30s (+ 5s server grace window).
class QrTokenResponse {
  final String token;
  final String type;
  final String date;
  final int expiresIn;
  final DateTime expiresAt;

  const QrTokenResponse({
    required this.token,
    required this.type,
    required this.date,
    required this.expiresIn,
    required this.expiresAt,
  });

  factory QrTokenResponse.fromJson(Map<String, dynamic> json) {
    final expiresAtRaw = json['expiresAt'];
    final parsedExpiresAt = expiresAtRaw is String
        ? (DateTime.tryParse(expiresAtRaw)?.toUtc() ??
            DateTime.now().toUtc().add(const Duration(seconds: 30)))
        : DateTime.now().toUtc().add(const Duration(seconds: 30));

    return QrTokenResponse(
      token: json['token']?.toString() ?? '',
      type: json['type']?.toString() ?? 'dinner',
      date: json['date']?.toString() ?? '',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 30,
      expiresAt: parsedExpiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'type': type,
    'date': date,
    'expiresIn': expiresIn,
    'expiresAt': expiresAt.toIso8601String(),
  };
}

/// Sabha session assembly model returned by `/api/attendance/sabhas`.
class SabhaSession {
  final String id;
  final DateTime date;
  final String description;
  final bool current;
  final DateTime startTime;
  final DateTime endTime;

  const SabhaSession({
    required this.id,
    required this.date,
    String? description,
    String? title,
    this.current = false,
    required this.startTime,
    required this.endTime,
  }) : description = description ?? title ?? 'Sabha';

  /// Alias for backward compatibility with `SabhaResponse.title`
  String get title => description;

  factory SabhaSession.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v.toUtc();
      if (v is String) return DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    return SabhaSession(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      date: parseDate(json['date']),
      description: (json['description'] ?? json['title'] ?? 'Sabha').toString(),
      current: json['current'] == true,
      startTime: parseDate(json['startTime']),
      endTime: parseDate(json['endTime']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'description': description,
    'current': current,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
  };
}

// Backward-compatible typedefs for existing code
typedef AttendanceMarkResponse = AttendanceRecord;
typedef AttendanceLogEntry = AttendanceRecord;
typedef SabhaResponse = SabhaSession;
