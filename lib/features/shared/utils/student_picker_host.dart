import 'package:get/get.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/students/student_picker_source.dart';

/// Picker state for a controller that lets an admin choose students one by
/// one (used with `StudentPickerScreen`).
mixin StudentPickerHost on GetxController {
  /// Where the pickable students come from.
  StudentPickerSource get studentSource;

  /// Whether students who have left can be picked.
  bool get includeAlumniInPicker => false;

  /// Called after [selectedStudents] changes.
  void onStudentsChanged() {}

  final students = <PickableStudent>[].obs;
  final isStudentsLoading = false.obs;
  final studentsError = RxnString();
  final selectedStudents = <PickableStudent>[].obs;

  Future<void>? _loadingStudents;

  /// Loads the students once. A call while one is running waits for it (so
  /// the picker and a background start share one download); [force] reloads.
  Future<void> loadStudents({bool force = false}) {
    final running = _loadingStudents;
    if (running != null) return running;
    if (students.isNotEmpty && !force) return Future.value();
    return _loadingStudents = _fetchStudents(force: force).whenComplete(() => _loadingStudents = null);
  }

  Future<void> _fetchStudents({required bool force}) async {
    isStudentsLoading.value = true;
    studentsError.value = null;
    try {
      students.assignAll(await studentSource.load(includeAlumni: includeAlumniInPicker, refresh: force));
    } on ApiException catch (e) {
      studentsError.value = e.message;
    } catch (_) {
      studentsError.value = 'Could not load students.';
    } finally {
      isStudentsLoading.value = false;
    }
  }

  void addStudent(PickableStudent student) {
    if (selectedStudents.contains(student)) return;
    selectedStudents.add(student);
    onStudentsChanged();
  }

  void removeStudent(PickableStudent student) {
    if (selectedStudents.remove(student)) onStudentsChanged();
  }

  void toggleStudent(PickableStudent student) =>
      selectedStudents.contains(student) ? removeStudent(student) : addStudent(student);
}
