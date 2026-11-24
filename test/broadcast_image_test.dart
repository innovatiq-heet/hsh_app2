import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show FormData;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide FormData;
import 'package:hsh_app2/core/models/broadcasts/broadcast_models.dart';
import 'package:hsh_app2/core/network/repository/broadcasts/broadcasts_repository.dart';
import 'package:hsh_app2/core/network/repository/tags/tags_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/core/utils/image_type.dart';
import 'package:hsh_app2/features/broadcast/controllers/broadcast_compose_controller.dart';
import 'package:hsh_app2/features/broadcast/utils/tag_members.dart';
import 'package:hsh_app2/features/broadcast/widgets/broadcast_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// A picture on a broadcast: upload (`POST /broadcasts/image`), send with
/// `image_id`, and `image_url` on the admin and inbox models. Offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;
  late BroadcastComposeController c;

  const debounce = Duration(milliseconds: 30);
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 120));

  const pngBytes = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0];
  const jpegBytes = [0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1, 1, 0, 0, 1];
  // An iPhone HEIC: "....ftypheic", not something the API accepts.
  final heicBytes = [0, 0, 0, 0x18, ...ascii.encode('ftypheic'), 0, 0, 0, 0];

  Future<File> tempFile(List<int> bytes, [String name = 'pic.png']) async {
    final dir = await Directory.systemTemp.createTemp('hsh_broadcast_image_test');
    addTearDown(() => dir.delete(recursive: true));
    return File('${dir.path}/$name')..writeAsBytesSync(bytes);
  }

  Map<String, dynamic> uploadReply(String id) => {
        'success': true,
        'data': {'image_id': id, 'image_url': 'https://api.test/uploads/$id'},
      };

  const imageId = 'bc_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png';

  Map<String, dynamic> broadcastJson({String? imageUrl}) => {
        'id': 91,
        'title': 'Holiday',
        'message': 'Hostel closed on Friday.',
        'image_url': imageUrl,
        'tags': <Object>[],
        'student_ids': [102],
        'status': 'sending',
        'recipient_count': 1,
        'sender': {'id': 1, 'name': 'Super Admin'},
        'created_at': '2026-11-11T09:30:00.000Z',
      };

  Future<BroadcastComposeController> open() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'token', 'name': 'Admin'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    Get.put(TagsRepository());
    Get.put(BroadcastsRepository());
    api.on('GET /tags', {
      'success': true,
      'data': [
        {'id': 3, 'name': 'Floor 2', 'color': '#0284C7', 'student_count': 40},
      ],
    });
    final controller = Get.put(BroadcastComposeController(previewDebounce: debounce));
    await until(
      () => controller.accessDenied.value || (controller.tags.isNotEmpty && !controller.isTagsLoading.value),
      reason: 'compose screen ready',
    );
    return controller;
  }

  /// A ready-to-send form (title, message, one tag, preview of 2).
  Future<void> fillValid() async {
    api.on('POST /broadcasts/preview', {
      'success': true,
      'data': {'recipient_count': 2, 'no_device_count': 0, 'sample': <Object>[]},
    });
    c.messageController.text = 'Hostel closed on Friday.';
    c.toggleTag(3);
    c.setTagScope(TagMemberScope.all);
    await settle();
  }

  setUp(() async {
    c = await open();
  });

  tearDown(Get.reset);

  group('compose: picture upload and send', () {
    test('uploads as multipart "image" typed by its content, then send carries image_id', () async {
      api.on('POST /broadcasts/image', uploadReply(imageId), status: 201);
      api.on('POST /broadcasts', {'success': true, 'data': broadcastJson(imageUrl: 'https://api.test/uploads/$imageId')}, status: 201);
      await fillValid();

      await c.attachImage(await tempFile(pngBytes));

      expect(c.isImageUploading.value, isFalse);
      expect(c.uploadedImage.value?.imageId, imageId);
      final form = api.last('POST /broadcasts/image').data as FormData;
      expect(form.files.map((f) => f.key), ['image']);
      expect(form.files.single.value.contentType?.mimeType, 'image/png');
      expect(form.files.single.value.filename, 'broadcast.png');

      final sent = await c.send();
      expect(sent?.imageUrl, 'https://api.test/uploads/$imageId');
      expect((api.last('POST /broadcasts').data as Map)['image_id'], imageId);
      // The picture was uploaded once, not again with the send.
      expect(api.called('POST /broadcasts/image'), hasLength(1));
    });

    test('without a picture the send body has no image_id', () async {
      api.on('POST /broadcasts', {'success': true, 'data': broadcastJson()}, status: 201);
      await fillValid();

      expect(await c.send(), isNotNull);
      expect((api.last('POST /broadcasts').data as Map).containsKey('image_id'), isFalse);
      expect(api.called('POST /broadcasts/image'), isEmpty);
    });

    test('a HEIC or a file over 5 MB is refused before any request', () async {
      await c.attachImage(await tempFile(heicBytes, 'iphone.heic'));
      expect(c.image.value, isNull);

      final big = await tempFile([...jpegBytes, ...List.filled(ImageType.maxUploadBytes, 0)], 'big.jpg');
      await c.attachImage(big);
      expect(c.image.value, isNull);
      expect(api.called('POST /broadcasts/image'), isEmpty);

      expect(await BroadcastComposeController.validateImage(await tempFile(jpegBytes)), isNull);
      expect(await BroadcastComposeController.validateImage(await tempFile(heicBytes)), contains('JPEG, PNG or WebP'));
    });

    test('a refused upload clears the picture and the send goes out text only', () async {
      api.on('POST /broadcasts/image', {'success': false, 'message': 'Admin access required.'}, status: 403);
      api.on('POST /broadcasts', {'success': true, 'data': broadcastJson()}, status: 201);
      await fillValid();

      await c.attachImage(await tempFile(pngBytes));

      expect(c.image.value, isNull);
      expect(c.uploadedImage.value, isNull);
      expect(c.isImageUploading.value, isFalse);
      await c.send();
      expect((api.last('POST /broadcasts').data as Map).containsKey('image_id'), isFalse);
    });

    test('removing the picture drops its id; choosing another replaces it', () async {
      var n = 0;
      api.routes['POST /broadcasts/image'] = (_) {
        n += 1;
        return FakeReply(201, uploadReply('bc_${'$n' * 32}.png'));
      };
      api.on('POST /broadcasts', {'success': true, 'data': broadcastJson()}, status: 201);
      await fillValid();

      await c.attachImage(await tempFile(pngBytes));
      expect(c.uploadedImage.value?.imageId, 'bc_${'1' * 32}.png');
      await c.attachImage(await tempFile(jpegBytes, 'second.jpg'));
      expect(c.uploadedImage.value?.imageId, 'bc_${'2' * 32}.png');

      c.removeImage();
      expect(c.image.value, isNull);
      expect(c.uploadedImage.value, isNull);
      await c.send();
      expect((api.last('POST /broadcasts').data as Map).containsKey('image_id'), isFalse);
    });

    test('Send waits while the picture is still uploading', () async {
      await fillValid();
      expect(c.canSend, isTrue);
      c.isImageUploading.value = true;
      expect(c.canSend, isFalse);
    });
  });

  group('models: image_url', () {
    test('admin broadcast and inbox message parse image_url; blank or missing means none', () {
      expect(Broadcast.fromJson(broadcastJson(imageUrl: 'https://api.test/uploads/x.jpg')).imageUrl, 'https://api.test/uploads/x.jpg');
      expect(Broadcast.fromJson(broadcastJson()).imageUrl, isNull);
      expect(Broadcast.fromJson(broadcastJson(imageUrl: '  ')).imageUrl, isNull);

      final json = {'id': 5, 'message': 'Hi', 'image_url': 'https://api.test/uploads/y.png', 'created_at': '2026-11-11T09:30:00.000Z'};
      final item = InboxBroadcast.fromJson(json);
      expect(item.imageUrl, 'https://api.test/uploads/y.png');
      // Marking it read keeps the picture.
      expect(item.copyWith(readAt: DateTime.utc(2026, 11, 12)).imageUrl, 'https://api.test/uploads/y.png');
      expect(InboxBroadcast.fromJson({'id': 6, 'message': 'Hi'}).imageUrl, isNull);
    });

    test('the inbox repository keeps image_url from /me/broadcasts', () async {
      api.on('GET /me/broadcasts', {
        'success': true,
        'data': [
          {'id': 7, 'message': 'With picture', 'image_url': 'https://api.test/uploads/z.webp'},
          {'id': 6, 'message': 'Text only', 'image_url': null},
        ],
        'total': 2,
        'unread_count': 2,
      });
      final page = await Get.find<BroadcastsRepository>().inbox();
      expect(page.items.map((i) => i.imageUrl), ['https://api.test/uploads/z.webp', null]);
    });
  });

  group('BroadcastImage widget', () {
    testWidgets('draws nothing without a picture', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BroadcastImage(url: null))));
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BroadcastImage(url: ''))));
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('shows the picture, and a message when it cannot load', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: BroadcastImage(url: 'https://api.test/uploads/none.png')),
      ));
      expect(find.byType(Image), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      // Tests have no network: the error builder shows instead of a red box.
      expect(find.text('Picture unavailable'), findsOneWidget);
    });
  });
}
