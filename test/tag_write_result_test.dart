import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/network/repository/tags/tags_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Tag changes report how long the server's cached student list may still
/// show the old tags (`refresh_in_seconds`, `notice`); the app shows the notice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reading the reply', () {
    test('a cached list: seconds and the notice', () {
      final r = TagWriteResult.fromBody({
        'success': true,
        'refresh_in_seconds': 18,
        'notice': 'Saved. The student list may take up to 18 seconds to show this change.',
      });
      expect(r.refreshInSeconds, 18);
      expect(r.addTo('Tag "A" removed from Ravi.'),
          'Tag "A" removed from Ravi.\nSaved. The student list may take up to 18 seconds to show this change.');
    });

    test('nothing cached, or an older server: no notice, message unchanged', () {
      for (final body in [
        {'success': true, 'refresh_in_seconds': 0, 'notice': null},
        {'success': true},
        {'success': true, 'refresh_in_seconds': '-3', 'notice': '  '},
        null,
      ]) {
        final r = TagWriteResult.fromBody(body);
        expect(r.refreshInSeconds, 0, reason: '$body');
        expect(r.notice, isNull, reason: '$body');
        expect(r.addTo('Done.'), 'Done.');
      }
    });

    test('several writes keep the longest wait', () {
      const a = TagWriteResult(refreshInSeconds: 5, notice: 'five');
      const b = TagWriteResult(refreshInSeconds: 20, notice: 'twenty');
      expect(a.laterOf(b).notice, 'twenty');
      expect(b.laterOf(a).notice, 'twenty');
      expect(a.laterOf(TagWriteResult.none).notice, 'five');
    });
  });

  group('repository', () {
    late FakeApi api;

    setUp(() {
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({
        'auth_token': 'admin-token',
        'user_session': jsonEncode({'role': 'admin', 'token': 'admin-token', 'name': 'Super Admin'}),
      });
      Get.put(SessionStore());
      api = FakeApi()..install();
    });

    tearDown(Get.reset);

    test('assign, remove and delete return the wait; rename leaves it in lastWrite', () async {
      const reply = {'success': true, 'refresh_in_seconds': 12, 'notice': 'Wait 12'};
      api.on('POST /tags/student/812', reply);
      api.on('DELETE /tags/student/812/3', reply);
      api.on('DELETE /tags/3', {'success': true, 'refresh_in_seconds': 0, 'notice': null});
      api.on('PUT /tags/3', {
        'success': true,
        'refresh_in_seconds': 7,
        'notice': 'Wait 7',
        'data': {'id': 3, 'name': 'Renamed', 'color': '#111111'},
      });
      final repo = TagsRepository();

      expect((await repo.assignTag(studentId: 812, tagId: 3)).notice, 'Wait 12');
      expect((await repo.assignTags(studentId: 812, tagIds: [3, 4])).refreshInSeconds, 12);
      expect((await repo.removeTag(studentId: 812, tagId: 3)).notice, 'Wait 12');
      expect((await repo.deleteTag(3)).notice, isNull);

      final tag = await repo.updateTag(id: 3, name: 'Renamed');
      expect(tag.name, 'Renamed');
      expect(repo.lastWrite.notice, 'Wait 7');
    });
  });
}
