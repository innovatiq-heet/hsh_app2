import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/broadcasts/broadcast_models.dart';
import 'package:hsh_app2/core/network/repository/broadcasts/broadcasts_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/broadcast/controllers/broadcast_detail_controller.dart';
import 'package:hsh_app2/features/broadcast/controllers/broadcast_history_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Admin → Broadcast history and detail, against `/broadcasts`, offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;

  Map<String, dynamic> broadcastJson(int id, {String status = 'sent'}) => {
        'id': id,
        'title': 'Notice $id',
        'message': 'Message $id',
        'tags': [
          {'id': 3, 'name': 'Floor 2', 'color': '#0284C7'},
        ],
        'student_ids': ['102', 215],
        'status': status,
        'recipient_count': '48',
        'push_sent': 43,
        'push_failed': 0,
        'no_device': 5,
        'read_count': 12,
        'sender': {'id': 1, 'name': 'Super Admin'},
        'created_at': '2026-11-11T09:30:00.000Z',
        'completed_at': status == 'sent' ? '2026-11-11T09:30:04.000Z' : null,
      };

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'token', 'name': 'Super Admin'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    Get.put(BroadcastsRepository());
  });

  tearDown(Get.reset);

  test('parses broadcasts, tolerating numbers sent as strings and unknown status', () async {
    api.on('GET /broadcasts', {
      'success': true,
      'data': [
        broadcastJson(91),
        {...broadcastJson(90), 'status': 'queued'},
      ],
      'total': 2,
    });
    final c = Get.put(BroadcastHistoryController());
    await until(() => !c.isLoading.value, reason: 'history load');

    final b = c.broadcasts.first;
    expect(b.id, 91);
    expect(b.status, BroadcastStatus.sent);
    expect(b.recipientCount, 48);
    expect(b.studentIds, [102, 215]);
    expect(b.tags.single.name, 'Floor 2');
    expect(b.senderName, 'Super Admin');
    expect(b.createdAt, DateTime.utc(2026, 11, 11, 9, 30));
    expect(c.broadcasts[1].status, BroadcastStatus.unknown);
    expect(c.hasMore, isFalse);
  });

  test('pages with offset until total is reached', () async {
    api.routes['GET /broadcasts'] = (o) {
      final offset = o.queryParameters['offset'] as int;
      final ids = offset == 0 ? List.generate(20, (i) => 100 - i) : [80, 79];
      return FakeReply(200, {
        'success': true,
        'data': [for (final id in ids) broadcastJson(id)],
        'total': 22,
      });
    };
    final c = Get.put(BroadcastHistoryController());
    await until(() => !c.isLoading.value, reason: 'history load');
    expect(c.broadcasts, hasLength(20));
    expect(c.hasMore, isTrue);

    await c.loadMore();

    expect(api.last('GET /broadcasts').queryParameters, {'limit': 20, 'offset': 20});
    expect(c.broadcasts, hasLength(22));
    expect(c.hasMore, isFalse);
  });

  test('refreshes only while a broadcast is still sending', () async {
    var status = 'sending';
    api.routes['GET /broadcasts'] = (_) => FakeReply(200, {
          'success': true,
          'data': [broadcastJson(91, status: status)],
          'total': 1,
        });
    final c = Get.put(BroadcastHistoryController(pollInterval: const Duration(milliseconds: 40)));
    await until(() => !c.isLoading.value, reason: 'history load');

    await until(() => api.called('GET /broadcasts').length >= 3, reason: 'polling while sending');
    status = 'sent';
    await until(() => c.broadcasts.first.status == BroadcastStatus.sent, reason: 'sent');

    final calls = api.called('GET /broadcasts').length;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(api.called('GET /broadcasts').length, calls, reason: 'no polling once all are sent');
  });

  test('no polling when nothing is sending', () async {
    api.on('GET /broadcasts', {'success': true, 'data': [broadcastJson(91)], 'total': 1});
    final c = Get.put(BroadcastHistoryController(pollInterval: const Duration(milliseconds: 30)));
    await until(() => !c.isLoading.value, reason: 'history load');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(api.called('GET /broadcasts'), hasLength(1));
  });

  test('a non-admin is sent away and loads nothing', () async {
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': 'warden', 'token': 'token', 'name': 'Warden'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    Get.put(BroadcastsRepository());

    final c = Get.put(BroadcastHistoryController());
    await until(() => c.accessDenied.value, reason: 'access check');
    expect(api.requests, isEmpty);
  });

  test('detail lists recipients and filters them', () async {
    api.on('GET /broadcasts/91', {
      'success': true,
      'data': {
        ...broadcastJson(91),
        'recipients': [
          {'student_id': 102, 'name': 'Parth', 'room': '204', 'matched_by': 'both', 'push_status': 'sent', 'read_at': '2026-11-11T09:41:00.000Z'},
          {'student_id': 215, 'name': 'Ravi', 'room': '105', 'matched_by': 'tag', 'push_status': 'no_device', 'read_at': null},
          {'student_id': 216, 'name': 'Amit', 'room': '106', 'matched_by': 'individual', 'push_status': 'sent', 'read_at': null},
        ],
      },
    });
    final c = Get.put(BroadcastDetailController(broadcastId: 91));
    await until(() => !c.isLoading.value, reason: 'detail load');

    expect(c.visibleRecipients, hasLength(3));
    c.filter.value = RecipientFilter.read;
    expect(c.visibleRecipients.map((r) => r.studentId), [102]);
    c.filter.value = RecipientFilter.unread;
    expect(c.visibleRecipients.map((r) => r.studentId), [215, 216]);
    c.filter.value = RecipientFilter.noDevice;
    expect(c.visibleRecipients.map((r) => r.studentId), [215]);
    expect(c.broadcast.value!.recipients.first.pushStatus, PushStatus.sent);
  });
}
