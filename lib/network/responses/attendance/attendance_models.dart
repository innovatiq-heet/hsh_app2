import '../../../common_enums/attendance_type.dart';

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

  const AttendanceRecord({
    required this.id,
    this.aadhar,
    required this.date,
    required this.time,
    required this.type,
    required this.viaCode,
    this.ip,
  });

  /// Convenience getter matching previous `AttendanceLogEntry.markedAt` interface.
  DateTime get markedAt => time;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v.toUtc();
      if (v is String) return DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    final rawType = json['type']?.toString() ?? 'aarti';
    final dateVal = parseDate(json['date']);
    DateTime timeVal;
    if (json['time'] != null) {
      final parsedTime = parseDate(json['time']);
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

    return AttendanceRecord(
      id: json['id'] ?? json['_id'] ?? 0,
      aadhar: json['aadhar']?.toString(),
      date: dateVal,
      time: timeVal,
      type: AttendanceTypeX.fromApi(rawType),
      viaCode: json['viaCode'] == true,
      ip: json['ip']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (aadhar != null) 'aadhar': aadhar,
    'date': date.toIso8601String(),
    'time': time.toIso8601String(),
    'type': type.apiValue,
    'viaCode': viaCode,
    if (ip != null) 'ip': ip,
  };
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
