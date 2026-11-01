/// One page of `GET /screen-time/students`.
///
/// The API has answered in a few shapes over time (a bare list, or an object
/// holding the list under `students` / `data`, with the total under one of
/// several keys); this reads all of them in one place.
class StudentsPage {
  /// The raw student entries of this page (maps).
  final List<dynamic> students;

  /// The directory size the server reported. For a bare list there is no
  /// total, so this is just the page length (see [totalReported]).
  final int total;

  /// True when the response carried a real total, not just the page length.
  final bool totalReported;

  /// True when the response had a students list at all (even an empty one),
  /// as opposed to an unexpected body.
  final bool hasPayload;

  /// The whole response body, for readers of other fields (summary counts).
  final dynamic body;

  const StudentsPage({
    required this.students,
    required this.total,
    required this.totalReported,
    required this.hasPayload,
    required this.body,
  });

  factory StudentsPage.parse(dynamic body) {
    final data = body is Map ? (body['data'] ?? body) : body;
    var students = <dynamic>[];
    var total = 0;
    var reported = false;
    var hasPayload = false;

    if (data is List) {
      students = List<dynamic>.from(data);
      total = students.length;
      hasPayload = students.isNotEmpty;
    } else if (data is Map) {
      reported = true;
      if (data['students'] is List) {
        students = List<dynamic>.from(data['students'] as List);
      } else if (data['data'] is List) {
        students = List<dynamic>.from(data['data'] as List);
      }
      final pagination = data['pagination'];
      total = _toInt(
        data['total'] ??
            data['totalCount'] ??
            data['count'] ??
            data['totalStudents'] ??
            (pagination is Map ? pagination['total'] : null),
      );
      hasPayload = students.isNotEmpty ||
          data.containsKey('students') ||
          data.containsKey('data');
    }

    return StudentsPage(
      students: students,
      total: total,
      totalReported: reported,
      hasPayload: hasPayload,
      body: body,
    );
  }

  /// Same coercion as the Screen Time controllers' `toInt`.
  static int _toInt(dynamic v) {
    if (v is num) return v.round();
    if (v is String) return num.tryParse(v)?.round() ?? 0;
    return 0;
  }
}
