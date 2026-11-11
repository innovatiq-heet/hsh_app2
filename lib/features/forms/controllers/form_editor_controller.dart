import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/forms/forms_repository.dart';
import '../../../core/network/repository/screentime/screen_time_repository.dart';
import '../../../core/network/repository/students/student_picker_source.dart';
import '../../../core/network/repository/tags/tags_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/utils/student_picker_host.dart';
import 'forms_manager_gate.dart';

/// One question being edited. Immutable; the editor replaces it on change.
class QuestionDraft {
  /// Stable key in `answers`. Kept when editing so old responses still match.
  final String id;
  final String label;
  final FormFieldType type;
  final bool required;
  final List<String> options;

  const QuestionDraft({
    required this.id,
    this.label = '',
    this.type = FormFieldType.radio,
    this.required = true,
    this.options = const [],
  });

  QuestionDraft copyWith({String? label, FormFieldType? type, bool? required, List<String>? options}) =>
      QuestionDraft(
        id: id,
        label: label ?? this.label,
        type: type ?? this.type,
        required: required ?? this.required,
        options: options ?? this.options,
      );

  List<String> get cleanOptions => [
        for (final o in options)
          if (o.trim().isNotEmpty) o.trim(),
      ];

  FormFieldDef toField() => FormFieldDef(
        id: id,
        label: label.trim(),
        type: type,
        required: required,
        options: type.hasOptions ? cleanOptions : const [],
      );

  factory QuestionDraft.fromField(FormFieldDef f, String fallbackId) => QuestionDraft(
        id: f.answerKey.isEmpty ? fallbackId : f.answerKey,
        label: f.label,
        type: f.type,
        required: f.required,
        options: f.options,
      );
}

/// Operator → Forms & Polls → New / Edit.
///
/// Route argument: a [HostelForm] or its id to edit; nothing to create.
class FormEditorController extends GetxController with FormsManagerGate, StudentPickerHost {
  FormEditorController({
    FormsRepository? repository,
    TagsRepository? tagsRepository,
    ScreenTimeRepository? screenTimeRepository,
    HostelForm? editing,
    DateTime Function()? clock,
  })  : _repo = repository ?? Get.find<FormsRepository>(),
        _tagsRepo = tagsRepository ?? Get.find<TagsRepository>(),
        _screenTimeRepo = screenTimeRepository,
        _editingArg = editing,
        _now = clock ?? DateTime.now;

  final FormsRepository _repo;
  final TagsRepository _tagsRepo;
  final ScreenTimeRepository? _screenTimeRepo;
  final HostelForm? _editingArg;
  final DateTime Function() _now;

  /// Forms can target alumni, so they can be picked too.
  @override
  bool get includeAlumniInPicker => true;

  @override
  late final StudentPickerSource studentSource =
      StudentPickerSource(tags: _tagsRepo, screenTime: _screenTimeRepo);

  static const floorIds = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

  /// The form being edited, or null when creating.
  final original = Rxn<HostelForm>();
  final isLoadingForm = false.obs;
  final loadError = RxnString();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final title = ''.obs;

  final kind = FormKind.poll.obs;
  final questions = <QuestionDraft>[].obs;

  final audience = FormAudience.current.obs;
  final selectedFloors = <int>{}.obs;
  final selectedTagIds = <int>{}.obs;
  final tags = <StudentTag>[].obs;

  late final startTime = _now().obs;
  late final endTime = _now().add(const Duration(days: 1)).obs;
  final isActive = true.obs;
  final isMandatory = false.obs;

  final isSaving = false.obs;

  int _nextQuestion = 1;

  bool get isEditing => original.value != null;

  @override
  void onInit() {
    super.onInit();
    titleController.addListener(() => title.value = titleController.text);
    _start();
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }

