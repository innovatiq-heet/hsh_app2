import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/phonebook/services/phonebook_favourites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Phonebook Favourites: counted calls, synced with `/phonebook/*`, with a
/// local queue while the server can't be reached.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;
  final service = PhonebookFavouritesService.instance;

  Map<String, dynamic> favJson(String key, int calls) => {
        'student_key': key,
        'student_name': 'Student $key',
        'total_calls': calls,
        'last_called_at': '2026-11-11T09:30:00.000Z',
        'numbers': [
          {'phone': '98765 43210', 'phone_normalized': '9876543210', 'calls': calls - 1},
          {'phone': '+91 79849 07753', 'phone_normalized': '7984907753', 'calls': 1},
        ],
      };

  Future<void> call(String key, String phone) =>
      service.recordCall(studentKey: key, name: 'Student $key', phone: phone);

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'admin-token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'admin-token', 'name': 'Super Admin'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    service.resetForTest();
  });

  tearDown(Get.reset);

  test('server favourites are used as-is, most-dialled number first', () async {
    api.on('GET /phonebook/favourites', {
      'success': true,
      'data': [favJson('HSH-1', 5), favJson('HSH-2', 3)],
    });

    final favs = await service.topFavourites();

    expect(favs.map((f) => f.studentKey), ['HSH-1', 'HSH-2']);
    expect(favs.first.totalCalls, 5);
    expect(favs.first.mostDialledNumber, '98765 43210');
    final query = api.last('GET /phonebook/favourites').queryParameters;
    expect(query['limit'], PhonebookFavouritesService.maxFavourites);
    expect(query['min_calls'], PhonebookFavouritesService.minCallsForFavourite);
  });

  test('without the server, local counts drive favourites (2+ calls)', () async {
    // No routes: every request is a 404, as before the backend ships.
    await call('HSH-1', '98765 43210');
    await call('HSH-1', '+91 98765 43210');
    await call('HSH-2', '7984907753');

    final favs = await service.topFavourites();

    expect(favs.map((f) => f.studentKey), ['HSH-1'], reason: 'HSH-2 has only one call');
    expect(favs.first.totalCalls, 2);
    expect(favs.first.callsByNumber, {'9876543210': 2}, reason: 'same number, different formatting');
  });

  /// A server like hsh_api: stores calls (ignoring repeated ids), deletes
  /// a student's calls, and is unreachable (404) while [online] is false.
  Map<String, Map> serve({required bool Function() online}) {
    final stored = <String, Map>{}; // client_call_id -> call
    const down = FakeReply(404, {'success': false, 'message': 'Not found'});
    api.routes['POST /phonebook/calls'] = (o) {
      if (!online()) return down;
      for (final c in (o.data as Map)['calls'] as List) {
        stored.putIfAbsent((c as Map)['client_call_id'] as String, () => c);
      }
      return const FakeReply(200, {'success': true, 'data': {}});
    };
    api.routes['DELETE /phonebook/favourites/HSH-1'] = (o) {
      if (!online()) return down;
      stored.removeWhere((_, c) => c['student_key'] == 'HSH-1');
      return const FakeReply(200, {'success': true, 'data': {}});
    };
    api.routes['GET /phonebook/favourites'] = (o) =>
        online() ? const FakeReply(200, {'success': true, 'data': []}) : down;
    return stored;
  }

  test('calls made offline reach the server exactly once, in UTC', () async {
    var online = false;
    final stored = serve(online: () => online);

    await call('HSH-1', '98765 43210');
    await call('HSH-1', '98765 43210');
    await service.topFavourites(); // server down: kept in the queue
    expect(stored, isEmpty);

    online = true;
    await service.topFavourites();
    await service.topFavourites();

    expect(stored, hasLength(2), reason: 'both calls, no duplicates');
    final c = stored.values.first;
    expect(c['student_key'], 'HSH-1');
    expect(c['phone_normalized'], '9876543210');
    expect(DateTime.parse(c['called_at'] as String).isUtc, isTrue);

    // Queue is empty now: the next refresh uploads nothing.
    final posts = api.called('POST /phonebook/calls').length;
    await service.topFavourites();
    expect(api.called('POST /phonebook/calls').length, posts);
  });

  test('a retried upload reuses its client_call_id', () async {
    var online = false;
    serve(online: () => online);
    await call('HSH-1', '98765 43210');
    await service.topFavourites();
    online = true;
    await service.topFavourites();

    final ids = api
        .called('POST /phonebook/calls')
        .expand((r) => (r.data as Map)['calls'] as List)
        .map((c) => (c as Map)['client_call_id'])
        .toSet();
    expect(ids, hasLength(1));
  });

  test('remove leaves no calls for that student on the server', () async {
    var online = false;
    final stored = serve(online: () => online);

    await call('HSH-1', '98765 43210');
    await call('HSH-1', '98765 43210');
    await service.remove('HSH-1');
    online = true;
    await service.topFavourites();

    expect(api.called('DELETE /phonebook/favourites/HSH-1'), isNotEmpty);
    expect(stored.values.where((c) => c['student_key'] == 'HSH-1'), isEmpty);
    expect(await service.topFavourites(), isEmpty);
  });

  test('remove after the calls were uploaded deletes them on the server', () async {
    final stored = serve(online: () => true);
    await call('HSH-1', '98765 43210');
    await call('HSH-1', '98765 43210');
    await service.topFavourites();
    expect(stored, hasLength(2));

    await service.remove('HSH-1');
    await service.topFavourites();
    expect(stored, isEmpty);
  });

  test('remove while an upload is in flight still deletes on the server', () async {
    final stored = serve(online: () => true);
    await call('HSH-1', '98765 43210'); // starts an upload, not awaited
    await service.remove('HSH-1'); // edits the queue mid-upload
    await service.topFavourites();
    await service.topFavourites();

    expect(api.called('DELETE /phonebook/favourites/HSH-1'), isNotEmpty,
        reason: 'the queued remove must not be dropped by the finishing upload');
    expect(stored, isEmpty);
  });

  test('a 404 on delete counts as removed', () async {
    api.on('DELETE /phonebook/favourites/HSH-9', {'success': false, 'message': 'Not found'},
        status: 404);
    api.on('GET /phonebook/favourites', {'success': true, 'data': []});
    await service.remove('HSH-9');
    await service.topFavourites();

    final deletes = api.called('DELETE /phonebook/favourites/HSH-9').length;
    await service.topFavourites();
    expect(api.called('DELETE /phonebook/favourites/HSH-9').length, deletes,
        reason: 'not retried');
  });

  test('logout clears this admin\'s local favourites and queue', () async {
    await call('HSH-1', '98765 43210');
    await call('HSH-1', '98765 43210');

    await service.clearLocal();
    service.resetForTest();

    final favs = await service.topFavourites();
    expect(favs, isEmpty);
    api.requests.clear();
    await service.topFavourites();
    expect(api.called('POST /phonebook/calls'), isEmpty);
  });
}
