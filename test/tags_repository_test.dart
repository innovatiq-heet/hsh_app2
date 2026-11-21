import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/network/api_exception.dart';
import 'package:hsh_app2/core/network/repository/tags/tags_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;
  late TagsRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'test-token', 'name': 'Warden'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    repo = TagsRepository();
  });

  tearDown(Get.reset);

  group('TagsRepository', () {
    test('getTags returns list of StudentTag objects', () async {
      api.on('GET /tags', {
        'success': true,
        'data': [
          {'id': 1, 'name': 'Regular', 'color': '#10b981', 'is_system': 1, 'student_count': 10},
          {'id': 2, 'name': 'Sports', 'color': '#0284c7', 'is_system': 0, 'student_count': 5},
        ],
      });

      final tags = await repo.getTags();
      expect(tags, hasLength(2));
      expect(tags[0].id, 1);
      expect(tags[0].name, 'Regular');
      expect(tags[0].isSystem, isTrue);
      expect(tags[1].id, 2);
      expect(tags[1].name, 'Sports');
      expect(tags[1].isSystem, isFalse);
    });

    test('createTag posts payload and returns created StudentTag', () async {
      api.on('POST /tags', {
        'success': true,
        'data': {
          'id': 15,
          'name': 'Hostel Committee',
          'color': '#10b981',
          'is_system': 0,
          'description': 'Floor reps',
          'student_count': 0,
        },
      });

      final created = await repo.createTag(
        name: 'Hostel Committee',
        color: '#10b981',
        description: 'Floor reps',
      );

      expect(created.id, 15);
      expect(created.name, 'Hostel Committee');
      expect(created.colorHex, '#10b981');
      expect(created.description, 'Floor reps');

      final req = api.last('POST /tags');
      expect(req.data, {
        'name': 'Hostel Committee',
        'color': '#10b981',
        'description': 'Floor reps',
      });
    });

    test('updateTag puts payload to /tags/:id and returns updated StudentTag', () async {
      api.on('PUT /tags/12', {
        'success': true,
        'message': 'Tag updated successfully',
        'data': {
          'id': 12,
          'name': 'Hostel Committee Renamed',
          'color': '#f59e0b',
          'is_system': 0,
          'description': 'Updated description',
          'student_count': 14,
        },
      });

      final updated = await repo.updateTag(
        id: 12,
        name: 'Hostel Committee Renamed',
        color: '#f59e0b',
        description: 'Updated description',
      );

      expect(updated.id, 12);
      expect(updated.name, 'Hostel Committee Renamed');
      expect(updated.colorHex, '#f59e0b');
      expect(updated.description, 'Updated description');
      expect(updated.studentCount, 14);

      final req = api.last('PUT /tags/12');
      expect(req.data, {
        'name': 'Hostel Committee Renamed',
        'color': '#f59e0b',
        'description': 'Updated description',
      });
    });

    test('updateTag throws ApiException on 400 validation error (e.g. duplicate name)', () async {
      api.on('PUT /tags/12', {
        'success': false,
        'message': 'A tag with this name already exists',
      }, status: 400);

      expect(
        () => repo.updateTag(
          id: 12,
          name: 'Existing Tag',
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          'A tag with this name already exists',
        )),
      );
    });

    test('deleteTag sends DELETE request to /tags/:id', () async {
      api.on('DELETE /tags/12', {
        'success': true,
        'message': 'Tag deleted',
      });

      await repo.deleteTag(12);
      expect(api.called('DELETE /tags/12'), hasLength(1));
    });
  });
}
