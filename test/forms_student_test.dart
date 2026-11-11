import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/forms/form_models.dart';
import 'package:hsh_app2/core/network/repository/forms/forms_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/forms/controllers/student_forms_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Student → Polls & Forms against `/forms/student/*`, offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;
  late StudentFormsController c;

  final survey = {
    'id': 20,
    'title': 'Mess survey',
    'description': null,
    'form_type': 'form',
    'fields': [
      {'id': 'choice', 'label': 'Best day?', 'type': 'radio', 'required': true, 'options': ['Mon', 'Tue']},
      {'key': 'items', 'label': 'Favourites', 'type': 'checkbox', 'required': false, 'options': ['Dal', 'Rice', 'Roti']},
      {'label': 'Happy?', 'type': 'boolean', 'required': true},
      {'id': 'stars', 'label': 'Rate the mess', 'type': 'rating', 'required': true},
      {'id': 'count', 'label': 'Meals a day', 'type': 'number', 'required': false},
      {'id': 'note', 'label': 'Comments', 'type': 'textarea', 'required': false},
    ],
    'start_time': '2026-11-11 18:00:00',
    'end_time': '2099-11-12 21:00:00',
    'is_mandatory': true,
    'has_viewed': false,
    'has_submitted': false,
    'my_response': null,
  };

  final voted = {
    'id': 12,
    'title': 'Dinner Poll',
    'form_type': 'poll',
    'fields': [
      {'id': 'q1', 'label': 'Choose item', 'type': 'poll', 'required': true, 'options': ['Khichdi', 'Pulao']},
    ],
    'start_time': '2026-11-11 18:00:00',
    'end_time': '2099-11-12 21:00:00',
    'is_mandatory': false,
    'has_viewed': true,
    'has_submitted': true,
    'my_response': {
      'submitted_at': '2026-11-11 19:00:00',
      'answers': {'q1': 'Khichdi'},
    },
  };

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': 'student', 'token': 'token', 'name': 'Parth'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    Get.put(FormsRepository());
    api.on('GET /forms/student/active', {'success': true, 'status': 'ok', 'data': [survey, voted]});
    c = Get.put(StudentFormsController());
    await until(() => !c.isLoading.value, reason: 'active load');
  });

  tearDown(Get.reset);

  StudentForm surveyForm() => c.byId(20)!;

  /// A complete valid set of raw answers, as the fill screen holds them.
  Map<String, dynamic> validRaw() => {
        'choice': 'Tue',
        'items': {'Roti', 'Dal'},
        'Happy?': true,
        'stars': 4,
        'count': ' 3 ',
        'note': '  More roti please  ',
      };

  test('keeps the server order and reads earlier answers', () {
    expect(c.forms.map((f) => f.id), [20, 12], reason: 'mandatory first, as sent');
    expect(c.pendingCount, 1);
    expect(c.pendingMandatoryCount, 1);
    final r = c.byId(12)!.myResponse!;
    expect(r.answers, {'q1': 'Khichdi'});
    expect(r.submittedAt, DateTime.utc(2026, 11, 11, 13, 30));
  });

  test('opening records one view', () async {
    api.on('POST /forms/20/view', {'success': true, 'status': 'ok', 'message': 'View recorded'});
    await c.markViewed(surveyForm());
    await c.markViewed(surveyForm());
    expect(api.called('POST /forms/20/view'), hasLength(1));
    expect(surveyForm().hasViewed, isTrue);
  });

  test('a failed view record never blocks answering', () async {
    api.on('POST /forms/20/view', {'success': false, 'message': 'Not eligible'}, status: 403);
    await c.markViewed(surveyForm());
    expect(surveyForm().hasViewed, isTrue);
  });

  test('submit encodes each type and keys answers by id ?? key ?? label', () async {
    api.on('POST /forms/20/submit', {'success': true, 'status': 'ok', 'message': 'Response submitted successfully!'});

    expect(await c.submit(surveyForm(), validRaw()), isNull);

    expect(api.last('POST /forms/20/submit').data, {
      'answers': {
        'choice': 'Tue',
        'items': ['Dal', 'Roti'], // in option order
        'Happy?': true,
        'stars': 4,
        'count': 3,
        'note': 'More roti please',
      },
    });
    final f = surveyForm();
    expect(f.hasSubmitted, isTrue);
    expect(f.myResponse!.answers['stars'], 4);
    expect(c.pendingCount, 0);
  });

  test('unanswered optional questions are left out', () async {
    api.on('POST /forms/20/submit', {'success': true});
    final raw = validRaw()
      ..remove('note')
      ..['items'] = <String>{}
      ..['count'] = '';

    expect(await c.submit(surveyForm(), raw), isNull);
    final answers = (api.last('POST /forms/20/submit').data as Map)['answers'] as Map;
    expect(answers.keys, unorderedEquals(['choice', 'Happy?', 'stars']));
  });

  test('a missing or invalid answer is caught before sending', () async {
    expect(await c.submit(surveyForm(), validRaw()..remove('Happy?')), 'Please answer "Happy?".');
    expect(await c.submit(surveyForm(), validRaw()..['stars'] = 6), 'Rate "Rate the mess" from 1 to 5.');
    expect(await c.submit(surveyForm(), validRaw()..['choice'] = 'Sun'), 'Pick an option for "Best day?".');
    expect(await c.submit(surveyForm(), validRaw()..['count'] = 'three'), '"Meals a day" needs a number.');
    expect(api.called('POST /forms/20/submit'), isEmpty);
  });

  test('a 400 (already submitted, closed) returns the server message and keeps state', () async {
    api.on('POST /forms/20/submit', {'success': false, 'message': 'You have already submitted this form.'}, status: 400);
    expect(await c.submit(surveyForm(), validRaw()), 'You have already submitted this form.');
    expect(surveyForm().hasSubmitted, isFalse);
    expect(c.submitting, isEmpty);
  });

  test('a double tap submits once', () async {
    api.on('POST /forms/20/submit', {'success': true});
    await Future.wait([c.submit(surveyForm(), validRaw()), c.submit(surveyForm(), validRaw())]);
    expect(api.called('POST /forms/20/submit'), hasLength(1));
  });

  test('my-response: fetched when missing, null on 404', () async {
    final repo = Get.find<FormsRepository>();
    api.on('GET /forms/student/12/my-response', {
      'success': true,
      'data': {'submitted_at': '2026-11-11 19:00:00', 'answers': {'q1': 'Pulao'}},
    });
    expect((await repo.myResponse(12))!.answers, {'q1': 'Pulao'});
    expect(await repo.myResponse(99), isNull, reason: 'not submitted yet → 404');
  });
}
