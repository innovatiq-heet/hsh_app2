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
  final bool current;

  const ScheduleSabhaRequest({
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.current = true,
  });

  Map<String, dynamic> toJson() => {
    'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'description': title,
    'current': current,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
  };
}
