import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/network/repository/students/student_picker_source.dart';
import 'package:hsh_app2/core/network/repository/tags/tags_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// The picker's student list is a heavy download (`/students?all=true`), so
/// it is downloaded once and shared.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;
  var now = DateTime(2026, 11, 21, 10);

  StudentPickerSource source() => StudentPickerSource(tags: Get.find<TagsRepository>(), clock: () => now);

  int downloads() => api.called('GET /students').length;

  setUp(() {
    Get.testMode = true;
    now = DateTime(2026, 11, 21, 10);
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'token', 'name': 'Admin'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    Get.put(TagsRepository());
    api.on('GET /students', {
      'success': true,
      'data': [
        {'id': 1, 'name': 'Asha Patel', 'room_number': '101'},
        {'id': 2, 'name': 'Bhavin Shah', 'room_number': '102'},
        {'id': 3, 'name': 'Old Student', 'room_number': ''},
      ],
    });
  });

  tearDown(() {
    StudentPickerSource.clearCache();
    Get.reset();
  });

  test('the list is downloaded once and reused by every picker', () async {
    final first = await source().load();
    final second = await source().load(); // another screen, same app
    final third = await source().load(includeAlumni: true);

    expect(downloads(), 1);
    expect(first.map((s) => s.id), [1, 2], reason: 'residents only, by name');
    expect(second.map((s) => s.id), [1, 2]);
    expect(third.map((s) => s.id), [1, 2, 3], reason: 'alumni come from the same download');
  });

  test('pickers asking at the same time share one request', () async {
    final results = await Future.wait([source().load(), source().load(includeAlumni: true), source().load()]);

    expect(downloads(), 1);
    expect(results.map((r) => r.length), [2, 3, 2]);
  });

  test('refresh downloads again; so does an old list', () async {
    await source().load();
    await source().load(refresh: true);
    expect(downloads(), 2);

    now = now.add(StudentPickerSource.maxAge + const Duration(seconds: 1));
    await source().load();
    expect(downloads(), 3);
  });

  test('clearing the cache (logout) forces a new download', () async {
    await source().load();
    StudentPickerSource.clearCache();
    await source().load();
    expect(downloads(), 2);
  });

  test('a failed download is not kept, so the next try asks again', () async {
    api.on('GET /students', {'success': false, 'message': 'down'}, status: 500);
    api.on('GET /screen-time/students', {'success': false, 'message': 'down'}, status: 500);
    await expectLater(source().load(), throwsA(anything));

    api.on('GET /students', {
      'success': true,
      'data': [
        {'id': 1, 'name': 'Asha Patel', 'room_number': '101'},
      ],
    });
    expect((await source().load()).map((s) => s.id), [1]);
  });
}
