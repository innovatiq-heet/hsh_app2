import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/forms/form_models.dart';
import 'package:hsh_app2/core/models/students/pickable_student.dart';
import 'package:hsh_app2/core/network/repository/forms/forms_repository.dart';
import 'package:hsh_app2/core/network/repository/tags/tags_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/forms/controllers/form_editor_controller.dart';
import 'package:hsh_app2/features/forms/controllers/forms_list_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Operator → Forms & Polls against `/forms`, offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;

  Map<String, dynamic> formJson({
    int id = 12,
    String status = 'active',
    bool active = true,
    String audience = 'current',
  }) =>
      {
        'id': id,
        'title': 'Dinner Poll',
        'description': null,
        'form_type': 'poll',
        'fields': [
          {'id': 'q1', 'label': 'Choose item', 'type': 'poll', 'required': true, 'options': ['Khichdi', 'Pulao']},
        ],
        'target_audience': audience,
        'target_student_ids': null,
        'target_floors': null,
        'target_tags': null,
        'start_time': '2026-11-11 18:00:00',
        'end_time': '2026-11-12 21:00:00',
        'is_active': active,
        'is_mandatory': false,
        'total_targeted': 420,
        'total_viewed': 180,
        'total_responded': 125,
        'seen_not_answered': 55,
        'status': status,
        'created_at': '2026-11-11 18:00:00',
        'updated_at': '2026-11-11 18:00:00',
      };

  void session(String role) {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': role, 'token': 'token', 'name': 'User'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    Get.put(FormsRepository());
    Get.put(TagsRepository());
    api.on('GET /tags', {'success': true, 'data': []});
  }

  setUp(() => session('admin'));
  tearDown(Get.reset);

  group('model', () {
    test('IST times without a zone are read as IST; zoned times as given', () {
      expect(parseFormTime('2026-11-11 18:00:00'), DateTime.utc(2026, 11, 11, 12, 30));
      expect(parseFormTime('2026-11-11T12:30:00.000Z'), DateTime.utc(2026, 11, 11, 12, 30));
      expect(parseFormTime('2026-11-11T18:00:00+05:30'), DateTime.utc(2026, 11, 11, 12, 30));
      expect(parseFormTime(null), isNull);
      expect(formTimeToJson(DateTime.utc(2026, 11, 11, 12, 30)), '2026-11-11T12:30:00.000Z');
    });

    test('answer key is id, then key, then label', () {
      expect(const FormFieldDef(id: 'a', key: 'b', label: 'c', type: FormFieldType.text).answerKey, 'a');
      expect(const FormFieldDef(key: 'b', label: 'c', type: FormFieldType.text).answerKey, 'b');
      expect(const FormFieldDef(label: 'c', type: FormFieldType.text).answerKey, 'c');
    });

    test('students/floors audiences are the selected audience; floor 0 is kept', () {
      final f = HostelForm.fromJson({
        ...formJson(audience: 'floors'),
        'target_floors': [0, '3'],
        'target_student_ids': ['102'],
      });
      expect(f.audience, FormAudience.selected);
      expect(f.targetFloors, [0, 3]);
      expect(f.targetStudentIds, [102]);
    });
  });

  group('list', () {
    test('loads forms with stats and filters by status', () async {
      api.on('GET /forms', {
        'success': true,
        'status': 'ok',
        'data': [formJson(), formJson(id: 13, status: 'expired')],
      });
      final c = Get.put(FormsListController());
      await until(() => !c.isLoading.value, reason: 'forms load');

      final f = c.forms.first;
      expect(f.kind, FormKind.poll);
      expect(f.startTime, DateTime.utc(2026, 11, 11, 12, 30));
      expect(f.totalResponded, 125);
      expect(f.fields.single.options, ['Khichdi', 'Pulao']);
      c.filter.value = FormStatus.expired;
      expect(c.visible.map((f) => f.id), [13]);
    });

    test('a warden may manage; a student is sent away before any request', () async {
      Get.reset();
      session('warden');
      api.on('GET /forms', {'success': true, 'data': []});
      final warden = Get.put(FormsListController());
      await until(() => !warden.isLoading.value, reason: 'warden load');
      expect(warden.accessDenied.value, isFalse);

      Get.reset();
      session('student');
      final student = Get.put(FormsListController());
      await until(() => student.accessDenied.value, reason: 'gate');
      expect(api.called('GET /forms'), isEmpty);
    });

    test('pausing shows at once and is rolled back when it fails', () async {
      api.on('GET /forms', {'success': true, 'data': [formJson()]});
      final c = Get.put(FormsListController());
      await until(() => !c.isLoading.value, reason: 'forms load');

      api.on('POST /forms/12/toggle', {'success': false, 'message': 'Server error'}, status: 500);
      final done = c.toggle(c.forms.first);
      expect(c.forms.first.isActive, isFalse, reason: 'optimistic');
      expect(c.forms.first.status, FormStatus.disabled);
      await done;
      expect(c.forms.first.isActive, isTrue);
      expect(c.forms.first.status, FormStatus.active);

      api.on('POST /forms/12/toggle', {'success': true, 'status': 'ok', 'is_active': false});
      await c.toggle(c.forms.first);
      expect(c.forms.first.isActive, isFalse);
      expect(c.busyIds, isEmpty);
    });

    test('delete removes the form; a failure keeps it', () async {
      api.on('GET /forms', {'success': true, 'data': [formJson(), formJson(id: 13)]});
      final c = Get.put(FormsListController());
      await until(() => !c.isLoading.value, reason: 'forms load');

      api.on('DELETE /forms/13', {'success': false, 'message': 'Server error'}, status: 500);
      expect(await c.delete(c.forms[1]), isFalse);
      expect(c.forms, hasLength(2));

      api.on('DELETE /forms/12', {'success': true, 'status': 'ok'});
      expect(await c.delete(c.forms.first), isTrue);
      expect(c.forms.map((f) => f.id), [13]);
    });
  });

  group('editor', () {
    final opens = DateTime.utc(2026, 11, 11, 12, 30);

    Future<FormEditorController> newEditor() async {
      final c = Get.put(FormEditorController(clock: () => opens));
      await until(() => c.questions.isNotEmpty, reason: 'editor ready');
      return c;
    }

    test('new poll starts with one poll question and checks the API rules', () async {
      final c = await newEditor();
      expect(c.kind.value, FormKind.poll);
      expect(c.questions.single.type, FormFieldType.poll);

      expect(c.validationError, 'Add a title.');
      c.titleController.text = 'Dinner Poll';
      expect(c.validationError, 'Question 1 needs a text.');
      c.updateQuestion(0, c.questions[0].copyWith(label: 'Choose item', options: ['Khichdi', '']));
      expect(c.validationError, 'Question 1 needs at least 2 options.');
      c.updateQuestion(0, c.questions[0].copyWith(options: ['Khichdi', 'khichdi']));
      expect(c.validationError, 'Question 1 has the same option twice.');
      c.updateQuestion(0, c.questions[0].copyWith(options: ['Khichdi', 'Pulao']));
      expect(c.validationError, isNull);

      c.updateQuestion(0, c.questions[0].copyWith(type: FormFieldType.checkbox, options: ['Khichdi']));
      expect(c.validationError, isNull, reason: 'checkbox needs only 1 option');

      c.endTime.value = c.startTime.value;
      expect(c.validationError, 'The end time must be after the start time.');
      c.endTime.value = c.startTime.value.add(const Duration(hours: 3));

      c.audience.value = FormAudience.selected;
      expect(c.validationError, 'Pick students, floors or tags for a selected audience.');
      c.toggleFloor(0);
      expect(c.validationError, isNull, reason: 'Ground floor (0) counts');
    });

    test('create sends the full body: ISO UTC times, numeric ids, floor 0', () async {
      api.on('POST /forms', {'success': true, 'status': 'ok', 'message': 'Form created successfully', 'form_id': 12});
      final c = await newEditor();
      c.titleController.text = ' Dinner Poll ';
      c.descriptionController.text = 'Vote before 7 PM';
      c.updateQuestion(0, c.questions[0].copyWith(label: 'Choose item', options: [' Khichdi ', 'Pulao', '']));
      c.addQuestion(FormFieldType.text);
      c.updateQuestion(1, c.questions[1].copyWith(label: 'Any comments?', required: false));
      c.audience.value = FormAudience.selected;
      c.toggleFloor(0);
      c.toggleFloor(3);
      c.addStudent(const PickableStudent(id: 102, name: 'Parth', room: '204'));
      c.endTime.value = opens.add(const Duration(hours: 27));

      expect(await c.save(), isTrue);

      final body = api.last('POST /forms').data as Map;
      expect(body['title'], 'Dinner Poll');
      expect(body['description'], 'Vote before 7 PM');
      expect(body['form_type'], 'poll');
      expect(body['fields'], [
        {'id': 'q1', 'label': 'Choose item', 'type': 'poll', 'required': true, 'options': ['Khichdi', 'Pulao']},
        {'id': 'q2', 'label': 'Any comments?', 'type': 'text', 'required': false},
      ]);
      expect(body['target_audience'], 'selected');
      expect(body['target_floors'], [0, 3]);
      expect(body['target_student_ids'], [102]);
      expect(body['target_tags'], isNull);
      expect(body['start_time'], '2026-11-11T12:30:00.000Z');
      expect(body['end_time'], '2026-11-12T15:30:00.000Z');
      expect(body['is_active'], isTrue);
      expect(body['is_mandatory'], isFalse);
    });

    test('targets are null unless the audience is selected', () async {
      api.on('POST /forms', {'success': true, 'form_id': 12});
      final c = await newEditor();
      c.titleController.text = 'Dinner Poll';
      c.updateQuestion(0, c.questions[0].copyWith(label: 'Choose item', options: ['Khichdi', 'Pulao']));
      c.toggleFloor(3); // picked, then audience switched back
      c.audience.value = FormAudience.current;

      await c.save();

      final body = api.last('POST /forms').data as Map;
      expect(body['target_audience'], 'current');
      expect(body['target_floors'], isNull);
      expect(body['target_student_ids'], isNull);
    });

    test('edit sends only the changed fields; no change sends nothing', () async {
      api.on('GET /forms/12', {'success': true, 'status': 'ok', 'data': formJson()});
      api.on('PUT /forms/12', {'success': true, 'status': 'ok', 'message': 'Form updated successfully'});
      final form = HostelForm.fromJson(formJson());
      final c = Get.put(FormEditorController(editing: form));
      await until(() => api.called('GET /forms/12').isNotEmpty && !c.isLoadingForm.value, reason: 'edit load');
      expect(c.isEditing, isTrue);
      expect(c.questions.single.id, 'q1', reason: 'existing keys are kept');

      expect(await c.save(), isTrue);
      expect(api.called('PUT /forms/12'), isEmpty, reason: 'nothing changed');

      c.titleController.text = 'Dinner Poll (Friday)';
      c.isMandatory.value = true;
      expect(await c.save(), isTrue);
      expect(api.last('PUT /forms/12').data, {'title': 'Dinner Poll (Friday)', 'is_mandatory': true});
    });

    test('a 400 keeps everything on screen', () async {
      api.on('POST /forms', {'success': false, 'message': 'end_time must be after start_time'}, status: 400);
      final c = await newEditor();
      c.titleController.text = 'Dinner Poll';
      c.updateQuestion(0, c.questions[0].copyWith(label: 'Choose item', options: ['Khichdi', 'Pulao']));

      expect(await c.save(), isFalse);
      expect(c.titleController.text, 'Dinner Poll');
      expect(c.questions.single.options, ['Khichdi', 'Pulao']);
      expect(c.isSaving.value, isFalse);
    });

    test('an invalid form is never sent', () async {
      final c = await newEditor();
      expect(await c.save(), isFalse);
      expect(api.called('POST /forms'), isEmpty);
    });
  });
}
