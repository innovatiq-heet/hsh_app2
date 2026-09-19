import '../../../common_enums/attendance_type.dart';

class AttendanceMarkResponse {
  final AttendanceType type;
  final DateTime markedAt;
  final bool viaCode;

  const AttendanceMarkResponse({
    required this.type,
    required this.markedAt,
    required this.viaCode,
  });
}

class AttendanceLogEntry {
  final AttendanceType type;
  final DateTime markedAt;
  final bool viaCode;

  const AttendanceLogEntry({
    required this.type,
    required this.markedAt,
    required this.viaCode,
  });
}

class SabhaResponse {
  final String id;
  final String title;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;

  const SabhaResponse({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
  });
}
