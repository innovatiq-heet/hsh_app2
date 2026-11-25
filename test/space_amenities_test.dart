import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hsh_app2/core/network/repository/space_amenities/space_amenities_repository.dart';
import 'package:hsh_app2/core/network/request/complaints/submit_complaint_request.dart';
import 'package:hsh_app2/core/network/responses/complaints/complaint_response.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/space_amenities/controllers/space_amenities_controller.dart';
import 'package:hsh_app2/features/space_amenities/utils/space_amenity_ui.dart';
import 'support/fake_api.dart';

void main() {
  group('SpaceAmenityUi', () {
    test('extracts HSH asset codes from QR payloads and rejects partial codes', () {
      expect(SpaceAmenityUi.assetCodeIn('https://hsh.example/a/HSH-FAN-00124'), 'HSH-FAN-00124');
      expect(SpaceAmenityUi.assetCodeIn('hsh-ac-00007'), 'HSH-AC-00007');
      expect(SpaceAmenityUi.assetCodeIn('HSH-FAN-124'), isNull);
      expect(SpaceAmenityUi.assetCodeIn(null), isNull);
    });
  });

  group('SpaceAmenitiesRepository & Models', () {
    late FakeApi api;
    late SpaceAmenitiesRepository repo;

    setUp(() {
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({
        'auth_token': 'admin-token',
        'user_session': jsonEncode({'role': 'admin', 'token': 'admin-token', 'name': 'Admin'}),
      });
      Get.put(SessionStore());
      api = FakeApi()..install();
      repo = SpaceAmenitiesRepository();
    });

    tearDown(Get.reset);

    test('parses overview and dynamic floors without hardcoding', () async {
      api.on('GET /space-amenities/overview', {
        'success': true,
        'data': {
          'summary': {
            'total_spaces': 12,
            'total_assets': 48,
            'working_assets': 45,
            'faulty_assets': 3,
            'under_repair_assets': 1,
            'awaiting_replacement_assets': 0,
            'open_complaints': 2,
            'pending_complaints': 1,
            'in_progress_complaints': 1,
            'resolved_complaints': 5,
            'total_maintenance_cost': 1200,
            'total_maintenance_records': 4,
          },
          'floors': [
            {
              'floor_id': 0,
              'floor_name': 'Ground Floor',
              'total_spaces': 2,
              'student_rooms_count': 0,
              'total_assets': 6,
              'working_assets': 6,
              'faulty_assets': 0,
              'open_issues': 0,
              'health_status': 'healthy',
              'special_spaces': ['Rector Room'],
              'subtitle': 'Rector Room',
            },
          ],
        },
      });

      final ov = await repo.overview();
      expect(ov.summary.totalSpaces, 12);
      expect(ov.summary.faultyAssets, 3);
      expect(ov.floors.single.floorName, 'Ground Floor');
      expect(ov.floors.single.specialSpaces, ['Rector Room']);
    });

    test('bulk registration, transfer, and maintenance update send expected bodies', () async {
      api.on('POST /space-amenities/assets/bulk', {'success': true, 'data': []});
      api.on('POST /space-amenities/assets/7/transfer', {
        'success': true,
        'data': {
          'asset': {
            'id': 7,
            'asset_code': 'HSH-FAN-00007',
            'type_id': 1,
            'type_name': 'Fan',
            'type_icon': 'mode_fan_off',
            'category_id': 1,
            'category_name': 'Electrical',
            'space_id': 12,
            'space_name': 'Study Room',
            'floor_id': 1,
            'floor_name': 'Floor 1',
            'name': 'Fan',
            'status': 'working',
            'condition': 'good',
            'warranty_status': 'none',
            'is_archived': false,
            'open_complaints_count': 0,
          },
          'quick_stats': {'total_repairs': 0, 'open_complaints': 0, 'warranty_status': 'none'},
          'timeline': [],
          'complaints': [],
          'location_history': [],
          'maintenance_records': [],
        },
      });
      api.on('POST /space-amenities/maintenance/update', {'success': true, 'data': {}});

      await repo.registerAssetsBulk({'space_id': 5, 'type_id': 1, 'quantity': 4});
      expect(api.last('POST /space-amenities/assets/bulk').data['quantity'], 4);

      await repo.transferAsset(7, destinationSpaceId: 12, reason: 'Needed in study room');
      expect(api.last('POST /space-amenities/assets/7/transfer').data, {
        'destination_space_id': 12,
        'reason': 'Needed in study room',
      });

      await repo.submitMaintenanceUpdate({
        'asset_id': 7,
        'complaint_id': 42,
        'action': 'complete_repair',
        'material_cost': 100,
        'labor_cost': 50,
      });
      expect(api.last('POST /space-amenities/maintenance/update').data['complaint_id'], 42);
    });

    test('SubmitComplaintRequest and ComplaintResponse handle linked asset fields cleanly', () {
      const req = SubmitComplaintRequest(roomId: '204', categoryId: 1, itemId: 1, spaceId: 5, assetId: 7);
      expect(req.toJson()['asset_id'], 7);
      expect(req.toJson()['space_id'], 5);

      final plain = const SubmitComplaintRequest(roomId: '204', categoryId: 1, itemId: 1).toJson();
      expect(plain.containsKey('asset_id'), isFalse);

      final parsed = ComplaintResponse.fromJson({
        'id': 42,
        'room_id': '204',
        'category_id': 1,
        'category': 'Electrical',
        'item_id': 1,
        'item': 'Fan',
        'status': 'OPEN',
        'asset_id': 7,
        'asset_code': 'HSH-FAN-00007',
        'asset_name': 'Ceiling Fan',
        'space_id': 5,
        'space_name': 'Room 204',
      });
      expect(parsed.assetId, 7);
      expect(parsed.assetCode, 'HSH-FAN-00007');
      expect(parsed.spaceName, 'Room 204');
    });

    test('SpaceAmenitiesHomeController loads overview and opens faulty assets filter', () async {
      api.on('GET /space-amenities/overview', {
        'success': true,
        'data': {
          'summary': {
            'total_spaces': 1,
            'total_assets': 2,
            'working_assets': 1,
            'faulty_assets': 1,
            'under_repair_assets': 0,
            'awaiting_replacement_assets': 0,
            'open_complaints': 1,
            'pending_complaints': 1,
            'in_progress_complaints': 0,
            'resolved_complaints': 0,
            'total_maintenance_records': 0,
          },
          'floors': [],
        },
      });
      api.on('GET /space-amenities/assets', {'success': true, 'data': []});

      final c = Get.put(SpaceAmenitiesHomeController(repository: repo));
      await c.loadOverview();
      expect(c.overview.value?.summary.faultyAssets, 1);

      c.openFaultyAssets();
      expect(c.activeSection.value, 1);
      expect(c.assetStatusFilter.value, 'faulty_group');
    });
  });
}
