import '../../../common_enums/attendance_type.dart';

/// [viaCode] is just a client-set flag (did this come from a scan) — the
/// server doesn't decode anything from it.
class MarkAttendanceRequest {
  final AttendanceType type;
  final bool viaCode;

  const MarkAttendanceRequest({required this.type, required this.viaCode});
}

/// Used for the operator's "attendance on behalf of" flow.
class MarkAttendanceOnBehalfRequest {
  final String studentAadhar;
  final AttendanceType type;
  final DateTime date;

  const MarkAttendanceOnBehalfRequest({
    required this.studentAadhar,
    required this.type,
    required this.date,
  });
}
