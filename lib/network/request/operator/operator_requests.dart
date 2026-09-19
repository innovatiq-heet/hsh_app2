class RoomSwapRequest {
  final String studentAadharA;
  final String studentAadharB;

  const RoomSwapRequest({
    required this.studentAadharA,
    required this.studentAadharB,
  });
}

class MarkStudentLeftRequest {
  final String studentAadhar;
  final String reason;

  const MarkStudentLeftRequest({
    required this.studentAadhar,
    required this.reason,
  });
}

class ScheduleSabhaRequest {
  final String title;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;

  const ScheduleSabhaRequest({
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
  });
}
