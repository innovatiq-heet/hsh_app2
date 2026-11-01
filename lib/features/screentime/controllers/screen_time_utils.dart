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

bool isStudentTampered(dynamic s) {
  final c = complianceOf(s);
  if (c == null || c.isEmpty) return false;
  final locPerm = (c['locationPermission'] ?? '').toString().toLowerCase();
  final locDisabled = locPerm == 'denied' || locPerm == 'foreground';
  final locServicesOff = c['locationEnabled'] == false;
  return c['usageAccess'] == false ||
      c['accessibilityEnabled'] == false ||
      locDisabled ||
      locServicesOff;
}

bool isStudentLocked(dynamic s) {
  if (s is! Map) return false;
  final pol = s['policy'] is Map ? s['policy'] as Map : s;
  return pol['is_locked'] == true || pol['isLocked'] == true ||
      pol['is_locked'] == 1;
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

/// The API may send minutes as int, double or string.
int toInt(dynamic value) {
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round() ?? 0;
  return 0;
}