  Future<void> _start() async {
    if (!await ensureManager()) return;
    _loadTags();
    final arg = _editingArg ?? Get.arguments;
    if (arg is HostelForm) {
      // The list item may be partial; fetch the full form.
      _fill(arg);
      await _fetch(arg.id);
    } else if (int.tryParse(arg?.toString() ?? '') case final id?) {
      await _fetch(id);
    } else {
      questions.add(_newQuestion(FormFieldType.poll));
    }
  }

  Future<void> _fetch(int id) async {
    isLoadingForm.value = true;
    loadError.value = null;
    try {
      _fill(await _repo.get(id));
    } on ApiException catch (e) {
      loadError.value = e.message;
    } catch (_) {
      loadError.value = 'Could not load this form.';
    } finally {
      isLoadingForm.value = false;
    }
  }

  void _fill(HostelForm f) {
    original.value = f;
    titleController.text = f.title;
    descriptionController.text = f.description ?? '';
    kind.value = f.kind;
    var n = 1;
    questions.assignAll([for (final q in f.fields) QuestionDraft.fromField(q, 'q${n++}')]);
    _nextQuestion = questions.length + 1;
    audience.value = f.audience;
    selectedFloors.assignAll(f.targetFloors);
    selectedTagIds.assignAll(f.targetTags);
    // Names fill in once the picker list loads; ids are what matter.
    selectedStudents.assignAll([
      for (final id in f.targetStudentIds) PickableStudent(id: id, name: 'Student #$id', room: ''),
    ]);
    if (f.targetStudentIds.isNotEmpty) _resolveStudentNames();
    if (f.startTime != null) startTime.value = f.startTime!.toLocal();
    if (f.endTime != null) endTime.value = f.endTime!.toLocal();
    isActive.value = f.isActive;
    isMandatory.value = f.isMandatory;
  }

  Future<void> _resolveStudentNames() async {
    await loadStudents();
    final byId = {for (final s in students) s.id: s};
    selectedStudents.assignAll([for (final s in selectedStudents) byId[s.id] ?? s]);
  }

  Future<void> _loadTags() async {
    try {
      tags.assignAll(dedupeTags(await _tagsRepo.getTags()));
    } catch (_) {
      // Students and floors still work without tags.
    }
  }

  // --- questions ---

  QuestionDraft _newQuestion(FormFieldType type) {
    final taken = questions.map((q) => q.id).toSet();
    var id = 'q${_nextQuestion++}';
    while (taken.contains(id)) {
      id = 'q${_nextQuestion++}';
    }
    return QuestionDraft(
      id: id,
      type: type,
      options: type.hasOptions ? const ['', ''] : const [],
    );
  }

  void setKind(FormKind value) {
    kind.value = value;
    if (value == FormKind.poll && questions.isEmpty) questions.add(_newQuestion(FormFieldType.poll));
  }

  void addQuestion([FormFieldType type = FormFieldType.radio]) => questions.add(_newQuestion(type));

  void updateQuestion(int index, QuestionDraft draft) {
    if (index >= 0 && index < questions.length) questions[index] = draft;
  }

  void removeQuestion(int index) {
    if (index >= 0 && index < questions.length) questions.removeAt(index);
  }

  void moveQuestion(int from, int to) {
    if (from < 0 || from >= questions.length || to < 0 || to >= questions.length) return;
    final q = questions.removeAt(from);
    questions.insert(to, q);
  }

  // --- audience ---

  void toggleFloor(int id) {
    if (!selectedFloors.remove(id)) selectedFloors.add(id);
  }

  void toggleTag(int id) {
    if (!selectedTagIds.remove(id)) selectedTagIds.add(id);
  }

  // --- validation & payload ---

