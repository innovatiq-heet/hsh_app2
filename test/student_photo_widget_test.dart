import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/services/student_photo_cache_service.dart';
import 'package:hsh_app2/features/shared/widgets/student_contact_card.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StudentPhotoCacheService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('student_photo_widget_test_');
    service = StudentPhotoCacheService.instance;
    service.resetForTesting();
  });

  tearDown(() {
    service.resetForTesting();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets('StudentPhoto displays fallback letter when photo is not cached and not found',
      (tester) async {
    const url =
        'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com/student/personal/111122223333.jpg';

    final marker = File(p.join(tempDir.path, '111122223333.jpg.missing'));
    marker.writeAsStringSync('missing', flush: true);

    await tester.runAsync(() async {
      await service.init(dir: tempDir);
    });

    bool fallbackTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentPhoto(
            url: url,
            name: 'Krutarth Patel',
            letter: const Text('KP'),
            onFallbackTap: () => fallbackTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('KP'), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.text('KP'));
    await tester.pump();
    expect(fallbackTapped, isTrue);
  });

  testWidgets('StudentPhoto renders Image.file when photo is cached on local disk',
      (tester) async {
    const url =
        'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com/student/personal/999988887777.jpg';

    // 1x1 transparent PNG bytes
    final dummyPngBytes = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];

    final file = File(p.join(tempDir.path, '999988887777.jpg'));
    file.writeAsBytesSync(dummyPngBytes, flush: true);

    await tester.runAsync(() async {
      await service.init(dir: tempDir);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StudentPhoto(
            url: url,
            name: 'Taksh Patel',
            letter: Text('TP'),
          ),
        ),
      ),
    );

    // Initial build synchronously finds the cached file
    expect(find.byType(Image), findsOneWidget);

    final imageWidget = tester.widget<Image>(find.byType(Image));
    expect(imageWidget.image, isA<ResizeImage>());
    final resizeImage = imageWidget.image as ResizeImage;
    expect(resizeImage.imageProvider, isA<FileImage>());
  });
}
