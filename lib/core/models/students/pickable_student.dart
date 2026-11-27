import '../../../features/phonebook/models/phonebook_models.dart' show PhonebookStudent;
import '../../utils/string_formatting.dart';
import '../tags/student_tag_model.dart';

/// A student an admin can pick by hand (Broadcast recipients, Forms & Polls
/// targets). The [id] is always the numeric `students.id`.
class PickableStudent {
  /// Numeric `students.id`; the only identifier ever sent.
  final int id;
  final String name;
  final String room;
  final bool isAlumni;

  /// For the picker's filters only; empty when the row didn't say.
  final int? floorId;
  final String group;
  final List<StudentTag> tags;

  const PickableStudent({
    required this.id,
    required this.name,
    required this.room,
    this.isAlumni = false,
    this.floorId,
    this.group = '',
    this.tags = const [],
  });

  /// From the room number, else the row's `floor_id`; 0 is the ground floor.
  /// Alumni are on no floor.
  int? get floor => isAlumni ? null : (PhonebookStudent.floorOfRoom(room) ?? floorId);

  @override
  bool operator ==(Object other) => other is PickableStudent && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The numeric `students.id` from a directory row, or null.
///
/// Reads `id` only, and only a positive integer written without a leading
/// zero. Bank codes and `student_code` (`0768`, `HSH-0768`) must never become
/// an id: they collide with other students' ids (AGENTS.md §4).
int? studentIdOf(Map row) {
  final raw = row['id'];
  if (raw is int) return raw > 0 ? raw : null;
  final s = raw?.toString().trim() ?? '';
  return RegExp(r'^[1-9]\d*$').hasMatch(s) ? int.parse(s) : null;
}

/// True for a room value that means the student has left (alumni).
bool isAlumniRoom(String room) {
  final r = room.trim().toLowerCase();
  return r.isEmpty || r == 'alumni' || r == 'n/a' || r == 'none' || r == 'null';
}

const _noGroup = {'', 'not available', 'n/a', 'na', 'none', 'null', '-'};

/// The data spells one group several ways ("param", "Param "), so the name is
/// put in one form; the server compares groups ignoring case too.
String _groupOf(Map row) {
  final group = (row['group_name'] ?? row['groupName'] ?? '').toString().trim();
  return _noGroup.contains(group.toLowerCase()) ? '' : formatPersonName(group);
}

List<StudentTag> _tagsOf(Map row) {
  final raw = row['tags'];
  if (raw is! List) return const [];
  return dedupeTags([
    for (final t in raw)
      if (t is Map) StudentTag.fromJson(Map<String, dynamic>.from(t)),
  ].where((t) => t.id > 0 && t.name.isNotEmpty));
}

/// Turns directory rows into [PickableStudent]s: numeric ids only, no
/// duplicates, sorted by name. Alumni are kept only when [includeAlumni].
List<PickableStudent> pickableStudentsFromRows(
  Iterable<Map> rows, {
  bool includeAlumni = false,
}) {
  final seen = <int>{};
  final list = <PickableStudent>[];
  for (final m in rows) {
    final id = studentIdOf(m);
    if (id == null || !seen.add(id)) continue;
    final status = (m['student_status'] ?? m['studentStatus'] ?? '').toString().trim().toLowerCase();
    if (status == 'cancel-admission' || status == 'rejected-admission') continue;
    final room = (m['room_number'] ?? m['room'] ?? '').toString().trim();
    final alumni = isAlumniRoom(room);
    if (alumni && !includeAlumni) continue;
    final name = (m['name'] ?? m['fullName'] ?? '').toString().trim();
    list.add(PickableStudent(
      id: id,
      name: name.isEmpty ? 'Student' : name,
      room: alumni ? 'Alumni' : room,
      isAlumni: alumni,
      floorId: int.tryParse('${m['floor_id'] ?? m['floorId'] ?? ''}'),
      group: _groupOf(m),
      tags: _tagsOf(m),
    ));
  }
  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}
