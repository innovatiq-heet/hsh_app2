import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/services/student_photo_cache_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late StudentPhotoCacheService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('student_photo_cache_test_');
    service = StudentPhotoCacheService.instance;
    service.resetForTesting();
    await service.init(dir: tempDir);
  });

  tearDown(() async {
    service.resetForTesting();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('StudentPhotoCacheService filenameForUrl', () {
    test('extracts clean 12-digit aadhar filename', () {
      const url =
          'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com/student/personal/123456789012.jpg';
      expect(StudentPhotoCacheService.filenameForUrl(url), '123456789012.jpg');
    });

    test('normalizes uppercase extensions', () {
      const url =
          'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com/student/personal/123456789012.JPG';
      expect(StudentPhotoCacheService.filenameForUrl(url), '123456789012.jpg');
    });

    test('father and mother photos get their own file, not the student\'s', () {
      const base = 'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com';
      final names = {
        StudentPhotoCacheService.filenameForUrl('$base/student/personal/342374115218.jpg'),
        StudentPhotoCacheService.filenameForUrl('$base/father/personal/342374115218.jpg'),
        StudentPhotoCacheService.filenameForUrl('$base/mother/personal/342374115218.jpg'),
      };
      expect(names, {'342374115218.jpg', 'father_342374115218.jpg', 'mother_342374115218.jpg'});
    });

    test('documents get their own file too, never the photo file', () {
      const base = 'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com';
      expect(StudentPhotoCacheService.filenameForUrl('$base/student/aadhar/342374115218.jpg'), 'student_aadhar_342374115218.jpg');
      expect(StudentPhotoCacheService.filenameForUrl('$base/father/pan/342374115218.jpg'), 'father_pan_342374115218.jpg');
      expect(StudentPhotoCacheService.filenameForUrl('$base/mother/signature/342374115218.jpg'), 'mother_signature_342374115218.jpg');
      // Photos keep their names.
      expect(StudentPhotoCacheService.filenameForUrl('$base/student/personal/342374115218.jpg'), '342374115218.jpg');
    });

    test('handles empty or blank url', () {
      expect(StudentPhotoCacheService.filenameForUrl(''), '');
      expect(StudentPhotoCacheService.filenameForUrl('   '), '');
    });
  });

  group('StudentPhotoCacheService caching operations', () {
    test('returns null when file is not cached and not marked missing', () {
      const url =
          'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com/student/personal/111122223333.jpg';
      expect(service.getCachedFile(url), isNull);
      expect(service.isMarkedMissing(url), isFalse);
    });

    test('getCachedFile returns file synchronously once file is on disk', () async {
      const url =
          'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com/student/personal/222233334444.jpg';
      final file = File(p.join(tempDir.path, '222233334444.jpg'));
      await file.writeAsBytes([1, 2, 3, 4], flush: true);

      final cached = service.getCachedFile(url);
      expect(cached, isNotNull);
      expect(cached!.existsSync(), isTrue);
      expect(p.normalize(cached.path), p.normalize(file.path));
    });

    test('ignores and removes 0-byte corrupt files', () async {
      const url =
          'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com/student/personal/333344445555.jpg';
      final file = File(p.join(tempDir.path, '333344445555.jpg'));
      await file.writeAsBytes([], flush: true);

      final cached = service.getCachedFile(url);
      expect(cached, isNull);
      expect(file.existsSync(), isFalse);
    });

    test('loadPhoto downloads and caches photo on 200 OK', () async {
      const url =
          'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com/student/personal/444455556666.jpg';

      int httpCalls = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        httpCalls++;
        return ResponseBody(
          Stream.value(Uint8List.fromList([10, 20, 30, 40])),
          200,
          headers: {
            Headers.contentTypeHeader: ['image/jpeg'],
          },
        );
      });
      service.setDioForTesting(dio);

      // First call: makes HTTP request and caches to disk
      final file = await service.loadPhoto(url);
      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(await file.readAsBytes(), [10, 20, 30, 40]);
      expect(httpCalls, 1);

      // Second call: loads from cache, zero HTTP calls!
      final cached = service.getCachedFile(url);
      expect(cached, isNotNull);
      expect(cached!.path, file.path);

      final secondLoad = await service.loadPhoto(url);
      expect(secondLoad, isNotNull);
      expect(httpCalls, 1, reason: 'Must not make another HTTP call for cached file');
    });

    test('loadPhoto marks missing on 403 Forbidden and prevents repeated calls', () async {
      const url =
          'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com/student/personal/555566667777.jpg';

      int httpCalls = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        httpCalls++;
        return ResponseBody(
          Stream.value(Uint8List.fromList([])),
          403,
          headers: {},
        );
      });
      service.setDioForTesting(dio);

      // First call: gets 403, writes .missing marker
      final result1 = await service.loadPhoto(url);
      expect(result1, isNull);
      expect(httpCalls, 1);
      expect(service.isMarkedMissing(url), isTrue);

      final marker = File(p.join(tempDir.path, '555566667777.jpg.missing'));
      expect(marker.existsSync(), isTrue);

      // Subsequent call: returns null immediately, NO HTTP calls!
      final result2 = await service.loadPhoto(url);
      expect(result2, isNull);
      expect(httpCalls, 1, reason: 'Must not make repeat HTTP calls for known missing photo');

      // getCachedFile also returns null
      expect(service.getCachedFile(url), isNull);
    });

    test('deduplicates concurrent in-flight requests for the same URL', () async {
      const url =
          'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com/student/personal/666677778888.jpg';

      int httpCalls = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        httpCalls++;
        await Future.delayed(const Duration(milliseconds: 50));
        return ResponseBody(
          Stream.value(Uint8List.fromList([1, 2, 3])),
          200,
          headers: {},
        );
      });
      service.setDioForTesting(dio);

      // Launch 3 requests simultaneously
      final futures = [
        service.loadPhoto(url),
        service.loadPhoto(url),
        service.loadPhoto(url),
      ];

      final results = await Future.wait(futures);
      expect(httpCalls, 1, reason: 'Concurrent requests must be deduplicated to 1 HTTP call');
      expect(results[0], isNotNull);
      expect(results[1], isNotNull);
      expect(results[2], isNotNull);
    });

    test('invalidate removes cached file and allows fresh download', () async {
      const url =
          'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com/student/personal/777788889999.jpg';
      final file = File(p.join(tempDir.path, '777788889999.jpg'));
      await file.writeAsBytes([9, 9, 9], flush: true);

      expect(service.getCachedFile(url), isNotNull);

      await service.invalidate(url);

      expect(service.getCachedFile(url), isNull);
      expect(file.existsSync(), isFalse);
    });

    test('clearCache deletes all cached files from disk', () async {
      final f1 = File(p.join(tempDir.path, 'photo1.jpg'));
      final f2 = File(p.join(tempDir.path, 'photo2.jpg'));
      await f1.writeAsBytes([1]);
      await f2.writeAsBytes([2]);

      expect(f1.existsSync(), isTrue);
      expect(f2.existsSync(), isTrue);

      await service.clearCache();

      expect(f1.existsSync(), isFalse);
      expect(f2.existsSync(), isFalse);
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
