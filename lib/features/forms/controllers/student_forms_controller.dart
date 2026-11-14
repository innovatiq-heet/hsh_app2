import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/forms/forms_repository.dart';

/// Student → Dashboard → Polls & Forms: open forms and polls for this student.
class StudentFormsController extends GetxController with LoadStateMixin {
  StudentFormsController({FormsRepository? repository})
      : _repo = repository ?? Get.find<FormsRepository>();

  final FormsRepository _repo;

  final forms = <StudentForm>[].obs;

  /// Forms with a submit in flight (a double tap submits once).
  final submitting = <int>{}.obs;

  int get pendingCount => forms.where((f) => !f.hasSubmitted).length;
  int get pendingMandatoryCount => forms.where((f) => f.isMandatory && !f.hasSubmitted).length;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Keeps the server's order (mandatory first, newest first).
  Future<void> load({bool showLoading = true}) => guard(() async {
        forms.assignAll(await _repo.active());
      }, showLoading: showLoading);

  StudentForm? byId(int id) => forms.firstWhereOrNull((f) => f.id == id);

  /// Records that the student opened [form], once. Never blocks the screen.
  Future<void> markViewed(StudentForm form) async {
    if (form.hasViewed) return;
    _replace(form.copyWith(hasViewed: true));
    try {
      await _repo.recordView(form.id);
    } catch (_) {
      // Analytics only; the student can still answer.
    }
  }

  /// The student's saved answers for [form], fetched if the list lacks them.
  Future<FormResponse?> responseFor(StudentForm form) async {
    if (form.myResponse != null) return form.myResponse;
    if (!form.hasSubmitted) return null;
    try {
      final r = await _repo.myResponse(form.id);
      if (r != null) _replace(form.copyWith(myResponse: r));
      return r;
    } catch (_) {
      return null;
    }
  }

  /// Submits [raw] answers (as held by the fill screen). Returns null on
  /// success, or the message to show; answers are kept on failure.
  Future<String?> submit(StudentForm form, Map<String, dynamic> raw) async {
    if (submitting.contains(form.id)) return null;
    final problem = validateAnswers(form.fields, raw);
    if (problem != null) return problem;
    final answers = encodeAnswers(form.fields, raw);
    submitting.add(form.id);
    try {
      await _repo.submit(form.id, answers);
      _replace(form.copyWith(
        hasViewed: true,
        hasSubmitted: true,
        myResponse: FormResponse(submittedAt: DateTime.now().toUtc(), answers: answers),
      ));
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong, try again.';
    } finally {
      submitting.remove(form.id);
    }
  }

  void _replace(StudentForm updated) {
    final i = forms.indexWhere((f) => f.id == updated.id);
    if (i != -1) forms[i] = updated;
  }

  // --- answers ---

  static bool _isEmpty(dynamic v) =>
      v == null ||
      (v is String && v.trim().isEmpty) ||
      (v is Iterable && v.isEmpty);

  /// The first problem with [raw], or null.
  static String? validateAnswers(List<FormFieldDef> fields, Map<String, dynamic> raw) {
    for (final f in fields) {
      final v = raw[f.answerKey];
      if (_isEmpty(v)) {
        if (f.required) return 'Please answer "${f.label}".';
        continue;
      }
      switch (f.type) {
        case FormFieldType.number:
          if (num.tryParse(v.toString().trim()) == null) return '"${f.label}" needs a number.';
        case FormFieldType.rating:
          final n = v is int ? v : int.tryParse(v.toString());
          if (n == null || n < 1 || n > 5) return 'Rate "${f.label}" from 1 to 5.';
        case FormFieldType.poll || FormFieldType.radio || FormFieldType.select:
          if (!f.options.contains(v.toString())) return 'Pick an option for "${f.label}".';
        case FormFieldType.checkbox:
          final picked = (v as Iterable).map((e) => e.toString());
          if (picked.any((p) => !f.options.contains(p))) return 'Pick valid options for "${f.label}".';
        case FormFieldType.boolean || FormFieldType.text || FormFieldType.textarea:
          break;
      }
    }
    return null;
  }

  /// [raw] in the shape the API expects, keyed by `field.id ?? key ?? label`:
  /// checkbox → `List<String>`, boolean → `bool`, rating → `int`,
  /// number → `num`, text → trimmed `String`. Unanswered optional fields are
  /// left out.
  static Map<String, dynamic> encodeAnswers(List<FormFieldDef> fields, Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    for (final f in fields) {
      final v = raw[f.answerKey];
      if (_isEmpty(v)) continue;
      out[f.answerKey] = switch (f.type) {
        FormFieldType.checkbox => [
            for (final o in f.options)
              if ((v as Iterable).map((e) => e.toString()).contains(o)) o,
          ],
        FormFieldType.boolean => v == true || v.toString().toLowerCase() == 'yes' || v.toString() == 'true',
        FormFieldType.rating => v is int ? v : int.parse(v.toString()),
        FormFieldType.number => num.parse(v.toString().trim()),
        FormFieldType.text || FormFieldType.textarea => v.toString().trim(),
        _ => v.toString(),
      };
    }
    return out;
  }
}
