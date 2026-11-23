import '../../../core/models/students/pickable_student.dart';

/// Who in the selected tags a broadcast goes to.
enum TagMemberScope { all, current, alumni }

/// Members of some tags, split the way the server counts broadcast
/// recipients (`ACTIVE_STUDENT_SQL` in HAMS_WEB `broadcasts.service.ts`):
///
/// - **current**: active (`is_active = 1`) and not left / cancelled / rejected;
/// - **alumni**: no room (empty, `N/A`, `alumni`, ...) and not cancelled /
///   rejected (left students count here).
///
/// Anyone else (cancelled or rejected admissions) never gets a broadcast.
class TagMembers {
  final List<int> current;
  final List<int> alumni;

  const TagMembers({this.current = const [], this.alumni = const []});

  static const empty = TagMembers();

  List<int> idsFor(TagMemberScope scope) => switch (scope) {
        TagMemberScope.current => current,
        TagMemberScope.alumni => alumni,
        TagMemberScope.all => [...current, ...alumni],
      };

  static const _noRoom = {'', 'n/a', 'na', 'none', 'null', '-', '--', '0', 'unassigned', 'nil', 'alumni'};

  /// Students (rows of `GET /students?all=true`, each with its `tags`) who
  /// have at least one of [tagIds]. Ids are numeric `students.id` only
  /// ([studentIdOf]); a row without one is skipped.
  static TagMembers of(Iterable<Map> rows, Set<int> tagIds) {
    if (tagIds.isEmpty) return empty;
    final current = <int>[];
    final alumni = <int>[];
    final seen = <int>{};
    for (final row in rows) {
      final id = studentIdOf(row);
      if (id == null || seen.contains(id)) continue;
      if (!_hasAnyTag(row['tags'], tagIds)) continue;

      final status = '${row['student_status'] ?? row['studentStatus'] ?? ''}'.trim().toLowerCase();
      if (status == 'cancel-admission' || status == 'rejected-admission') continue;
      final active = row['is_active'] == true || row['is_active'] == 1 || '${row['is_active']}' == '1';
      final room = '${row['room_number'] ?? row['room'] ?? ''}'.trim().toLowerCase();

      if (active && status != 'left') {
        current.add(id);
        seen.add(id);
      } else if (_noRoom.contains(room)) {
        alumni.add(id);
        seen.add(id);
      }
    }
    return TagMembers(current: current, alumni: alumni);
  }

  static bool _hasAnyTag(dynamic tags, Set<int> tagIds) {
    if (tags is! List) return false;
    for (final t in tags) {
      final raw = t is Map ? (t['id'] ?? t['tag_id']) : t;
      final id = raw is int ? raw : int.tryParse('${raw ?? ''}');
      if (id != null && tagIds.contains(id)) return true;
    }
    return false;
  }
}
