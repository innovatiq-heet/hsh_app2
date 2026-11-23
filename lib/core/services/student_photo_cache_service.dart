import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Local phone cache for student profile photos.
///
/// Student photos are hosted publicly on Google Cloud Storage at
/// `${AppConfig.studentPhotoBaseUrl}/<12-digit-aadhar>.jpg`.
///
/// Without local caching, Flutter's default `Image.network` issues HTTP GET
/// requests repeatedly on list scroll, widget rebuilds, and app restarts.
/// Furthermore, students without a photo answer 403 on the server, causing
/// repeated failing requests.
///
/// This service:
/// 1. Stores successfully downloaded photos on local disk (`<appSupportDir>/student_photos/`).
/// 2. Returns cached [File] immediately from disk with zero network requests.
/// 3. Remembers 403/404 ("missing photo") responses (with a disk `.missing` marker),
///    preventing repeated HTTP calls for students with no photo.
/// 4. Deduplicates concurrent in-flight download requests for the same URL.
class StudentPhotoCacheService {
  static final StudentPhotoCacheService instance = StudentPhotoCacheService._internal();

  StudentPhotoCacheService._internal() {
    _defaultDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
  }

  late final Dio _defaultDio;
  Dio? _customDio;
  Dio get _dio => _customDio ?? _defaultDio;

  Directory? _cacheDir;
  bool _initialized = false;
  Future<void>? _initFuture;

  final Set<String> _cachedFilenames = <String>{};
  final Set<String> _notFoundFilenames = <String>{};
  final Map<String, Future<File?>> _inFlightDownloads = <String, Future<File?>>{};

  /// Visible for testing: inject custom dio instance.
  @visibleForTesting
  void setDioForTesting(Dio? dio) {
    _customDio = dio;
  }

  /// Visible for testing: reset cached state.
  @visibleForTesting
  void resetForTesting({bool resetDio = false}) {
    _cachedFilenames.clear();
    _notFoundFilenames.clear();
    _inFlightDownloads.clear();
    _initialized = false;
    _initFuture = null;
    if (resetDio) {
      _customDio = null;
    }
  }

  /// Initializes the cache directory and scans existing cached photos into memory.
  Future<void> init({Directory? dir}) => _initFuture ??= _doInit(dir: dir);

