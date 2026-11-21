/// A warden alert from `GET /screen-time/alerts` (HAMS_WEB): a student tried
/// to turn off removal protection, turned it off, or may have uninstalled the
/// app.
class ScreenTimeAlert {
  final int id;
  final String type;
  final String message;
  final DateTime? createdAt;
  final bool read;

  /// Numeric `students.id` (never a bank code); null when the row has none.
  final int? studentId;
  final String studentName;
  final String room;
  final String group;

  const ScreenTimeAlert({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.read,
    required this.studentId,
    required this.studentName,
    required this.room,
    required this.group,
  });

  static const typeAdminProtected = 'admin_protected';
  static const typeAdminDisabled = 'admin_disabled';
  static const typeSuspectedUninstall = 'suspected_uninstall';

  /// Short title shown on the card.
  String get title => switch (type) {
        typeAdminProtected => 'Removal attempt blocked',
        typeAdminDisabled => 'Protection turned off',
        typeSuspectedUninstall => 'App may be uninstalled',
        _ => 'Screen time alert',
      };

  /// Whether the phone may no longer be monitored (worse than a blocked attempt).
  bool get isSevere => type == typeAdminDisabled || type == typeSuspectedUninstall;

  /// Parses one row; returns null for a row without a usable id.
  static ScreenTimeAlert? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final id = int.tryParse('${raw['id'] ?? ''}');
    if (id == null) return null;
    final student = raw['student'] is Map ? raw['student'] as Map : raw;
    final sid = '${student['id'] ?? raw['student_id'] ?? ''}'.trim();
    // A `students.id` is a positive integer without a leading zero.
    final studentId = RegExp(r'^[1-9]\d*$').hasMatch(sid) ? int.parse(sid) : null;
    final readRaw = raw['read'] ?? raw['is_read'];
    return ScreenTimeAlert(
      id: id,
      type: '${raw['type'] ?? ''}',
      message: '${raw['message'] ?? ''}',
      createdAt: DateTime.tryParse('${raw['created_at'] ?? raw['createdAt'] ?? ''}')?.toLocal(),
      read: readRaw == true || readRaw == 1 || readRaw == '1' || raw['read_at'] != null,
      studentId: studentId,
      studentName: '${student['name'] ?? raw['student_name'] ?? 'Student'}',
      room: '${student['room_number'] ?? student['room'] ?? ''}',
      group: '${student['group_name'] ?? student['group'] ?? ''}',
    );
  }

  /// Alerts from a response body: `{data: [...]}`, `{alerts: [...]}` or a list.
  static List<ScreenTimeAlert> parseList(dynamic body) {
    final raw = body is List
        ? body
        : body is Map
            ? (body['data'] is List
                ? body['data']
                : body['alerts'] is List
                    ? body['alerts']
                    : body['data'] is Map && body['data']['alerts'] is List
                        ? body['data']['alerts']
                        : const [])
            : const [];
    return (raw as List).map(tryParse).whereType<ScreenTimeAlert>().toList();
  }

  ScreenTimeAlert markedRead() => ScreenTimeAlert(
        id: id,
        type: type,
        message: message,
        createdAt: createdAt,
        read: true,
        studentId: studentId,
        studentName: studentName,
        room: room,
        group: group,
      );
}
