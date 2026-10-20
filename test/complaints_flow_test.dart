import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide FormData;
import 'package:hsh_app2/core/enums/complaint_status.dart';
import 'package:hsh_app2/core/network/api_exception.dart';
import 'package:hsh_app2/core/network/repository/authentication/auth_repository.dart';
import 'package:hsh_app2/core/network/repository/complaints/complaints_repository.dart';
import 'package:hsh_app2/core/network/request/complaints/submit_complaint_request.dart';
import 'package:hsh_app2/core/network/responses/complaints/complaint_catalog.dart';
import 'package:hsh_app2/core/network/responses/complaints/complaint_response.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/core/utils/image_type.dart';
import 'package:hsh_app2/features/complaints/controllers/add_complaint_controller.dart';
import 'package:hsh_app2/features/complaints/controllers/complaint_orders_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Room complaints against the `/complaint-categories`, `/complaint-items`,
/// `/complaints` and `/admin/complaints` contract, with HTTP faked offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;

  Map<String, dynamic> complaintJson({
    String status = 'OPEN',
    String? imageUrl = '/api/complaints/12/image',
    bool withStudent = false,
  }) =>
      {
        'id': 12,
        'room_id': '101',
        'category_id': 1,
        'category': 'Electrical',
        'item_id': 5,
        'item': 'AC',
        'item_code': 'AC',
        'comment': 'AC not cooling',
        'image_url': imageUrl,
        'status': status,
        'created_at': '2026-10-20 14:05:11',
        'updated_at': '2026-10-20 14:05:11',
        if (withStudent)
          'student': {'id': 42, 'name': 'Rahul Patel', 'student_code': '0768'},
      };

  const electricalItems = [
    {'id': 1, 'categoryId': 1, 'name': 'Fan', 'code': 'FAN'},
    {'id': 5, 'categoryId': 1, 'name': 'AC', 'code': 'AC'},
  ];

  /// Replaces the stored session (every test starts as a student in 101).
  void signIn(String role, {String room = '101'}) {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'user_session': jsonEncode({'role': role, 'token': 'test-token', 'name': 'Test', 'room': room}),
    });
    if (Get.isRegistered<SessionStore>()) Get.delete<SessionStore>(force: true);
    Get.put(SessionStore());
  }

  Future<File> tempFile(List<int> bytes) async {
    final dir = await Directory.systemTemp.createTemp('hsh_complaint_test');
    addTearDown(() => dir.delete(recursive: true));
    return File('${dir.path}/photo.jpg')..writeAsBytesSync(bytes);
  }

  const jpegBytes = [0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1, 1, 0, 0, 1];
  // An iPhone HEIC: "....ftypheic" — not something the API accepts.
  final heicBytes = [0, 0, 0, 0x18, ...ascii.encode('ftypheic'), 0, 0, 0, 0];

  setUp(() {
    Get.testMode = true;
    signIn('student');
    api = FakeApi()..install();
    Get.put(AuthRepository());
    Get.put(ComplaintsRepository());
    api.on('GET /complaint-categories', {
      'success': true,
      'data': [
        {'id': 1, 'name': 'Electrical'},
        {'id': 2, 'name': 'Carpentry'},
      ],
    });
    api.routes['GET /complaint-items'] = (o) => FakeReply(200, {
          'success': true,
          'data': o.queryParameters['categoryId'] == 1 ? electricalItems : [],
        });
    api.on('GET /auth/me', {
      'success': true,
      'data': {'id': 42, 'name': 'Rahul Patel', 'role': 'student', 'room': '101', 'room_number': '101'},
    });
    api.on(
      'POST /complaints',
      {'success': true, 'message': 'Complaint submitted successfully', 'data': complaintJson()},
      status: 201,
    );
  });

  tearDown(Get.reset);

  group('ComplaintResponse', () {
    test('parses the API shape, including the solver-only student', () {
      final c = ComplaintResponse.fromJson(complaintJson(withStudent: true));

      expect(c.id, '12');
      expect(c.roomId, '101');
      expect(c.categoryId, 1);
      expect(c.item, 'AC');
      expect(c.comment, 'AC not cooling');
      expect(c.status, ComplaintStatus.open);
      expect(c.student?.id, 42);
      expect(c.student?.studentCode, '0768');
      // image_url already starts with /api: it must not be doubled.
      expect(c.absoluteImageUrl, endsWith('.com/api/complaints/12/image'));
    });

    test('a null image_url means no photo', () {
      final c = ComplaintResponse.fromJson(complaintJson(imageUrl: null));

      expect(c.hasImage, isFalse);
      expect(c.absoluteImageUrl, isNull);
      expect(c.student, isNull);
    });

    test('statuses round-trip and use the agreed student labels', () {
      for (final s in ComplaintStatus.values) {
        expect(ComplaintStatusX.fromApi(s.apiValue), s);
      }
      expect(ComplaintStatus.values.map((s) => s.apiValue), ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED']);
      expect(ComplaintStatus.values.map((s) => s.label), ['Submitted', 'In progress', 'Resolved', 'Closed']);
      expect(ComplaintStatus.open.staffLabel, 'Open');
    });
  });

  group('student: new complaint', () {
    Future<AddComplaintController> open() async {
      final controller = Get.put(AddComplaintController());
      await until(() => !controller.isLoading.value, reason: 'form load');
      return controller;
    }

    Future<AddComplaintController> openWithItem() async {
      final controller = await open();
      await controller.selectCategory(controller.categories.first);
      controller.selectItem(controller.items.firstWhere((i) => i.name == 'AC'));
      return controller;
    }

    test('loads categories and takes the room from /auth/me', () async {
      signIn('student', room: '999'); // stale cached room
      final controller = await open();

      expect(controller.categories.map((c) => c.name), ['Electrical', 'Carpentry']);
      expect(controller.room.value, '101');
      expect(controller.hasRoom, isTrue);
    });

    test('choosing a category loads its items by categoryId', () async {
      final controller = await open();
      await controller.selectCategory(controller.categories.first);

      expect(api.last('GET /complaint-items').queryParameters['categoryId'], 1);
      expect(controller.items.map((i) => i.name), ['Fan', 'AC']);
      expect(controller.selectedItem.value, isNull);
    });

    test('without a photo it posts JSON with only room, category, item and comment', () async {
      final controller = await openWithItem();
      controller.commentController.text = '  AC not cooling  ';

      expect(await controller.submit(), isTrue);

      expect(api.last('POST /complaints').data, {
        'room_id': '101',
        'category_id': 1,
        'item_id': 5,
        'comment': 'AC not cooling',
      });
    });

    test('an empty comment is left out', () async {
      final controller = await openWithItem();

      expect(await controller.submit(), isTrue);

      final body = api.last('POST /complaints').data as Map;
      expect(body.containsKey('comment'), isFalse);
      expect(body.containsKey('status'), isFalse);
      expect(body.containsKey('image_url'), isFalse);
    });

    test('with a photo it posts multipart, the file in "image" typed by its content', () async {
      final controller = await openWithItem();
      controller.image.value = await tempFile(jpegBytes);

      expect(await controller.submit(), isTrue);

      final form = api.last('POST /complaints').data as FormData;
      expect(Map.fromEntries(form.fields), {'room_id': '101', 'category_id': '1', 'item_id': '5'});
      expect(form.files.map((f) => f.key), ['image']);
      expect(form.files.single.value.contentType?.mimeType, 'image/jpeg');
    });

    test('a student without a room (alumni) cannot submit', () async {
      signIn('student', room: 'N/A');
      api.on('GET /auth/me', {
        'success': true,
        'data': {'id': 42, 'name': 'Old Boy', 'role': 'alumni', 'room': 'N/A', 'room_number': 'N/A'},
      });
      final controller = await open();

      expect(controller.hasRoom, isFalse);
      expect(await controller.submit(), isFalse);
      expect(api.called('POST /complaints'), isEmpty);
    });

    test('the server message is passed through (403 other room)', () async {
      api.on(
        'POST /complaints',
        {'success': false, 'message': 'You can only submit complaints for your own room'},
        status: 403,
      );

      await expectLater(
        Get.find<ComplaintsRepository>().submit(
          const SubmitComplaintRequest(roomId: '102', categoryId: 1, itemId: 5),
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'You can only submit complaints for your own room')),
      );
    });

    test('photos the API would reject are refused before upload', () async {
      expect(await AddComplaintController.validateImage(await tempFile(jpegBytes)), isNull);
      expect(await AddComplaintController.validateImage(await tempFile(heicBytes)), contains('JPEG, PNG or WebP'));
      final big = await tempFile([...jpegBytes, ...List.filled(ImageType.maxUploadBytes, 0)]);
      expect(await AddComplaintController.validateImage(big), contains('5 MB'));

      await expectLater(
        Get.find<ComplaintsRepository>().submit(
          SubmitComplaintRequest(roomId: '101', categoryId: 1, itemId: 5, image: await tempFile(heicBytes)),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(api.called('POST /complaints'), isEmpty);
    });
  });

  group('student: my complaints', () {
    test('an empty list is not an error', () async {
      api.on('GET /complaints/my', {'success': true, 'data': []});

      expect(await Get.find<ComplaintsRepository>().myComplaints(), isEmpty);
      expect(api.last('GET /complaints/my').queryParameters, {'limit': 50, 'offset': 0});
    });

    test('a 500 shows a generic message, not "Server error"', () async {
      api.on('GET /complaints/my', {'success': false, 'message': 'Server error'}, status: 500);

      await expectLater(
        Get.find<ComplaintsRepository>().myComplaints(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Something went wrong, try again')),
      );
    });
  });

  group('solver desk', () {
    late ComplainOrdersController controller;

    int listCalls() => api.called('GET /admin/complaints').length;

    setUp(() async {
      signIn('complain-solver', room: '');
      api.on('GET /admin/complaints', {
        'success': true,
        'data': [complaintJson(withStudent: true)],
      });
      api.on('PATCH /admin/complaints/12/status', {
        'success': true,
        'data': complaintJson(status: 'IN_PROGRESS', withStudent: true),
      });
      controller = Get.put(ComplainOrdersController());
      await until(() => !controller.isLoading.value, reason: 'desk load');
    });

    test('opens on the open queue, first page', () {
      expect(api.last('GET /admin/complaints').queryParameters, {'status': 'OPEN', 'limit': 50, 'offset': 0});
      expect(controller.complaints.single.student?.name, 'Rahul Patel');
    });

    test('category, room and status filters are applied by the API', () async {
      controller.setCategoryFilter(const ComplaintCategory(id: 2, name: 'Carpentry'));
      await until(() => listCalls() == 2, reason: 'category reload');
      expect(api.last('GET /admin/complaints').queryParameters['categoryId'], 2);

      controller.searchRoom(' 101 ');
      await until(() => listCalls() == 3, reason: 'room reload');
      expect(api.last('GET /admin/complaints').queryParameters['room_id'], '101');

      controller.setStatusFilter(null);
      await until(() => listCalls() == 4, reason: 'all statuses reload');
      expect(api.last('GET /admin/complaints').queryParameters.containsKey('status'), isFalse);
    });

    test('changing the status sends only the status and replaces the row', () async {
      await controller.changeStatus(controller.complaints.single, ComplaintStatus.inProgress);

      expect(api.last('PATCH /admin/complaints/12/status').data, {'status': 'IN_PROGRESS'});
      expect(controller.complaints.single.status, ComplaintStatus.inProgress);
    });

    test('a rejected status change leaves the row as it was', () async {
      api.on(
        'PATCH /admin/complaints/12/status',
        {'success': false, 'message': 'Forbidden: requires one of the following roles: [complain-solver]'},
        status: 403,
      );

      await controller.changeStatus(controller.complaints.single, ComplaintStatus.closed);

      expect(controller.complaints.single.status, ComplaintStatus.open);
      expect(controller.updatingId.value, isNull);
    });
  });

  test('image sniffing matches the API: JPEG, PNG, WebP only', () {
    expect(ImageType.sniffMimeType(jpegBytes), 'image/jpeg');
    expect(ImageType.sniffMimeType([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0]), 'image/png');
    expect(ImageType.sniffMimeType([...ascii.encode('RIFF'), 0, 0, 0, 0, ...ascii.encode('WEBP'), 0]), 'image/webp');
    expect(ImageType.sniffMimeType(heicBytes), isNull);
  });
}
