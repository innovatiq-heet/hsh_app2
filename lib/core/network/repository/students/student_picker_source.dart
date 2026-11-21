import 'package:get/get.dart';
import '../../../models/students/pickable_student.dart';
import '../screentime/screen_time_repository.dart';
import '../tags/tags_repository.dart';

class _Cached {
  final List<PickableStudent> all;
  final DateTime at;
  final int generation;

  const _Cached(this.all, this.at, this.generation);
}

/// Students an admin can pick by hand, each with a numeric `students.id`.
///
/// Same sources as Assign Tag: `/students?all=true`, falling back to the
/// Screen Time directory. The phonebook cache (bank codes) is never used.
///
/// That call returns every student with full details, so it is slow. The
/// result is kept in memory and shared: a second picker (another screen, or
/// the same one reopened) is instant, and two pickers asking at the same time
/// share one request. The cache is dropped on logout ([clearCache]) and after
/// [maxAge].
class StudentPickerSource {
  StudentPickerSource({
    TagsRepository? tags,
    ScreenTimeRepository? screenTime,
    DateTime Function()? clock,
  }) : _tags = tags ?? Get.find<TagsRepository>(),
       _screenTime = screenTime ?? ScreenTimeRepository(),
       _now = clock ?? DateTime.now;

  final TagsRepository _tags;
  final ScreenTimeRepository _screenTime;
  final DateTime Function() _now;

  /// How long a downloaded list is reused.
  static const maxAge = Duration(minutes: 15);

  // Keyed by the repository, so each app (and each test) has its own.
  static final _cache = Expando<_Cached>('student picker cache');
  static final _inflight = Expando<Future<List<PickableStudent>>>('student picker request');
  static int _generation = 0;

  /// Forgets every downloaded list (logout: the next admin must not see it).
  static void clearCache() => _generation++;

  /// The students, residents only unless [includeAlumni]. Reuses the
  /// downloaded list; [refresh] downloads it again.
  Future<List<PickableStudent>> load({bool includeAlumni = false, bool refresh = false}) async {
    final cached = _cache[_tags];
    if (!refresh && cached != null && cached.generation == _generation && _now().difference(cached.at) < maxAge) {
      return _filter(cached.all, includeAlumni);
    }
    final running = _inflight[_tags];
    if (!refresh && running != null) return _filter(await running, includeAlumni);

    final generation = _generation;
    final request = _download();
    _inflight[_tags] = request;
    try {
      final all = await request;
      if (generation == _generation) _cache[_tags] = _Cached(all, _now(), generation);
      return _filter(all, includeAlumni);
    } finally {
      if (identical(_inflight[_tags], request)) _inflight[_tags] = null;
    }
  }

  /// Everyone, alumni included; callers filter.
  Future<List<PickableStudent>> _download() async {
    var rows = <Map<String, dynamic>>[];
    try {
      rows = await _tags.getStudentsForAssignment();
    } catch (_) {}
    if (rows.isEmpty) {
      final page = await _screenTime.students(limit: 1000, offset: 0);
      rows = page.students.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    return pickableStudentsFromRows(rows, includeAlumni: true);
  }

  static List<PickableStudent> _filter(List<PickableStudent> all, bool includeAlumni) =>
      includeAlumni ? all : [for (final s in all) if (!s.isAlumni) s];
}
