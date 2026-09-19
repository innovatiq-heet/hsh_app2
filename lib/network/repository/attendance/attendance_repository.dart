import '../../../common_enums/attendance_type.dart';
import '../../../constants/app_config.dart';
import '../../request/attendance/mark_attendance_request.dart';
import '../../responses/attendance/attendance_responses.dart';

class AttendanceRepository {
  final Map<AttendanceType, DateTime> _markedToday = {
    AttendanceType.aarti: DateTime.now().toUtc().subtract(
      const Duration(hours: 6),
    ),
  };
  final List<AttendanceLogEntry> _history = List.generate(14, (i) {
    final day = DateTime.now().toUtc().subtract(Duration(days: i + 1));
    return AttendanceLogEntry(
      type: AttendanceType.values[i % AttendanceType.values.length],
      markedAt: day,
      viaCode: i.isEven,
    );
  });

  Future<Map<AttendanceType, DateTime?>> todayStatus() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return {for (final t in AttendanceType.values) t: _markedToday[t]};
  }

  Future<AttendanceMarkResponse> mark(MarkAttendanceRequest request) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final now = DateTime.now().toUtc();
    _markedToday[request.type] = now;
    _history.insert(
      0,
      AttendanceLogEntry(
        type: request.type,
        markedAt: now,
        viaCode: request.viaCode,
      ),
    );
    return AttendanceMarkResponse(
      type: request.type,
      markedAt: now,
      viaCode: request.viaCode,
    );
  }

  Future<List<AttendanceLogEntry>> history({
    DateTime? from,
    DateTime? to,
    AttendanceType? type,
  }) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return _history.where((e) {
      if (type != null && e.type != type) return false;
      if (from != null && e.markedAt.isBefore(from)) return false;
      if (to != null && e.markedAt.isAfter(to)) return false;
      return true;
    }).toList();
  }

  Future<List<SabhaResponse>> upcomingSabhas() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final base = DateTime.now().toUtc();
    return [
      SabhaResponse(
        id: 'sabha-1',
        title: 'Weekly Sabha',
        date: base.add(const Duration(days: 2)),
        startTime: base.add(const Duration(days: 2, hours: 1)),
        endTime: base.add(const Duration(days: 2, hours: 2)),
      ),
      SabhaResponse(
        id: 'sabha-2',
        title: 'Special Sabha',
        date: base.add(const Duration(days: 9)),
        startTime: base.add(const Duration(days: 9, hours: 1)),
        endTime: base.add(const Duration(days: 9, hours: 3)),
      ),
    ];
  }
}
