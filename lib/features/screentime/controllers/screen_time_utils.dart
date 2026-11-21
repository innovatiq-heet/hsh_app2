import 'dart:convert';
import '../../../core/utils/date_formatting.dart';
import '../services/app_icon_cache.dart';

// Read-only helpers shared by the directory and the per-student Screen Time
// controllers and by the widgets: reading the raw API maps (online, locked,
// blocked apps ...), minutes formatting, date and app-list normalisation.

bool toBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final s = value.trim().toLowerCase();
    return s == '1' || s == 'true';
  }
  return false;
}

bool isStudentOnline(dynamic s) {
  if (s is! Map) return false;
  final onlineVal = s['isOnline'] ?? s['is_online'] ?? s['online'];
  if (onlineVal != null) {
    return toBool(onlineVal);
  }
  final lastSeen = lastSeenOf(s);
  if (lastSeen != null) {
    return DateTime
        .now()
        .difference(lastSeen)
        .inMinutes <= 10;
  }
  return false;
}

bool isStudentOffline(dynamic s) => !isStudentOnline(s);

/// Returns true only if the student has an allocated hostel room (excludes Room N/A, alumni, day scholars).
bool hasValidRoom(dynamic s) {
  if (s is! Map) return false;
  final raw = (s['room'] ?? s['room_number'] ?? s['roomNumber'] ?? '').toString().trim();
  if (raw.isEmpty) return false;
  final lower = raw.toLowerCase();
  if (lower == 'n/a' ||
      lower == 'na' ||
      lower.contains('n/a') ||
      lower == 'none' ||
      lower == 'null' ||
      lower == 'alumni' ||
      lower == 'day scholar' ||
      lower == 'dayscholar' ||
      lower == 'unallocated' ||
      lower == '0' ||
      lower == '-') {
    return false;
  }
  return true;
}

bool isStudentScreenOn(dynamic s) {
  if (s is! Map) return false;
  final screenVal = s['isScreenOn'] ?? s['is_screen_on'] ?? s['screenOn'] ??
      s['screen_on'];
  return toBool(screenVal);
}

// ---------- Student-row helpers (directory entries are raw API maps) ----------

Map<String, dynamic>? complianceOf(dynamic s) =>
    s is Map && s['compliance'] is Map ? Map<String, dynamic>.from(
        s['compliance']) : null;

/// Whether a phone's compliance report says nothing can block apps. Current
/// builds send `appBlockerActive`, which is also true when the phone blocks
/// from usage events with Accessibility off. Older builds only send
/// `accessibilityEnabled`.
bool isAppBlockerOff(Map<String, dynamic> c) => c.containsKey('appBlockerActive')
    ? c['appBlockerActive'] == false
    : c['accessibilityEnabled'] == false;

bool isStudentTampered(dynamic s) {
  final c = complianceOf(s);
  if (c == null || c.isEmpty) return false;
  final locPerm = (c['locationPermission'] ?? '').toString().toLowerCase();
  final locDisabled = locPerm == 'denied' || locPerm == 'foreground';
  final locServicesOff = c['locationEnabled'] == false;
  return c['usageAccess'] == false ||
      isAppBlockerOff(c) ||
      locDisabled ||
      locServicesOff;
}

bool isStudentLocked(dynamic s) {
  if (s is! Map) return false;
  final id = (s['id'] ?? s['studentId'] ?? s['student_id'] ?? '').toString().trim();
  // Unenrolled students or rows without a numeric student id cannot be locked
  if (id.isEmpty || !isStudentId(id)) return false;

  final pol = s['policy'] is Map ? s['policy'] as Map : null;
  final lockedVal = pol?['is_locked'] ??
      pol?['isLocked'] ??
      pol?['locked'] ??
      s['is_locked'] ??
      s['isLocked'] ??
      s['locked'];
  return toBool(lockedVal);
}

