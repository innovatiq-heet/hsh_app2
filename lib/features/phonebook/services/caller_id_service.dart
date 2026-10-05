import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'phone_number_normalizer.dart';
import 'phonebook_database_service.dart';

/// Where caller ID stands on this device.
class CallerIdStatus {
  /// Android 10+ or iOS — older Android can't screen calls without call-log access.
  final bool supported;

  /// Android: we hold the Call Screening role. iOS: the Call Directory
  /// extension is switched on in Settings → Phone.
  final bool enabled;

  /// Android only: "Display over other apps" granted (needed for the popup;
  /// without it we still post a notification).
  final bool overlayGranted;

  /// Warden turned the feature on in-app (cleared on logout).
  final bool active;

  /// iOS only: `enabled` / `disabled` / `unknown` (user hasn't decided yet).
  final String iosState;

  const CallerIdStatus({
    this.supported = false,
    this.enabled = false,
    this.overlayGranted = false,
    this.active = false,
    this.iosState = 'unknown',
  });

  bool get isWorking => supported && enabled && active;

  factory CallerIdStatus.fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return const CallerIdStatus();
    return CallerIdStatus(
      supported: m['supported'] == true,
      enabled: m['enabled'] == true,
      overlayGranted: m['overlayGranted'] == true,
      active: m['active'] == true,
      iosState: (m['iosState'] ?? 'unknown').toString(),
    );
  }
}

/// Truecaller-style caller ID for wardens, backed by the phonebook cache.
///
/// * **Android** — a `CallScreeningService` looks the number up in the
///   SQLite cache the moment a call arrives and shows an overlay card plus a
///   notification. Nothing to export; the native side reads the same DB file.
/// * **iOS** — the OS never shows us the number. Instead we push the whole
///   directory (`E.164 → label`) into a CallKit Call Directory extension via
///   the shared App Group, and iOS prints the label on the call screen.
class CallerIdService {
  CallerIdService._();

  static const _channel = MethodChannel('hsh/caller_id');
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  static Future<CallerIdStatus> status() async {
    if (!isSupported) return const CallerIdStatus();
    try {
      return CallerIdStatus.fromMap(await _channel.invokeMapMethod<String, dynamic>('getStatus'));
    } catch (e) {
      developer.log('getStatus failed: $e', name: 'CallerId');
      return const CallerIdStatus();
    }
  }

  /// Android: shows the system "use HSH App for caller ID?" sheet.
  /// iOS: opens Settings → Phone → Call Blocking & Identification.
  static Future<bool> requestEnable() => _bool('requestEnable');

  /// Android only: opens the "Display over other apps" page.
  static Future<bool> requestOverlay() => _bool('requestOverlay');

  /// Warden-level switch, persisted natively so the screening service can
  /// check it without Flutter running. Cleared on logout.
  static Future<void> setActive(bool active) => _invoke('setActive', {'active': active});

  /// Opened from a caller-ID popup/notification? Returns `{studentId, query}`
  /// once, then forgets it.
  static Future<Map<String, dynamic>?> consumeLaunchTarget() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMapMethod<String, dynamic>('consumeLaunchTarget');
    } catch (_) {
      return null;
    }
  }

  /// Rebuilds the CallKit directory from the phonebook cache (iOS). Call after
  /// every phonebook sync. A no-op on Android, where lookups are live.
  static Future<void> syncDirectory() async {
    if (!Platform.isIOS) return;
    try {
      final entries = await buildDirectoryEntries();
      await _channel.invokeMethod<void>('exportDirectory', {
        'entries': entries.map((e) => [e.number, e.label]).toList(),
      });
    } catch (e) {
      developer.log('exportDirectory failed: $e', name: 'CallerId');
    }
  }

  /// `E.164 → label`, deduplicated and sorted ascending — CallKit rejects the
  /// whole batch if a number repeats or the order is wrong. A number shared by
  /// siblings (same father) becomes one entry naming both students.
  static Future<List<DirectoryEntry>> buildDirectoryEntries() async {
    final rows = await PhonebookDatabaseService.instance.callerIdRows();
    final byNumber = <int, _Agg>{};
    for (final r in rows) {
      final e164 = PhoneNumberNormalizer.toE164Int(r['phone_normalized']?.toString() ?? r['phone']?.toString());
      if (e164 == null) continue;
      final agg = byNumber.putIfAbsent(e164, _Agg.new);
      agg.names.add(_firstName((r['name'] ?? '').toString()));
      agg.relations.add(relationLabel((r['phone_label'] ?? '').toString()));
      final place = (r['department'] ?? '').toString().trim();
      if (place.isNotEmpty) agg.places.add(place);
    }

    final entries = byNumber.entries.map((e) {
      final a = e.value;
      final names = a.names.where((n) => n.isNotEmpty).toList();
      final relation = a.relations.length == 1 ? a.relations.first : 'Family';
      final who = names.length == 1
          ? names.first
          : names.length == 2
              ? '${names[0]} & ${names[1]}'
              : '${names.first} +${names.length - 1}';
      final place = a.places.length == 1 ? _formatPlace(a.places.first) : '';
      
      final parts = <String>[
        who,
        if (place.isNotEmpty) place,
        if (relation != 'Student') relation,
      ];
      final label = parts.join(' · ');
      return DirectoryEntry(e.key, label.length > 60 ? '${label.substring(0, 57)}…' : label);
    }).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return entries;
  }

  static String _formatPlace(String rawPlace) {
    if (rawPlace.isEmpty || rawPlace == 'HSH Resident') return '';
    final roomMatch = RegExp(r'Room\s*([A-Za-z0-9_-]+)', caseSensitive: false).firstMatch(rawPlace);
    if (roomMatch != null) {
      final roomNum = roomMatch.group(1)!;
      final groupOnly = rawPlace.replaceAll(RegExp(r'[•·-]?\s*Room\s*[A-Za-z0-9_-]+', caseSensitive: false), '').trim();
      if (groupOnly.isNotEmpty && groupOnly != 'HSH Resident') {
        return 'Rm $roomNum ($groupOnly)';
      }
      return 'Rm $roomNum';
    }
    return rawPlace;
  }

  /// `Student Mobile` → `Student`, `Father Contact` → `Father`, …
  static String relationLabel(String phoneLabel) {
    final l = phoneLabel.toLowerCase();
    if (l.contains('father')) return 'Father';
    if (l.contains('mother')) return 'Mother';
    if (l.contains('whatsapp')) return 'WhatsApp';
    if (l.contains('guardian') || l.contains('parent')) return 'Guardian';
    return 'Student';
  }

  static String _firstName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    // "Rohan Sharma" → "Rohan Sharma" but "Rohan Kumar Sharma" → "Rohan Sharma" to keep labels short.
    if (parts.length <= 2) return parts.join(' ');
    return '${parts.first} ${parts.last}';
  }

  static Future<bool> _bool(String method) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (e) {
      developer.log('$method failed: $e', name: 'CallerId');
      return false;
    }
  }

  static Future<void> _invoke(String method, [Object? args]) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (e) {
      developer.log('$method failed: $e', name: 'CallerId');
    }
  }
}

class DirectoryEntry {
  final int number;
  final String label;
  const DirectoryEntry(this.number, this.label);
}

class _Agg {
  final names = <String>{};
  final relations = <String>{};
  final places = <String>{};
}
