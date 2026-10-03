import 'dart:convert';

import 'package:flutter/foundation.dart';

/// In-memory store of real launcher icons, keyed by package name.
///
/// Student devices upload each app's icon once (base64 PNG in the ping
/// breakdown); the backend echoes it as `icon` on breakdown entries. Any
/// response that passes through [ingest] fills this cache, so an icon seen on
/// one day's history keeps showing on every other screen. Decoded bytes are
/// shared across widgets to avoid re-decoding the same base64 per rebuild.
class AppIconCache {
  AppIconCache._();

  static final Map<String, Uint8List> _icons = {};

  /// Notifies listeners when new icons arrive so visible lists can repaint.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Uint8List? get(String packageName) => _icons[packageName];

  static bool has(String packageName) => _icons.containsKey(packageName);

  /// Pulls `icon` / `iconBase64` / `icon_base64` out of every entry in a
  /// breakdown list. Tolerates data-URI prefixes and junk values.
  static void ingest(Iterable<dynamic> entries) {
    var added = 0;
    for (final e in entries) {
      if (e is! Map) continue;
      final pkg = (e['packageName'] ?? e['package_name'] ?? '').toString();
      if (pkg.isEmpty || _icons.containsKey(pkg)) continue;
      final raw = e['icon'] ?? e['iconBase64'] ?? e['icon_base64'];
      if (raw is! String || raw.length < 32) continue;
      final bytes = _decode(raw);
      if (bytes != null) {
        _icons[pkg] = bytes;
        added++;
      }
    }
    if (added > 0) revision.value++;
  }

  static Uint8List? _decode(String raw) {
    var s = raw.trim();
    final comma = s.indexOf(',');
    if (s.startsWith('data:') && comma != -1) s = s.substring(comma + 1);
    try {
      return base64Decode(base64.normalize(s));
    } catch (_) {
      return null;
    }
  }
}