bool isStudentLowBattery(dynamic s) {
  if (s is! Map) return false;
  final rawBattery = s['batteryLevel'] ??
      s['battery_level'] ??
      s['battery'] ??
      (s['compliance'] is Map
          ? (s['compliance']['batteryLevel'] ?? s['compliance']['battery_level'])
          : null);
  if (rawBattery == null) return false;
  final b = toInt(rawBattery);
  if (b < 0 || b > 15) return false;
  final isCharging = toBool(
      s['isCharging'] ??
      s['is_charging'] ??
      (s['compliance'] is Map
          ? (s['compliance']['isCharging'] ?? s['compliance']['is_charging'])
          : false));
  return !isCharging;
}

bool isStudentDisconnected(dynamic s) {
  if (s is! Map) return false;
  if (isStudentOnline(s)) return false;
  if (s['isDisconnected'] == true || s['is_disconnected'] == true) return true;
  final lastSeen = lastSeenOf(s);
  if (lastSeen == null) return true;
  return DateTime.now().difference(lastSeen).inMinutes >= 15;
}

bool isStudentExtendedOffline(dynamic s) {
  if (s is! Map) return false;
  if (isStudentOnline(s)) return false;
  final lastSeen = lastSeenOf(s);
  if (lastSeen == null) return true;
  return DateTime.now().difference(lastSeen).inHours >= 12;
}

bool isStudentNeedsAttention(dynamic s) {
  return isStudentTampered(s) ||
      isStudentLocked(s) ||
      isStudentLowBattery(s) ||
      isStudentDisconnected(s) ||
      isStudentExtendedOffline(s);
}

List<String> blockedOf(dynamic s) {
  if (s is! Map) return const [];
  final pol = s['policy'] is Map ? s['policy'] as Map : const {};
  final raw = s['blockedPackages'] ?? s['blocked_packages'] ??
      pol['blockedPackages'] ?? pol['blocked_packages'];
  return raw is List ? raw.map((e) => e.toString()).toList() : const [];
}

bool isStudentRestricted(dynamic s) => blockedOf(s).isNotEmpty;

DateTime? lastSeenOf(dynamic s) {
  if (s is! Map) return null;
  final raw = s['lastSeenAt'] ?? s['lastSeen'] ?? s['last_seen'] ??
      s['lastPing'] ?? s['last_ping'] ?? s['updatedAt'];
  if (raw == null) return null;
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(
        raw > 1e12 ? raw.toInt() : raw.toInt() * 1000);
  }
  return DateTime.tryParse(raw.toString())?.toLocal();
}

/// "just now", "4 min ago", "3 h ago", "2 d ago".
String relativeTime(DateTime t) => DateFormatting.relativeTime(t);