  /// The first problem to fix before saving, or null. Mirrors the API's
  /// checks so the admin isn't bounced by a 400.
  String? get validationError {
    final t = title.value.trim();
    if (t.isEmpty) return 'Add a title.';
    if (t.length > 200) return 'Keep the title under 200 characters.';
    if (questions.isEmpty) return 'Add at least one question.';
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final n = i + 1;
      if (q.label.trim().isEmpty) return 'Question $n needs a text.';
      final opts = q.cleanOptions;
      if (opts.length < q.type.minOptions) {
        return 'Question $n needs at least ${q.type.minOptions} '
            '${q.type.minOptions == 1 ? 'option' : 'options'}.';
      }
      if (opts.map((o) => o.toLowerCase()).toSet().length != opts.length) {
        return 'Question $n has the same option twice.';
      }
    }
    if (!endTime.value.isAfter(startTime.value)) return 'The end time must be after the start time.';
    if (audience.value == FormAudience.selected &&
        selectedStudents.isEmpty &&
        selectedFloors.isEmpty &&
        selectedTagIds.isEmpty) {
      return 'Pick students, floors or tags for a selected audience.';
    }
    return null;
  }

  /// The full request body for what is on screen.
  Map<String, dynamic> buildPayload() {
    final selected = audience.value == FormAudience.selected;
    final description = descriptionController.text.trim();
    return {
      'title': title.value.trim(),
      'description': description.isEmpty ? null : description,
      'form_type': kind.value.name,
      'fields': [for (final q in questions) q.toField().toJson()],
      'target_audience': audience.value.name,
      'target_student_ids': selected && selectedStudents.isNotEmpty
          ? [for (final s in selectedStudents) s.id]
          : null,
      'target_floors': selected && selectedFloors.isNotEmpty ? (selectedFloors.toList()..sort()) : null,
      'target_tags': selected && selectedTagIds.isNotEmpty ? (selectedTagIds.toList()..sort()) : null,
      'start_time': formTimeToJson(startTime.value),
      'end_time': formTimeToJson(endTime.value),
      'is_active': isActive.value,
      'is_mandatory': isMandatory.value,
    };
  }

  /// The same body for [form] as it was loaded, to diff against on edit.
  static Map<String, dynamic> payloadOf(HostelForm form) {
    final selected = form.audience == FormAudience.selected;
    return {
      'title': form.title.trim(),
      'description': form.description,
      'form_type': form.kind.name,
      'fields': [for (final f in form.fields) f.toJson()],
      'target_audience': form.audience.name,
      'target_student_ids': selected && form.targetStudentIds.isNotEmpty ? form.targetStudentIds : null,
      'target_floors': selected && form.targetFloors.isNotEmpty ? (form.targetFloors.toList()..sort()) : null,
      'target_tags': selected && form.targetTags.isNotEmpty ? (form.targetTags.toList()..sort()) : null,
      'start_time': form.startTime == null ? null : formTimeToJson(form.startTime!),
      'end_time': form.endTime == null ? null : formTimeToJson(form.endTime!),
      'is_active': form.isActive,
      'is_mandatory': form.isMandatory,
    };
  }

  /// Only the keys whose value differs from the loaded form.
  Map<String, dynamic> changedFields() {
    final now = buildPayload();
    final f = original.value;
    if (f == null) return now;
    final before = payloadOf(f);
    return {
      for (final e in now.entries)
        if (jsonEncode(e.value) != jsonEncode(before[e.key])) e.key: e.value,
    };
  }

  /// Creates or updates. Returns true on success; on failure the form stays
  /// as it is and the server's message is shown.
  Future<bool> save() async {
    if (isSaving.value) return false;
    final problem = validationError;
    if (problem != null) {
      AppSnackbar.warning('Check the form', problem);
      return false;
    }
    isSaving.value = true;
    try {
      final f = original.value;
      if (f == null) {
        await _repo.create(buildPayload());
      } else {
        final changes = changedFields();
        if (changes.isEmpty) return true;
        await _repo.update(f.id, changes);
      }
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error('Not Saved', e.message);
      return false;
    } catch (_) {
      AppSnackbar.error('Not Saved', 'Something went wrong, try again.');
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
