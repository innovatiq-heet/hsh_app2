import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/broadcasts/broadcast_models.dart';
import 'package:hsh_app2/core/network/repository/broadcasts/broadcasts_repository.dart';
import 'package:hsh_app2/core/network/repository/tags/tags_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/broadcast/controllers/broadcast_compose_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Admin → Broadcast → New, against the `/broadcasts` contract, offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;
  late BroadcastComposeController c;

  const debounce = Duration(milliseconds: 30);
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 120));

  Map<String, dynamic> broadcastJson({int id = 91, int recipients = 2}) => {
        'id': id,
        'title': 'Water supply',
        'message': 'No water 2-4 pm today.',
        'tags': [
          {'id': 3, 'name': 'Floor 2', 'color': '#0284C7'},
        ],
        'student_ids': [102],
        'status': 'sending',
        'recipient_count': recipients,
        'push_sent': 0,
        'push_failed': 0,
        'no_device': 0,
        'read_count': 0,
        'sender': {'id': 1, 'name': 'Super Admin'},
        'created_at': '2026-11-11T09:30:00.000Z',
        'completed_at': null,
      };

  void previewReturns(int count, {int noDevice = 0}) => api.on('POST /broadcasts/preview', {
        'success': true,
        'data': {
          'recipient_count': count,
          'no_device_count': noDevice,
          'sample': [
            {'id': 102, 'name': 'Parth Patel', 'room': '204'},
          ],
        },
      });

  Future<BroadcastComposeController> open({String role = 'admin'}) async {
    Get.testMode = true; // also after a Get.reset() inside a test
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': role, 'token': 'token', 'name': 'User'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    Get.put(TagsRepository());
    Get.put(BroadcastsRepository());
    api.on('GET /tags', {
      'success': true,
      'data': [
        {'id': 3, 'name': 'Floor 2', 'color': '#0284C7', 'student_count': 40},
        {'id': 7, 'name': 'Mess team', 'color': '#EA580C', 'student_count': 9},
      ],
    });
    final controller = Get.put(BroadcastComposeController(previewDebounce: debounce));
    await until(
      () => controller.accessDenied.value || (controller.tags.isNotEmpty && !controller.isTagsLoading.value),
      reason: 'compose screen ready',
    );
    return controller;
  }

  /// A ready-to-send form: title, message, one tag, preview of [count].
  Future<void> fillValid({int count = 2}) async {
    previewReturns(count);
    c.titleController.text = '  Water supply ';
    c.messageController.text = ' No water 2-4 pm today. ';
    c.toggleTag(3);
    await settle();
  }

  setUp(() async {
    Get.testMode = true;
    c = await open();
  });

  tearDown(Get.reset);

  test('admin sees tags; a non-admin is sent away and loads nothing', () async {
    expect(c.accessDenied.value, isFalse);
    expect(c.tags.map((t) => t.id), [3, 7]);

    Get.reset();
    final student = await open(role: 'student');
    expect(student.accessDenied.value, isTrue);
    expect(api.called('GET /tags'), isEmpty);
  });

  test('a fast series of audience edits makes one debounced preview request', () async {
    previewReturns(41);
    c.toggleTag(3);
    c.addStudent(const BroadcastStudent(id: 102, name: 'Parth Patel', room: '204'));
    c.toggleTag(7);
    expect(c.isPreviewLoading.value, isTrue);
    await settle();

    expect(api.called('POST /broadcasts/preview'), hasLength(1));
    expect(api.last('POST /broadcasts/preview').data, {
      'tag_ids': [3, 7],
      'student_ids': [102],
    });
    expect(c.preview.value.recipientCount, 41);
    expect(c.isPreviewLoading.value, isFalse);
  });

  test('clearing the audience resets the count without a request', () async {
    previewReturns(41);
    c.toggleTag(3);
    await settle();
    c.toggleTag(3);
    await settle();

    expect(api.called('POST /broadcasts/preview'), hasLength(1));
    expect(c.preview.value.recipientCount, 0);
    expect(c.canSend, isFalse);
  });

  test('individual picks use only numeric students.id, never codes', () async {
    api.on('GET /students', {
      'success': true,
      'data': [
        {'id': 102, 'student_id': 'HSH-0768', 'student_code': '0768', 'name': 'Parth Patel', 'room_number': '204'},
        {'id': '215', 'name': 'Ravi Shah', 'room': '105'},
        {'id': '0768', 'name': 'Leading zero', 'room': '301'}, // a bank code, not an id
        {'student_id': 999, 'name': 'No id field', 'room': '302'},
        {'id': 'HSH-12', 'name': 'Code as id', 'room': '303'},
        {'id': 300, 'name': 'Left student', 'room': 'N/A'}, // alumni are not offered
      ],
    });

    await c.loadStudents();
    expect(c.students.map((s) => s.id), unorderedEquals([102, 215]));

    previewReturns(2);
    c.titleController.text = 'Hi';
    c.messageController.text = 'Hello';
    for (final s in c.students) {
      c.addStudent(s);
    }
    await settle();
    api.on('POST /broadcasts', {'success': true, 'data': broadcastJson()}, status: 201);
    await c.send();

    final sent = api.last('POST /broadcasts').data as Map;
    final ids = sent['student_ids'] as List;
    expect(ids, everyElement(isA<int>()));
    expect(ids.toSet(), {102, 215});
    expect(jsonEncode(sent), isNot(contains('0768')));
    expect(jsonEncode(api.last('POST /broadcasts/preview').data), isNot(contains('HSH')));
  });

  test('send carries trimmed text, the audience and a UUID request id', () async {
    await fillValid();
    api.on('POST /broadcasts', {'success': true, 'data': broadcastJson()}, status: 201);

    final result = await c.send();

    expect(result?.id, 91);
    final body = api.last('POST /broadcasts').data as Map;
    expect(body['title'], 'Water supply');
    expect(body['message'], 'No water 2-4 pm today.');
    expect(body['tag_ids'], [3]);
    expect(body['student_ids'], <int>[]);
    expect(
      body['client_request_id'],
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });

  test('a double tap sends once', () async {
    await fillValid();
    api.on('POST /broadcasts', {'success': true, 'data': broadcastJson()}, status: 201);

    final first = c.send();
    final second = c.send();
    final results = await Future.wait([first, second]);

    expect(api.called('POST /broadcasts'), hasLength(1));
    expect(results.whereType<Broadcast>(), hasLength(1));
  });

  test('a retry after a 500 reuses the same client_request_id', () async {
    await fillValid();
    api.on('POST /broadcasts', {'success': false, 'message': 'Server error'}, status: 500);
    expect(await c.send(), isNull);

    api.on('POST /broadcasts', {'success': true, 'data': broadcastJson()}, status: 200);
    expect(await c.send(), isNotNull, reason: '200 (known request id) is a success too');

    final ids = api
        .called('POST /broadcasts')
        .map((r) => (r.data as Map)['client_request_id'])
        .toSet();
    expect(ids, hasLength(1));
  });

  test('400 and 422 keep the form so the admin can fix and retry', () async {
    await fillValid();
    for (final status in [400, 422]) {
      api.on(
        'POST /broadcasts',
        {'success': false, 'message': 'No active students match this audience.'},
        status: status,
      );
      expect(await c.send(), isNull);
      expect(c.titleController.text, '  Water supply ');
      expect(c.messageController.text, ' No water 2-4 pm today. ');
      expect(c.selectedTagIds, {3});
      expect(c.isSending.value, isFalse);
    }
  });

  test('send is disabled for invalid text, zero reach or a preview error', () async {
    await fillValid();
    expect(c.canSend, isTrue);

    c.titleController.text = '   ';
    expect(c.canSend, isFalse, reason: 'blank title');
    c.titleController.text = 'x' * 101;
    expect(c.canSend, isFalse, reason: 'title over 100');
    c.titleController.text = 'Water supply';
    c.messageController.text = 'y' * 2001;
    expect(c.canSend, isFalse, reason: 'message over 2000');
    c.messageController.text = 'No water today.';
    expect(c.canSend, isTrue);

    previewReturns(0);
    c.toggleTag(7);
    await settle();
    expect(c.canSend, isFalse, reason: 'reaches nobody');

    api.on('POST /broadcasts/preview', {'success': false, 'message': 'Server error'}, status: 500);
    c.toggleTag(7);
    await settle();
    expect(c.previewError.value, isNotNull);
    expect(c.canSend, isFalse, reason: 'preview failed');

    previewReturns(40);
    await c.refreshPreview();
    expect(c.previewError.value, isNull);
    expect(c.canSend, isTrue, reason: 'retry fixed it');

    expect(await Future.value(api.called('POST /broadcasts')), isEmpty);
  });
}