String formatMinutes(int mins) {
  final h = mins ~/ 60;
  final m = mins % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Standardizes any date representation (DateTime, numeric epoch ms/s, or string)
/// into 'yyyy-MM-dd'.
String extractRecordDate(dynamic r) {
  if (r == null) return '';
  if (r is DateTime) {
    return '${r.year.toString().padLeft(4, '0')}-${r.month.toString().padLeft(2, '0')}-${r.day.toString().padLeft(2, '0')}';
  }
  if (r is! Map) {
    return normalizeDateString(r.toString());
  }
  final raw = r['date'] ??
      r['day'] ??
      r['usage_date'] ??
      r['usageDate'] ??
      r['created_at'] ??
      r['createdAt'] ??
      r['record_date'] ??
      r['recordDate'] ??
      r['timestamp'];
  if (raw == null) return '';
  if (raw is DateTime) {
    return '${raw.year.toString().padLeft(4, '0')}-${raw.month.toString().padLeft(2, '0')}-${raw.day.toString().padLeft(2, '0')}';
  }
  if (raw is num) {
    final ms = raw > 1e12 ? raw.toInt() : raw.toInt() * 1000;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
  return normalizeDateString(raw.toString());
}

String normalizeDateString(String s) {
  final trimmed = s.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.contains('T') || trimmed.contains('Z') || trimmed.contains(':')) {
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final dt = parsed.toLocal();
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
  }
  final reg = RegExp(r'^(\d{4}-\d{2}-\d{2})');
  final match = reg.firstMatch(trimmed);
  if (match != null) {
    return match.group(1)!;
  }
  final parsed = DateTime.tryParse(trimmed);
  if (parsed != null) {
    final dt = parsed.toLocal();
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
  return trimmed.split('T').first.split(' ').first.trim();
}

/// Categorizes applications into student focus groups
String categorizeApp(String pkg, String name) {
  final p = pkg.toLowerCase();
  final n = name.toLowerCase();
  if (p.contains('instagram') ||
      p.contains('snapchat') ||
      p.contains('facebook') ||
      p.contains('whatsapp') ||
      p.contains('telegram') ||
      p.contains('discord') ||
      p.contains('reddit') ||
      p.contains('twitter') ||
      p.contains('musically') ||
      p.contains('tiktok') ||
      n.contains('insta') ||
      n.contains('chat') ||
      n.contains('social')) {
    return 'Social Media';
  }
  if (p.contains('youtube') ||
      p.contains('netflix') ||
      p.contains('videolan') ||
      p.contains('vlc') ||
      p.contains('spotify') ||
      p.contains('hotstar') ||
      p.contains('primevideo') ||
      n.contains('video') ||
      n.contains('movie') ||
      n.contains('music')) {
    return 'Entertainment';
  }
  if (p.contains('pubg') ||
      p.contains('freefire') ||
      p.contains('dts') ||
      p.contains('game') ||
      p.contains('supercell') ||
      p.contains('roblox') ||
      p.contains('candycrush') ||
      n.contains('game') ||
      n.contains('battle') ||
      n.contains('fire')) {
    return 'Gaming';
  }
  if (p.contains('chrome') ||
      p.contains('classroom') ||
      p.contains('docs') ||
      p.contains('drive') ||
      p.contains('pdf') ||
      p.contains('calculator') ||
      p.contains('notes') ||
      p.contains('wiki') ||
      n.contains('study') ||
      n.contains('class') ||
      n.contains('learn')) {
    return 'Study & Tools';
  }
  return 'Other';
}

final _studentIdPattern = RegExp(r'^[1-9]\d*$');

bool isStudentId(String value) => _studentIdPattern.hasMatch(value);

/// Extracts application usage breakdown from diverse backend payload shapes.
/// Handles JSON text strings, arrays, and alternate column naming.
List<dynamic> extractAppsListStatic(dynamic source) {
  if (source == null) return [];
  if (source is String) {
    final trimmed = source.trim();
    if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
        (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
      try {
        final decoded = jsonDecode(trimmed);
        return extractAppsListStatic(decoded);
      } catch (_) {}
    }
    return [];
  }
  if (source is List) {
    if (source.isNotEmpty) {
      AppIconCache.ingest(source);
    }
    return source;
  }
  if (source is Map) {
    final candidates = [
      source['appUsageBreakdown'],
      source['app_usage_breakdown'],
      source['app_usage'],
      source['appUsage'],
      source['apps'],
      source['appBreakdown'],
      source['app_breakdown'],
      source['usageBreakdown'],
      source['usage_breakdown'],
      source['usage_logs'],
      source['usageLogs'],
      source['app_usage_logs'],
      source['appUsageLogs'],
      source['logs'],
      source['screenTime']?['appUsageBreakdown'],
      source['today']?['appUsageBreakdown'],
      source['liveStatus']?['appUsageBreakdown'],
      source['student']?['appUsageBreakdown'],
      source['breakdown'],
      source['data'],
      source['items'],
      source['records'],
      source['rows'],
    ];
    for (final c in candidates) {
      if (c == null) continue;
      if (c is List && c.isNotEmpty) {
        final first = c.first;
        if (first is Map &&
            (first.containsKey('package_name') ||
                first.containsKey('packageName') ||
                first.containsKey('package') ||
                first.containsKey('pkg') ||
                first.containsKey('app_name') ||
                first.containsKey('appName') ||
                first.containsKey('usage_minutes') ||
                first.containsKey('minutes'))) {
          AppIconCache.ingest(c);
          return c;
        }
        // If candidate is a direct list of maps and we didn't match specific keys, still accept if source had a breakdown key
        final isExplicitBreakdownKey = c == source['appUsageBreakdown'] ||
            c == source['app_usage_breakdown'] ||
            c == source['apps'] ||
            c == source['app_usage'] ||
            c == source['appUsage'];
        if (isExplicitBreakdownKey && first is Map) {
          AppIconCache.ingest(c);
          return c;
        }
      }
      if (c is String) {
        final trimmed = c.trim();
        if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
            (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
          try {
            final decoded = jsonDecode(trimmed);
            final extracted = extractAppsListStatic(decoded);
            if (extracted.isNotEmpty) return extracted;
          } catch (_) {}
        }
      }
    }
  }
  return [];
}

int extractAppMinutes(dynamic item) {
  if (item is! Map) return 0;
  return toInt(
    item['minutes'] ??
        item['total_minutes'] ??
        item['totalMinutes'] ??
        item['usage_minutes'] ??
        item['usageMinutes'] ??
        item['screen_time_minutes'] ??
        item['screenTimeMinutes'] ??
        item['duration'] ??
        item['time'] ??
        item['timeInMinutes'] ??
        item['usage_time'] ??
        item['time_spent'],
  );
}

int extractStudentMinutes(dynamic s) {
  if (s == null) return 0;
  if (s is num) return toInt(s);
  if (s is! Map) return toInt(s);

  // 1. Direct keys on root object
  final direct = s['totalScreenTimeMinutes'] ??
      s['total_screen_time_minutes'] ??
      s['totalMinutes'] ??
      s['total_minutes'] ??
      s['todayScreenTimeMinutes'] ??
      s['today_screen_time_minutes'] ??
      s['todayMinutes'] ??
      s['today_minutes'] ??
      s['usageMinutes'] ??
      s['usage_minutes'] ??
      s['screenTimeMinutes'] ??
      s['screen_time_minutes'] ??
      s['screenTime'] ??
      s['screen_time'] ??
      s['minutes'] ??
      s['duration'] ??
      s['time'] ??
      s['timeInMinutes'];
  if (direct != null && direct is! Map && direct is! List) {
    final m = toInt(direct);
    if (m > 0) return m;
  }

  // 2. Nested sub-objects commonly returned by backend / live endpoint
  for (final key in const [
    'screenTime',
    'screen_time',
    'today',
    'live',
    'liveStatus',
    'usage',
    'stats',
    'data',
    'student'
  ]) {
    final nested = s[key];
    if (nested is Map) {
      final m = extractStudentMinutes(nested);
      if (m > 0) return m;
    }
  }

  // 3. Fallback: sum of appUsageBreakdown
  final apps = extractAppsListStatic(s);
  if (apps.isNotEmpty) {
    int sum = 0;
    for (final app in apps) {
      sum += extractAppMinutes(app);
    }
    if (sum > 0) return sum;
  }

  return direct != null && direct is! Map && direct is! List ? toInt(direct) : 0;
}

int extractStudentNightMinutes(dynamic s) {
  if (s == null) return 0;
  if (s is num) return toInt(s);
  if (s is! Map) return toInt(s);

  final direct = s['nightScreenTimeMinutes'] ??
      s['night_screen_time_minutes'] ??
      s['nightMinutes'] ??
      s['night_minutes'] ??
      s['nightScreenTime'] ??
      s['night_screen_time'] ??
      s['nightUsageMinutes'] ??
      s['night_usage_minutes'] ??
      s['curfewMinutes'] ??
      s['curfew_minutes'] ??
      s['curfew_screen_time_minutes'];
  if (direct != null && direct is! Map && direct is! List) {
    final m = toInt(direct);
    if (m > 0) return m;
  }

  for (final key in const [
    'screenTime',
    'screen_time',
    'today',
    'live',
    'liveStatus',
    'usage',
    'stats',
    'data',
    'student'
  ]) {
    final nested = s[key];
    if (nested is Map) {
      final m = extractStudentNightMinutes(nested);
      if (m > 0) return m;
    }
  }

  return direct != null && direct is! Map && direct is! List ? toInt(direct) : 0;
}

/// The API may send minutes as int, double or string.
int toInt(dynamic value) {
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round() ?? 0;
  return 0;
}
