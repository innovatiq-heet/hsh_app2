class ApplyLeaveRequest {
  final DateTime startTime;
  final DateTime endTime;
  final String reason;

  const ApplyLeaveRequest({
    required this.startTime,
    required this.endTime,
    required this.reason,
  });
}
