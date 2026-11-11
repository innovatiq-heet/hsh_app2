import 'package:get/get.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/students/student_picker_source.dart';

/// Picker state for a controller that lets an admin choose students one by
/// one (used with `StudentPickerSheet`).
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

  Future<void> loadStudents({bool force = false}) async {
    if (isStudentsLoading.value || (students.isNotEmpty && !force)) return;
    isStudentsLoading.value = true;
    studentsError.value = null;
    try {
      students.assignAll(await studentSource.load(includeAlumni: includeAlumniInPicker));
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