  Future<void> _doInit({Directory? dir}) async {
    try {
      if (dir != null) {
        _cacheDir = dir;
      } else if (_cacheDir == null) {
        try {
          final supportDir = await getApplicationSupportDirectory()
              .timeout(const Duration(milliseconds: 500));
          _cacheDir = Directory(p.join(supportDir.path, 'student_photos'));
        } catch (_) {
          // Fallback if path_provider fails or hangs in headless / testing environment
          _cacheDir = Directory(p.join(Directory.systemTemp.path, 'hsh_student_photos'));
        }
      }

      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }

      await _syncIndex();
      _initialized = true;
    } catch (e) {
      debugPrint('[StudentPhotoCache] init error: $e');
    }
  }

  /// Scans the directory for existing image files and `.missing` markers.
  Future<void> _syncIndex() async {
    if (_cacheDir == null) return;
    try {
      final entities = _cacheDir!.listSync();
      final now = DateTime.now();

      for (final entity in entities) {
        if (entity is File) {
          final base = p.basename(entity.path);
          if (base.endsWith('.missing')) {
            final targetFilename = base.substring(0, base.length - '.missing'.length);
            // Expire negative cache markers after 7 days
            try {
              final age = now.difference(entity.lastModifiedSync()).inDays;
              if (age < 7) {
                _notFoundFilenames.add(targetFilename);
              } else {
                try {
                  entity.deleteSync();
                } catch (_) {}
              }
            } catch (_) {
              _notFoundFilenames.add(targetFilename);
            }
          } else if (_isImageFile(base)) {
            try {
              if (entity.lengthSync() > 0) {
                _cachedFilenames.add(base);
              } else {
                try {
                  entity.deleteSync();
                } catch (_) {}
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[StudentPhotoCache] _syncIndex error: $e');
    }
  }

  static bool _isImageFile(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  /// Returns a clean, safe local filename for a photo URL.
  /// E.g. `https://.../student/personal/123456789012.jpg` -> `123456789012.jpg`.
  ///
  /// Father and mother photos share the student's file name
  /// (`father/personal/123456789012.jpg`), so any folder other than `student`
  /// is kept as a prefix (`father_123456789012.jpg`); otherwise a parent would
  /// be shown the student's cached photo. Student names stay unprefixed so
  /// photos already cached on phones remain valid.
  static String filenameForUrl(String url) {
    if (url.trim().isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final last = segments.last.trim();
        // The folders say whose file it is and what it is:
        // `<who>/<kind>/<aadhar>.jpg` (kind: personal, aadhar, pan, signature).
        // Student photos keep the bare name (already cached on phones); a
        // parent's photo is `father_<aadhar>.jpg`; any other kind gets both,
        // e.g. `student_aadhar_<aadhar>.jpg`, so a document never takes the
        // place of a photo in the cache.
        String prefix = '';
        if (segments.length >= 3) {
          final who = segments[segments.length - 3].toLowerCase();
          final kind = segments[segments.length - 2].toLowerCase();
          final safe = RegExp(r'^[a-z0-9_\-]+$');
          if (safe.hasMatch(who) && safe.hasMatch(kind)) {
            if (kind == 'personal') {
              if (who != 'student') prefix = '${who}_';
            } else {
              prefix = '${who}_${kind}_';
            }
          }
        }
        if (RegExp(r'^\d{12}\.(jpg|jpeg|png)$', caseSensitive: false).hasMatch(last)) {
          return '$prefix${last.toLowerCase()}';
        }
        if (RegExp(r'^[a-zA-Z0-9_\-\.]+\.(jpg|jpeg|png|webp)$', caseSensitive: false).hasMatch(last)) {
          return '$prefix${last.toLowerCase()}';
        }
      }
    } catch (_) {}
    return 'photo_${url.hashCode.toRadixString(16)}.jpg';
  }

  /// Returns the cached photo [File] if already present on disk, or null.
  /// This check is fast and synchronous.
  File? getCachedFile(String url) {
    final filename = filenameForUrl(url);
    if (filename.isEmpty) return null;
    if (_notFoundFilenames.contains(filename)) return null;
    if (_cacheDir == null) return null;

    final targetPath = p.join(_cacheDir!.path, filename);
    if (_cachedFilenames.contains(filename)) {
      return File(targetPath);
    }

    final file = File(targetPath);
    if (file.existsSync()) {
      try {
        if (file.lengthSync() > 0) {
          _cachedFilenames.add(filename);
          return file;
        } else {
          try {
            file.deleteSync();
          } catch (_) {}
        }
      } catch (_) {}
    }
    return null;
  }

  /// Returns true if this photo URL previously returned 403/404 ("no photo on server").
  bool isMarkedMissing(String url) {
    final filename = filenameForUrl(url);
    if (filename.isEmpty) return true;
    return _notFoundFilenames.contains(filename);
  }

  /// Loads the photo for [url]. Returns the cached [File] from disk if present,
  /// or downloads and saves it to disk before returning.
  ///
  /// If the server returns 403/404, writes a `.missing` marker so future
  /// calls return null immediately without making network calls.
  Future<File?> loadPhoto(String url) async {
    if (url.trim().isEmpty) return null;

    if (!_initialized) {
      await init();
    }
    if (_cacheDir == null) return null;

    final filename = filenameForUrl(url);
    if (filename.isEmpty) return null;

    // Check fast cache
    final cached = getCachedFile(url);
    if (cached != null) return cached;

    // Known not found
    if (_notFoundFilenames.contains(filename)) return null;

    // Deduplicate in-flight requests
    if (_inFlightDownloads.containsKey(filename)) {
      return await _inFlightDownloads[filename];
    }

    final downloadFuture = _executeDownload(url, filename);
    _inFlightDownloads[filename] = downloadFuture;

    try {
      return await downloadFuture;
    } finally {
      _inFlightDownloads.remove(filename);
    }
  }

  Future<File?> _executeDownload(String url, String filename) async {
    final targetPath = p.join(_cacheDir!.path, filename);
    final tempPath = '$targetPath.tmp_${DateTime.now().microsecondsSinceEpoch}';

    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null,
        ),
      );

      final statusCode = response.statusCode ?? 0;

      if (statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(response.data!, flush: true);

        final targetFile = File(targetPath);
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await tempFile.rename(targetPath);

        _cachedFilenames.add(filename);
        _notFoundFilenames.remove(filename);

        final marker = File('$targetPath.missing');
        if (await marker.exists()) {
          try {
            await marker.delete();
          } catch (_) {}
        }

        return targetFile;
      } else if (statusCode == 403 || statusCode == 404) {
        // Photo does not exist on server (GCS returns 403 on missing objects)
        _notFoundFilenames.add(filename);
        try {
          final marker = File('$targetPath.missing');
          await marker.writeAsString(DateTime.now().toIso8601String(), flush: true);
        } catch (_) {}
        return null;
      } else {
        // Transient 5xx / other status - do not permanently mark missing
        return null;
      }
    } catch (e) {
      // Network error / offline / timeout - do not permanently mark missing
      return null;
    } finally {
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Invalidates a cached photo (or removes a missing marker), forcing the
  /// next access to re-query the network.
  Future<void> invalidate(String url) async {
    final filename = filenameForUrl(url);
    if (filename.isEmpty || _cacheDir == null) return;

    _cachedFilenames.remove(filename);
    _notFoundFilenames.remove(filename);

    final photoFile = File(p.join(_cacheDir!.path, filename));
    if (await photoFile.exists()) {
      try {
        await photoFile.delete();
      } catch (_) {}
    }

    final markerFile = File(p.join(_cacheDir!.path, '$filename.missing'));
    if (await markerFile.exists()) {
      try {
        await markerFile.delete();
      } catch (_) {}
    }
  }

  /// Clears all cached student photos and markers from the device.
  Future<void> clearCache() async {
    _cachedFilenames.clear();
    _notFoundFilenames.clear();
    _inFlightDownloads.clear();

    if (_cacheDir != null && await _cacheDir!.exists()) {
      try {
        final entities = _cacheDir!.listSync();
        for (final entity in entities) {
          try {
            entity.deleteSync(recursive: true);
          } catch (_) {}
        }
      } catch (_) {}
    }
  }
}
