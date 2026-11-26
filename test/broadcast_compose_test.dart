import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/broadcasts/broadcast_models.dart';
import 'package:hsh_app2/core/network/repository/broadcasts/broadcasts_repository.dart';
import 'package:hsh_app2/core/network/repository/tags/tags_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/broadcast/controllers/broadcast_compose_controller.dart';
import 'package:hsh_app2/features/broadcast/utils/tag_members.dart';
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
    // With a tag, who in it gets the broadcast has to be chosen.
    c.setTagScope(TagMemberScope.all);
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
        {'id': 300, 'name': 'Alumni student', 'room': 'N/A'}, // alumni are offered
      ],
    });

    await c.loadStudents();
    expect(c.students.map((s) => s.id), unorderedEquals([102, 215, 300]));

    previewReturns(3);
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
    expect(ids.toSet(), {102, 215, 300});
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
    expect(body['channels'], 'both');
    expect(body['tag_ids'], [3]);
    expect(body['student_ids'], <int>[]);
    expect(
      body['client_request_id'],
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });

  test('send without title succeeds and omits title from request', () async {
    await fillValid();
    c.titleController.text = '   ';
    c.setChannel(BroadcastChannel.whatsapp);
    api.on('POST /broadcasts', {'success': true, 'data': broadcastJson()}, status: 201);

    final result = await c.send();

    expect(result?.id, 91);
    final body = api.last('POST /broadcasts').data as Map;
    expect(body.containsKey('title'), isFalse);
    expect(body['message'], 'No water 2-4 pm today.');
    expect(body['channels'], 'whatsapp');
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
    expect(c.canSend, isTrue, reason: 'blank title is optional and allowed');
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

  group('who in the tags gets it', () {
    Map<String, dynamic> row(int id, {bool active = true, String room = '204', String status = 'renewed-admission', List<int> tags = const [3]}) => {
          'id': id,
          'name': 'Student $id',
          'is_active': active ? 1 : 0,
          'room_number': room,
          'student_status': status,
          'tags': [for (final t in tags) {'id': t, 'name': 'T$t'}],
        };

    void studentsReturn(List<Map<String, dynamic>> rows) =>
        api.on('GET /students', {'success': true, 'data': rows});

    test('members split like the server: current, alumni, cancelled never', () {
      final m = TagMembers.of([
        row(1),
        row(2, active: false, room: 'N/A', status: 'left'),
        row(3, active: false, room: '', status: 'left'),
        row(4, status: 'cancel-admission'),
        row(5, active: false, room: 'alumni', status: 'rejected-admission'),
        row(6, tags: [7]), // another tag
        row(7, active: true, status: 'left', room: '305'), // left but still has a room: neither
        {'id': '0812', 'is_active': 1, 'room_number': '2', 'tags': [{'id': 3}]}, // a bank code, not an id
      ], {3});
      expect(m.current, [1]);
      expect(m.alumni, [2, 3]);
      expect(m.idsFor(TagMemberScope.all), [1, 2, 3]);
    });

    test('a tag needs a choice before sending', () async {
      previewReturns(3);
      studentsReturn([row(1), row(2, active: false, room: 'N/A', status: 'left')]);
      c.titleController.text = 'Meeting';
      c.messageController.text = 'Hall at 7 pm.';
      c.toggleTag(3);
      await settle();
      expect(c.canSend, isFalse, reason: 'who in the tag is not chosen yet');
      c.setTagScope(TagMemberScope.all);
      await settle();
      expect(c.canSend, isTrue);
    });

    test('alumni only sends those students by id, not the tag; individual picks stay', () async {
      previewReturns(2);
      studentsReturn([
        row(1),
        row(2, active: false, room: 'N/A', status: 'left'),
        row(3, active: false, room: '', status: 'left'),
      ]);
      api.on('POST /broadcasts', {'success': true, 'data': broadcastJson()});
      c.titleController.text = 'Alumni meet';
      c.messageController.text = 'Sunday 10 am.';
      c.toggleTag(3);
      c.setTagScope(TagMemberScope.alumni);
      await settle();

      expect(c.tagMembers.value.current, [1]);
      expect(c.tagMembers.value.alumni, [2, 3]);
      final preview = api.last('POST /broadcasts/preview').data as Map;
      expect(preview['tag_ids'], isEmpty);
      expect(preview['student_ids'], [2, 3]);

      await c.send();
      final sent = api.last('POST /broadcasts').data as Map;
      expect(sent['tag_ids'], isEmpty);
      expect(sent['student_ids'], [2, 3]);
    });

    test('current & alumni keeps sending the tag itself', () async {
      previewReturns(3);
      studentsReturn([row(1)]);
      c.titleController.text = 'All';
      c.messageController.text = 'Everyone.';
      c.toggleTag(3);
      c.setTagScope(TagMemberScope.all);
      await settle();
      final preview = api.last('POST /broadcasts/preview').data as Map;
      expect(preview['tag_ids'], [3]);
      expect(preview['student_ids'], isEmpty);
    });
  });

  group('leader group broadcasts', () {
    test('leader is admitted, loads group audience, and posts to /leader/broadcasts', () async {
      Get.reset();
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({
        'auth_token': 'leader-token',
        'user_session': jsonEncode({'role': 'leader', 'token': 'leader-token', 'name': 'Param Leader'}),
      });
      Get.put(SessionStore());
      api = FakeApi()..install();
      Get.put(TagsRepository());
      Get.put(BroadcastsRepository());
      api.on('GET /tags', {
        'success': true,
        'data': [{'id': 3, 'name': 'Floor 2', 'color': '#0284C7', 'student_count': 40}],
      });
      api.on('GET /leader/broadcasts/audience', {
        'success': true,
        'data': {
          'groupName': 'Param',
          'residentsCount': 25,
          'alumniCount': 40,
          'totalCount': 65,
          'whatsappConnected': true,
          'hasLinkedAccount': true,
          'linkedPhone': '919876543210',
        },
      });
      api.on('GET /leader/broadcasts/students', {
        'success': true,
        'data': [{'id': 501, 'name': 'Param Student', 'room': '201', 'is_alumni': false}],
      });
      api.on('POST /leader/broadcasts/preview', {
        'success': true,
        'data': {
          'recipient_count': 65,
          'no_device_count': 2,
          'no_whatsapp_count': 0,
          'whatsapp_connected': true,
          'sample': [{'id': 501, 'name': 'Param Student', 'room': '201'}],
        },
      });
      api.on('POST /leader/broadcasts', {'success': true, 'data': broadcastJson(recipients: 65)}, status: 201);

      final lc = Get.put(BroadcastComposeController(previewDebounce: debounce));
      await until(() => lc.leaderGroupName.value == 'Param' && lc.students.isNotEmpty, reason: 'leader ready');

      expect(lc.accessDenied.value, isFalse);
      expect(lc.isLeaderView.value, isTrue);
      expect(lc.leaderWhatsappConnected.value, isTrue);

      lc.messageController.text = 'Param house meeting at 7pm';
      lc.setGroupAudiencePreset('all');
      await settle();

      expect(api.last('POST /leader/broadcasts/preview').data['audience_preset'], 'all');
      expect(lc.canSend, isTrue);

      final sent = await lc.send();
      expect(sent, isNotNull);
      expect(api.last('POST /leader/broadcasts').data['audience_preset'], 'all');
    });
  });
}
