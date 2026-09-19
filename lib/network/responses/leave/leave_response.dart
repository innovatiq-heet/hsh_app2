import '../../../common_enums/leave_status.dart';

class LeaveResponse {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String reason;
  final LeaveStatus status;
  final DateTime appliedAt;

  const LeaveResponse({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.reason,
    required this.status,
    required this.appliedAt,
  });
}
