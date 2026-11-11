import 'package:get/get.dart';
import '../../../models/students/pickable_student.dart';
import '../screentime/screen_time_repository.dart';
import '../tags/tags_repository.dart';

/// Students an admin can pick by hand, each with a numeric `students.id`.
///
/// Same sources as Assign Tag: `/students?all=true`, falling back to the
/// Screen Time directory. The phonebook cache (bank codes) is never used.
class StudentPickerSource {
  StudentPickerSource({TagsRepository? tags, ScreenTimeRepository? screenTime})
      : _tags = tags ?? Get.find<TagsRepository>(),
        _screenTime = screenTime ?? ScreenTimeRepository();

  final TagsRepository _tags;
  final ScreenTimeRepository _screenTime;

  Future<List<PickableStudent>> load({bool includeAlumni = false}) async {
    var rows = <Map<String, dynamic>>[];
    try {
      rows = await _tags.getStudentsForAssignment();
    } catch (_) {}
    if (rows.isEmpty) {
      final page = await _screenTime.students(limit: 1000, offset: 0);
      rows = page.students.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    return pickableStudentsFromRows(rows, includeAlumni: includeAlumni);
  }
}
