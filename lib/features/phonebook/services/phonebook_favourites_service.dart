import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import 'phone_number_normalizer.dart';

/// How often one student (and each of their numbers) was dialled from the
/// phonebook by the logged-in admin.
class FavouriteCallStat {
  /// [PhonebookStudent.id] of the student (e.g. `HSH-12345`).
  final String studentKey;
  final String name;
  final int totalCalls;
  final DateTime lastCalledAt;

  /// Calls per number, keyed by the normalised number (or the raw digits when
  /// the number can't be normalised).
  final Map<String, int> callsByNumber;

  /// The number as it was dialled, keyed like [callsByNumber], so the
  /// favourite tile dials it exactly the same way.
  final Map<String, String> rawByNumber;

  const FavouriteCallStat({
    required this.studentKey,
    required this.name,
    required this.totalCalls,
    required this.lastCalledAt,
    required this.callsByNumber,
    required this.rawByNumber,
  });

  /// The number dialled most often for this student. On a tie, the number
  /// that was dialled first is kept.
  String get mostDialledNumber {
    if (callsByNumber.isEmpty) return '';
    final top = callsByNumber.entries.reduce((a, b) => b.value > a.value ? b : a);
    return rawByNumber[top.key] ?? top.key;
  }

  factory FavouriteCallStat.fromJson(Map<String, dynamic> json) {
    return FavouriteCallStat(
      studentKey: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      totalCalls: (json['total'] as num?)?.toInt() ?? 0,
      lastCalledAt: DateTime.tryParse(json['last']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      callsByNumber: (json['numbers'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ) ??
          {},
      rawByNumber: (json['raw'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          {},
    );
  }

  /// One item of `GET /phonebook/favourites`.
  factory FavouriteCallStat.fromApi(Map<String, dynamic> json) {
    final numbers = <String, int>{};
    final raws = <String, String>{};
    final list = json['numbers'];
    if (list is List) {
      for (final n in list.whereType<Map>()) {
        final phone = n['phone']?.toString() ?? '';
        final key = n['phone_normalized']?.toString() ?? phone;
        if (key.isEmpty) continue;
        numbers[key] = (n['calls'] as num?)?.toInt() ?? 0;
        raws[key] = phone.isNotEmpty ? phone : key;
      }
    }
    return FavouriteCallStat(
      studentKey: json['student_key']?.toString() ?? '',
      name: json['student_name']?.toString() ?? '',
      totalCalls: (json['total_calls'] as num?)?.toInt() ?? 0,
      lastCalledAt: DateTime.tryParse(json['last_called_at']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      callsByNumber: numbers,
      rawByNumber: raws,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': studentKey,
        'name': name,
        'total': totalCalls,
        'last': lastCalledAt.toIso8601String(),
        'numbers': callsByNumber,
        'raw': rawByNumber,
      };
}

/// Keeps the per-student call counts that drive the phonebook's automatic
/// Favourites section, synced through the backend so they follow the admin
/// to every phone they log in on.
///
/// The server is the source of truth. Counts are also kept on the device so
/// the strip updates instantly and still works offline (or before the
/// backend endpoints exist): calls and removals that fail to reach the server
/// are queued and sent on the next refresh. Every call carries a
/// `client_call_id`, so a retried upload is never counted twice.
///
/// Endpoints: `POST /phonebook/calls`, `GET /phonebook/favourites`,
/// `DELETE /phonebook/favourites/:studentKey` (see docs/PHONEBOOK_DOCS.md).
class PhonebookFavouritesService {
  PhonebookFavouritesService._();
  static final PhonebookFavouritesService instance = PhonebookFavouritesService._();

  static const _prefsKey = 'phonebook_call_stats_v1';
  static const _pendingKey = 'phonebook_call_stats_pending_v1';

  /// A student shows up in Favourites once dialled at least this many times.
  static const int minCallsForFavourite = 2;

  /// At most this many favourites are shown.
  static const int maxFavourites = 10;

  /// Oldest queued operations are dropped beyond this.
  static const int _maxPending = 500;

  Map<String, FavouriteCallStat>? _cache;
  List<Map<String, dynamic>>? _pending;
  Future<bool>? _flushing;
  final _random = Random();

  Dio? get _dio =>
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>().dio : null;

  // --- local storage ---

  Future<Map<String, FavouriteCallStat>> _load() async {
    if (_cache != null) return _cache!;
    final result = <String, FavouriteCallStat>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is Map) {
              final stat = FavouriteCallStat.fromJson(
                Map<String, dynamic>.from(entry.value as Map),
              );
              if (stat.studentKey.isNotEmpty) result[stat.studentKey] = stat;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PhonebookFavourites] load failed: $e');
    }
    return _cache = result;
  }

  Future<void> _save() async {
    final data = _cache;
    if (data == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(data.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (e) {
      debugPrint('[PhonebookFavourites] save failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadPending() async {
    if (_pending != null) return _pending!;
    final result = <Map<String, dynamic>>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          result.addAll(decoded.whereType<Map>().map(Map<String, dynamic>.from));
        }
      }
    } catch (e) {
      debugPrint('[PhonebookFavourites] load pending failed: $e');
    }
    return _pending = result;
  }

  Future<void> _savePending() async {
    final ops = _pending;
    if (ops == null) return;
    if (ops.length > _maxPending) ops.removeRange(0, ops.length - _maxPending);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingKey, jsonEncode(ops));
    } catch (e) {
      debugPrint('[PhonebookFavourites] save pending failed: $e');
    }
  }

  String _newCallId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = List.generate(8, (_) => _random.nextInt(36).toRadixString(36)).join();
    return '$now-$rand';
  }

  // --- server sync ---

  /// Sends queued calls/removals in order. True when the queue is empty.
  ///
  /// Flushes run one after another: a caller always gets a flush that started
  /// after its own changes were queued, never the result of an older one.
  Future<bool> _flushPending() {
    final previous = _flushing ?? Future.value(true);
    final next = previous.then((_) => _doFlush(), onError: (_) => _doFlush());
    _flushing = next;
    return next;
  }

  Future<bool> _doFlush() async {
    final dio = _dio;
    if (dio == null) return false;
    final ops = await _loadPending();
    try {
      while (ops.isNotEmpty) {
        // [remove] may edit the queue while a request is in flight, so sent
        // ops are dropped by identity, never by position.
        final op = ops.first;
        if (op['type'] == 'remove') {
          final key = op['student_key'].toString();
          try {
            await dio.delete('/phonebook/favourites/${Uri.encodeComponent(key)}');
          } on DioException catch (e) {
            // Nothing to remove on the server is fine.
            if (e.response?.statusCode != 404) rethrow;
          }
          ops.removeWhere((o) => identical(o, op));
        } else {
          final sent = ops.takeWhile((o) => o['type'] == 'call').take(100).toList();
          await dio.post('/phonebook/calls', data: {
            'calls': sent.map((o) => Map<String, dynamic>.from(o)..remove('type')).toList(),
          });
          ops.removeWhere((o) => sent.any((s) => identical(s, o)));
        }
        await _savePending();
      }
      return true;
    } catch (e) {
      debugPrint('[PhonebookFavourites] sync pending failed: $e');
      await _savePending();
      return false;
    }
  }

  // --- public API ---

  /// Counts one call to [phone] for the student identified by [studentKey].
  Future<void> recordCall({
    required String studentKey,
    required String name,
    required String phone,
  }) async {
    if (studentKey.isEmpty || phone.trim().isEmpty) return;
    final data = await _load();
    final normalized = PhoneNumberNormalizer.normalize(phone);
    final numberKey = normalized ?? phone.replaceAll(RegExp(r'[^\d+]'), '');
    final calledAt = DateTime.now();

    final old = data[studentKey];
    final numbers = Map<String, int>.from(old?.callsByNumber ?? const {});
    final raws = Map<String, String>.from(old?.rawByNumber ?? const {});
    numbers[numberKey] = (numbers[numberKey] ?? 0) + 1;
    raws[numberKey] = phone.trim();
    data[studentKey] = FavouriteCallStat(
      studentKey: studentKey,
      name: name,
      totalCalls: (old?.totalCalls ?? 0) + 1,
      lastCalledAt: calledAt,
      callsByNumber: numbers,
      rawByNumber: raws,
    );
    await _save();

    final ops = await _loadPending();
    ops.add({
      'type': 'call',
      'client_call_id': _newCallId(),
      'student_key': studentKey,
      'student_name': name,
      'phone': phone.trim(),
      'phone_normalized': numberKey,
      'called_at': calledAt.toUtc().toIso8601String(),
    });
    await _savePending();
    unawaited(_flushPending());
  }

  /// The most-dialled students, highest count first (latest call breaks ties).
  /// Comes from the server when it can be reached, otherwise from this device.
  Future<List<FavouriteCallStat>> topFavourites() async {
    final dio = _dio;
    if (dio != null && await _flushPending()) {
      try {
        final res = await dio.get(
          '/phonebook/favourites',
          queryParameters: {
            'limit': maxFavourites,
            'min_calls': minCallsForFavourite,
          },
        );
        final body = res.data;
        final list = body is Map ? body['data'] : body;
        if (list is List) {
          final server = list
              .whereType<Map>()
              .map((e) => FavouriteCallStat.fromApi(Map<String, dynamic>.from(e)))
              .where((s) => s.studentKey.isNotEmpty)
              .toList();
          _cache = {for (final s in server) s.studentKey: s};
          await _save();
          return server;
        }
      } catch (e) {
        debugPrint('[PhonebookFavourites] fetch favourites failed: $e');
      }
    }
    return _localTop(await _load());
  }

  static List<FavouriteCallStat> _localTop(Map<String, FavouriteCallStat> data) {
    final list = data.values
        .where((s) => s.totalCalls >= minCallsForFavourite)
        .toList()
      ..sort((a, b) {
        final byCount = b.totalCalls.compareTo(a.totalCalls);
        return byCount != 0 ? byCount : b.lastCalledAt.compareTo(a.lastCalledAt);
      });
    return list.take(maxFavourites).toList();
  }

  /// Removes a student from Favourites by clearing their call count, on this
  /// device and on the server. Dialling them again starts counting from zero.
  Future<void> remove(String studentKey) async {
    final data = await _load();
    if (data.remove(studentKey) != null) await _save();
    final ops = await _loadPending();
    // Calls still waiting to upload for this student are cleared too.
    ops.removeWhere((op) => op['type'] == 'call' && op['student_key'] == studentKey);
    ops.add({'type': 'remove', 'student_key': studentKey});
    await _savePending();
    unawaited(_flushPending());
  }

  /// Drops the in-memory copies so a test starts from SharedPreferences.
  @visibleForTesting
  void resetForTest() {
    _cache = null;
    _pending = null;
    _flushing = null;
  }

  /// Forgets everything stored on this device (call on logout so the next
  /// admin on this phone doesn't see these favourites).
  Future<void> clearLocal() async {
    _cache = {};
    _pending = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      await prefs.remove(_pendingKey);
    } catch (_) {}
  }
}
