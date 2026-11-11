import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/constants/app_routes.dart';
import 'package:hsh_app2/core/network/repository/broadcasts/broadcasts_repository.dart';
import 'package:hsh_app2/core/services/push_notification_service.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/broadcast/controllers/broadcast_inbox_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Student → Announcements against `/me/broadcasts`, and the push tap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;

  Map<String, dynamic> item(int id, {String? readAt}) => {
        'id': id,
        'title': 'Notice $id',
        'message': 'Message $id',
        'sender_name': 'Super Admin',
        'created_at': '2026-11-11T09:30:00.000Z',
        'read_at': readAt,
      };

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': 'student', 'token': 'token', 'name': 'Parth'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    Get.put(BroadcastsRepository());
    api.on('GET /me/broadcasts', {
      'success': true,
      'data': [item(91), item(90, readAt: '2026-11-10T08:00:00.000Z')],
      'total': 2,
      'unread_count': 1,
    });
  });

  tearDown(Get.reset);

  Future<BroadcastInboxController> open({int? openId}) async {
    final c = Get.put(BroadcastInboxController(openBroadcastId: openId));
    await until(() => !c.isLoading.value, reason: 'inbox load');
    return c;
  }

  test('lists messages with the unread count', () async {
    final c = await open();
    expect(c.items.map((i) => i.id), [91, 90]);
    expect(c.items.first.isRead, isFalse);
    expect(c.items.last.isRead, isTrue);
    expect(c.unreadCount.value, 1);
  });

  test('opening marks read at once, and keeps it when the server agrees', () async {
    api.on('POST /me/broadcasts/91/read', {
      'success': true,
      'data': {'id': 91, 'read_at': '2026-11-11T09:41:00.000Z'},
    });
    final c = await open();

    final done = c.markRead(c.items.first);
    expect(c.items.first.isRead, isTrue, reason: 'optimistic');
    expect(c.unreadCount.value, 0);
    await done;

    expect(api.called('POST /me/broadcasts/91/read'), hasLength(1));
    expect(c.items.first.readAt, DateTime.utc(2026, 11, 11, 9, 41));
    expect(c.unreadCount.value, 0);
  });

  test('a failed mark-read is rolled back', () async {
    api.on('POST /me/broadcasts/91/read', {'success': false, 'message': 'Server error'}, status: 500);
    final c = await open();

    await c.markRead(c.items.first);

    expect(c.items.first.isRead, isFalse);
    expect(c.unreadCount.value, 1);
  });

  test('an already-read message makes no request', () async {
    final c = await open();
    await c.markRead(c.items.last);
    expect(api.called('POST /me/broadcasts/90/read'), isEmpty);
  });

  test('a broadcast push opens that message in the inbox', () async {
    final target = PushNotificationService.broadcastTarget(
      {'type': 'broadcast', 'broadcast_id': '91', 'title': 'Notice', 'body': 'Message'},
      isOperator: false,
    );
    expect(target.route, Routes.broadcastInbox);
    expect(target.arguments, {'broadcast_id': 91});

    final id = (target.arguments as Map)['broadcast_id'] as int;
    final c = await open(openId: id);
    expect(c.openRequest.value?.id, 91);
  });

  test('an admin tapping a broadcast push opens its detail', () {
    final target = PushNotificationService.broadcastTarget(
      {'type': 'broadcast', 'broadcast_id': '91'},
      isOperator: true,
    );
    expect(target.route, Routes.operatorBroadcastDetail);
    expect(target.arguments, 91);
  });

  test('a tap during splash waits; it is opened once splash has routed', () {
    expect(PushNotificationService.mustWaitForStartup(''), isTrue);
    expect(PushNotificationService.mustWaitForStartup(Routes.splash), isTrue);
    expect(PushNotificationService.mustWaitForStartup(Routes.studentHome), isFalse);
  });
}
