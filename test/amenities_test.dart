import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/amenities/amenity_models.dart';
import 'package:hsh_app2/core/network/api_exception.dart';
import 'package:hsh_app2/core/network/repository/amenities/amenities_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/amenities/controllers/amenities_home_controller.dart';
import 'package:hsh_app2/features/amenities/utils/amenity_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Amenities Management (`/api/amenities`) with HTTP faked offline: paths,
/// partial bodies, numeric student ids, model parsing and the home
/// controller's drill-down and filters.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;
  late AmenitiesRepository repo;

  Map<String, dynamic> assetJson({int id = 7, String code = 'HSH-FAN-00012', String status = 'active'}) => {
        'id': id,
        'asset_code': code,
        'type_id': 3,
        'type_name': 'Ceiling fan',
        'category_id': 1,
        'category_name': 'Electrical',
        'label': 'Near window',
        'serial_number': 'CF-881',
        'status': status,
        'condition': 'new',
        'placement': 'installed',
        'current_assignment': {
          'id': 40,
          'asset': {'id': id, 'asset_code': code, 'type_id': 3, 'type_name': 'Ceiling fan', 'status': status},
          'type': {'id': 3, 'name': 'Ceiling fan', 'unit': 'pcs', 'tracking': 'individual'},
          'quantity': 1,
          'returned_quantity': 0,
          'location': {'id': 12, 'path': 'Main › Floor 2 › Room 204'},
          'room_number': '204',
          'assigned_at': '2026-11-01T10:00:00Z',
          'condition_at_assignment': 'good',
        },
        'home_location': {'id': 2, 'path': 'Main › Store'},
        'purchase_cost': '2450.00',
        'warranty': 'active',
        'qr_payload': 'https://hsh.example/a/$code',
      };

  Future<void> signIn(String role) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 't',
      'user_session': jsonEncode({'role': role, 'token': 't', 'name': 'Tester'}),
    });
    final store = Get.put(SessionStore());
    await store.role; // loads the cached session
  }

  setUp(() async {
    Get.testMode = true;
    await signIn('warden');
    api = FakeApi()..install();
    repo = AmenitiesRepository();
  });

  tearDown(Get.reset);

  group('models', () {
    test('asset parses status, condition, placement and its open assignment', () {
      final a = AmenityAsset.fromJson(assetJson(status: 'under_repair'));
      expect(a.assetCode, 'HSH-FAN-00012');
      expect(a.status, AssetStatus.underRepair);
      expect(a.condition, AssetCondition.newItem);
      expect(a.placement, AssetPlacement.installed);
      expect(a.currentAssignment!.isOpen, isTrue);
      expect(a.currentAssignment!.location!.path, contains('Room 204'));
      expect(a.homeLocation!.id, 2);
      expect(a.qrPayload, endsWith('/a/HSH-FAN-00012'));
    });

    test('unknown status falls back to active; unknown condition is null', () {
      expect(AssetStatus.parse('melted'), AssetStatus.active);
      expect(AssetCondition.parse('meh'), isNull);
      expect(AssetCondition.newItem.api, 'new');
      expect(AssetStatus.issueReported.api, 'issue_reported');
    });

    test('bulk assignment: outstanding quantity and title', () {
      final a = AmenityAssignment.fromJson({
        'id': 5,
        'asset': null,
        'type': {'id': 9, 'name': 'Bedsheet', 'unit': 'pcs', 'tracking': 'bulk'},
        'quantity': 4,
        'returned_quantity': 1,
        'student': {'id': 1043, 'name': 'Asha', 'room': '204'},
      });
      expect(a.isBulk, isTrue);
      expect(a.outstanding, 3);
      expect(a.typeId, 9);
      expect(a.student!.id, 1043);
      expect(a.title, 'Bedsheet × 3');
    });

    test('dashboard reads totals, value and per-category values', () {
      final d = AmenitiesDashboard.fromJson({
        'totals': {'assets': 120, 'bulk_units': 300, 'lost': 2, 'value': '845000.00'},
        'categories': [
          {'id': 1, 'name': 'Electrical', 'assets': 80, 'bulk_units': 0, 'value': '500000.00'},
        ],
      });
      expect(d['assets'], 120);
      expect(d['lost'], 2);
      expect(d['missing_key'], 0);
      expect(d.value, '845000.00');
      expect(d.categories.single.assetCount, 80);
      expect(d.categoryValues[1], '500000.00');
    });

    test('location tree flattens depth-first', () {
      final l = AmenityLocation.fromJson({
        'id': 1,
        'kind': 'building',
        'name': 'Main',
        'children': [
          {
            'id': 2,
            'kind': 'floor',
            'name': 'Floor 2',
            'children': [
              {'id': 3, 'kind': 'room', 'name': '204', 'room_number': '204'},
            ],
          },
        ],
      });
      expect(l.flatten().map((e) => e.id), [1, 2, 3]);
      expect(l.flatten().last.kind, LocationKind.room);
    });

    test('paged list knows whether there is more', () {
      final p = Paged.fromJson({
        'items': [assetJson()],
        'total': 3,
        'limit': 1,
        'offset': 0,
      }, AmenityAsset.fromJson);
      expect(p.items, hasLength(1));
      expect(p.hasMore, isTrue);
    });
  });

  group('asset code in a scanned QR', () {
    test('finds the code in a URL, plain text or lower case', () {
      expect(AmenityFormat.assetCodeIn('https://hsh.example/a/HSH-FAN-00124'), 'HSH-FAN-00124');
      expect(AmenityFormat.assetCodeIn('hsh-key-00007'), 'HSH-KEY-00007');
      expect(AmenityFormat.assetCodeIn('asset HSH-AC-00031 room 204'), 'HSH-AC-00031');
    });

    test('rejects anything else', () {
      expect(AmenityFormat.assetCodeIn('https://example.com'), isNull);
      expect(AmenityFormat.assetCodeIn('HSH-FAN-124'), isNull);
      expect(AmenityFormat.assetCodeIn(null), isNull);
    });
  });

  group('repository', () {
    test('asset list sends only the set filters plus paging', () async {
      api.on('GET /amenities/assets', {
        'success': true,
        'data': {'items': [assetJson()], 'total': 1, 'limit': 50, 'offset': 0},
      });
      final page = await repo.assets(
        const AssetQuery(search: ' fan ', status: AssetStatus.underRepair, placement: AssetPlacement.withStudent, locationId: 12),
        offset: 50,
      );
      expect(page.items.single.id, 7);
      final q = api.last('GET /amenities/assets').queryParameters;
      expect(q, {
        'search': 'fan',
        'status': 'under_repair',
        'placement': 'with_student',
        'location_id': 12,
        'sort': 'code',
        'limit': 50,
        'offset': 50,
      });
    });

    test('assign to a student sends the numeric students.id only', () async {
      api.on('POST /amenities/assets/7/assign', {'success': true, 'data': {}, 'warning': 'Student is not an active resident.'});
      final r = await repo.assignAsset(7, const AssignTarget.student(1043), condition: AssetCondition.good, note: '  spare key ');
      expect(r.warning, 'Student is not an active resident.');
      final body = api.last('POST /amenities/assets/7/assign').data as Map;
      expect(body, {'student_id': 1043, 'condition': 'good', 'note': 'spare key'});
      expect(body.keys, isNot(contains('student_code')));
      expect(body.keys, isNot(contains('location_id')));
    });

    test('install at a location sends location_id only', () async {
      api.on('POST /amenities/assets/7/transfer', {'success': true, 'data': {}});
      await repo.transferAsset(7, const AssignTarget.location(12));
      expect(api.last('POST /amenities/assets/7/transfer').data, {'location_id': 12});
    });

    test('updates are partial: only the changed fields are sent', () async {
      api.on('PUT /amenities/assets/7', {'success': true, 'data': assetJson()});
      api.on('PUT /amenities/types/3', {'success': true, 'data': {'id': 3, 'name': 'Fan'}});
      api.on('PUT /amenities/locations/12', {'success': true, 'data': {'id': 12, 'kind': 'room', 'name': '204'}});
      await repo.updateAsset(7, {'label': 'By the door'});
      await repo.updateType(3, {'name': 'Fan'});
      await repo.updateLocation(12, {'is_active': false});
      expect(api.last('PUT /amenities/assets/7').data, {'label': 'By the door'});
      expect(api.last('PUT /amenities/types/3').data, {'name': 'Fan'});
      expect(api.last('PUT /amenities/locations/12').data, {'is_active': false});
    });

    test('status change, return and by-code lookup hit their endpoints', () async {
      api.on('POST /amenities/assets/7/status', {'success': true});
      api.on('POST /amenities/assets/7/return', {'success': true});
      api.on('GET /amenities/assets/by-code/HSH-FAN-00012', {'success': true, 'data': assetJson()});
      await repo.setStatus(7, AssetStatus.lost, note: 'Not in room');
      await repo.returnAsset(7, condition: AssetCondition.fair);
      final a = await repo.assetByCode('HSH-FAN-00012');
      expect(api.last('POST /amenities/assets/7/status').data, {'status': 'lost', 'note': 'Not in room'});
      expect(api.last('POST /amenities/assets/7/return').data, {'condition': 'fair'});
      expect(a.id, 7);
    });

    test('bulk: stock, assign, move and partial return bodies', () async {
      api.on('POST /amenities/types/9/stock', {'success': true});
      api.on('POST /amenities/types/9/assign', {'success': true, 'data': {}});
      api.on('POST /amenities/types/9/move', {'success': true});
      api.on('POST /amenities/assignments/5/return', {'success': true});
      await repo.addStock(9, quantity: 20, unitCost: '180.00');
      await repo.assignBulk(9, const AssignTarget.student(1043), quantity: 2);
      await repo.moveBulk(9, quantity: 3, from: BulkState.available, to: BulkState.underRepair);
      await repo.returnAssignment(5, quantity: 1, toState: BulkState.damaged);
      expect(api.last('POST /amenities/types/9/stock').data, {'quantity': 20, 'unit_cost': '180.00'});
      expect(api.last('POST /amenities/types/9/assign').data, {'student_id': 1043, 'quantity': 2});
      expect(api.last('POST /amenities/types/9/move').data, {'quantity': 3, 'from': 'available', 'to': 'under_repair'});
      expect(api.last('POST /amenities/assignments/5/return').data, {'quantity': 1, 'to_state': 'damaged'});
    });

    test('a bulk 409 surfaces the server message', () async {
      api.on('POST /amenities/types/9/assign', {'success': false, 'message': 'Only 3 Bedsheet available.'}, status: 409);
      await expectLater(
        repo.assignBulk(9, const AssignTarget.student(1043), quantity: 5),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Only 3 Bedsheet available.')),
      );
    });

    test("a student's amenities are loaded by numeric id", () async {
      api.on('GET /amenities/students/1043/amenities', {
        'success': true,
        'data': {
          'current': [assetJson()['current_assignment']],
          'returned': [],
          'lost_or_damaged': [],
        },
      });
      final s = await repo.studentAmenities(1043);
      expect(s.current, hasLength(1));
      expect(s.isEmpty, isFalse);
    });
  });

  group('home controller', () {
    Future<AmenitiesHomeController> loaded() async {
      api.on('GET /amenities/dashboard', {
        'success': true,
        'data': {
          'totals': {'assets': 2, 'lost': 1, 'value': '0'},
          'categories': [],
        },
      });
      api.on('GET /amenities/categories', {
        'success': true,
        'data': [
          {'id': 1, 'name': 'Electrical'},
        ],
      });
      api.on('GET /amenities/types', {
        'success': true,
        'data': [
          {'id': 3, 'category_id': 1, 'name': 'Ceiling fan', 'tracking': 'individual', 'code_prefix': 'FAN'},
          {'id': 9, 'category_id': 1, 'name': 'Bulb', 'tracking': 'bulk', 'code_prefix': 'BLB'},
        ],
      });
      api.on('GET /amenities/assets', {
        'success': true,
        'data': {'items': [assetJson()], 'total': 1, 'limit': 50, 'offset': 0},
      });
      final c = Get.put(AmenitiesHomeController(repository: repo, searchDebounce: Duration.zero));
      await until(() => c.dashboard.value != null && c.types.isNotEmpty, reason: 'dashboard');
      return c;
    }

    test('a dashboard card opens Inventory with that filter', () async {
      final c = await loaded();
      c.drillDown(const AssetQuery(status: AssetStatus.lost));
      expect(c.tab.value, 1);
      await until(() => !c.isInventoryLoading.value && c.assets.isNotEmpty, reason: 'inventory');
      expect(api.last('GET /amenities/assets').queryParameters['status'], 'lost');
      // A status filter only applies to individual assets: no bulk rows.
      expect(c.bulkTypes, isEmpty);
    });

    test('category filter shows a named chip that removes it', () async {
      final c = await loaded();
      c.setFilters(const AssetQuery(categoryId: 1));
      await until(() => !c.isInventoryLoading.value, reason: 'inventory');
      expect(c.bulkTypes.map((t) => t.id), [9]);
      final chip = c.filterChips.single;
      expect(chip.label, 'Electrical');
      c.setFilters(chip.without);
      expect(c.query.value.hasFilters, isFalse);
    });

    test('students and staff are refused before any request', () async {
      Get.reset();
      Get.testMode = true;
      await signIn('student');
      api = FakeApi()..install();
      final c = Get.put(AmenitiesHomeController(repository: AmenitiesRepository()));
      await until(() => c.accessDenied.value, reason: 'access check');
      expect(api.requests, isEmpty);
    });
  });
}
