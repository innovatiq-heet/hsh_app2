/// The warden-configured rules a student's phone enforces.
///
/// One parser for every place the backend hands us a policy (`/policies/:id`,
/// `/policies/me`, the `policy` echo inside `/live`), accepting both the
/// snake_case and camelCase spellings the API currently emits.
class ScreenTimePolicy {
  final bool isLocked;
  final Set<String> blockedPackages;

  /// 0 = no limit.
  final int dailyLimitMinutes;

  /// "HH:mm" local time; both empty = no curfew.
  final String bedtimeStart;
  final String bedtimeEnd;

  /// Backend `updatedAt`/version marker, echoed by devices in their compliance report.
  final String version;

  /// Per-app daily limit in minutes (0 = no limit).
  final Map<String, int> appLimits;

  const ScreenTimePolicy({
    this.isLocked = false,
    this.blockedPackages = const {},
    this.dailyLimitMinutes = 0,
    this.bedtimeStart = '',
    this.bedtimeEnd = '',
    this.version = '',
    this.appLimits = const {},
  });

  bool get hasBedtime => bedtimeStart.isNotEmpty && bedtimeEnd.isNotEmpty;

  /// Parses a response body. Returns null when no policy field is present at
  /// all, so callers can keep their current value instead of resetting it.
  static ScreenTimePolicy? tryParse(dynamic raw, {ScreenTimePolicy? current}) {
    if (raw is! Map) return null;
    final data = raw['data'] is Map ? raw['data'] as Map : raw;
    final pol = data['policy'] is Map ? data['policy'] as Map : data;

    final appsRaw = _pick(data, ['apps']) ?? _pick(pol, ['apps']) ?? _pick(raw, ['apps']);
    final appLimitsRaw = _pick(data, ['appLimits', 'app_limits']) ??
        _pick(pol, ['appLimits', 'app_limits']) ??
        _pick(raw, ['appLimits', 'app_limits']);

    final blocked = _pick(data, ['blockedPackages', 'blocked_packages']) ??
        _pick(pol, ['blockedPackages', 'blocked_packages']) ??
        (appsRaw is List
            ? appsRaw
                .whereType<Map>()
                .where((a) => _toBool(a['is_blocked'] ?? a['isBlocked']) == true)
                .map((a) => (a['package_name'] ?? a['packageName'] ?? '').toString())
                .where((pkg) => pkg.isNotEmpty)
                .toList()
            : null);

    final locked = _pick(pol, ['is_locked', 'isLocked']) ?? _pick(data, ['is_locked', 'isLocked']);
    final limit = _pick(pol, ['daily_limit_minutes', 'dailyLimitMinutes']);
    final start = _pick(pol, ['bedtime_start', 'bedtimeStart']);
    final end = _pick(pol, ['bedtime_end', 'bedtimeEnd']);
    final version = _pick(pol, ['updatedAt', 'updated_at', 'version', 'policyVersion', 'policy_version']);
    // The backend sends `bedtime_start: null` when the curfew is off; that must
    // clear it, not fall back to a previous/default value.
    final hasBedtime = _hasAny(pol, ['bedtime_start', 'bedtimeStart', 'bedtime_end', 'bedtimeEnd']);

    Map<String, int>? parsedAppLimits;
    if (appsRaw is List) {
      parsedAppLimits = {};
      for (final a in appsRaw) {
        if (a is Map) {
          final pkg = (a['package_name'] ?? a['packageName'] ?? '').toString().trim();
          final appLimit = _toInt(a['daily_limit_minutes'] ?? a['dailyLimitMinutes']);
          if (pkg.isNotEmpty && appLimit != null && appLimit > 0) {
            parsedAppLimits[pkg] = appLimit;
          }
        }
      }
    } else if (appLimitsRaw is Map) {
      parsedAppLimits = {};
      for (final entry in appLimitsRaw.entries) {
        final pkg = entry.key.toString().trim();
        final appLimit = _toInt(entry.value);
        if (pkg.isNotEmpty && appLimit != null && appLimit > 0) {
          parsedAppLimits[pkg] = appLimit;
        }
      }
    }

    if (blocked == null && locked == null && limit == null && !hasBedtime && parsedAppLimits == null) {
      return null;
    }

    final base = current ?? const ScreenTimePolicy();
    final bedtimeOff = hasBedtime && (start == null || end == null);
    return ScreenTimePolicy(
      isLocked: _toBool(locked) ?? base.isLocked,
      blockedPackages: blocked is List
          ? blocked.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet()
          : base.blockedPackages,
      dailyLimitMinutes: _toInt(limit) ?? base.dailyLimitMinutes,
      bedtimeStart: bedtimeOff ? '' : (start == null ? base.bedtimeStart : _hhmm(start)),
      bedtimeEnd: bedtimeOff ? '' : (end == null ? base.bedtimeEnd : _hhmm(end)),
      version: version?.toString() ?? base.version,
      appLimits: parsedAppLimits ?? base.appLimits,
    );
  }

  /// MySQL `TIME` comes back as `23:00:00`; the app and the phone use `HH:mm`.
  static String _hhmm(dynamic v) {
    final s = v.toString().trim();
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
    return m == null ? s : '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
  }

  static bool _hasAny(Map m, List<String> keys) => keys.any(m.containsKey);

  /// Strict variant for payloads known to be a policy (e.g. the native side).
  factory ScreenTimePolicy.fromJson(Map<dynamic, dynamic> json) =>
      tryParse(json) ?? const ScreenTimePolicy();

  ScreenTimePolicy copyWith({
    bool? isLocked,
    Set<String>? blockedPackages,
    int? dailyLimitMinutes,
    String? bedtimeStart,
    String? bedtimeEnd,
    String? version,
    Map<String, int>? appLimits,
  }) =>
      ScreenTimePolicy(
        isLocked: isLocked ?? this.isLocked,
        blockedPackages: blockedPackages ?? this.blockedPackages,
        dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
        bedtimeStart: bedtimeStart ?? this.bedtimeStart,
        bedtimeEnd: bedtimeEnd ?? this.bedtimeEnd,
        version: version ?? this.version,
        appLimits: appLimits ?? this.appLimits,
      );

  /// Body for `PUT /screen-time/policies/:id`.
  Map<String, dynamic> toJson() => {
        'is_locked': isLocked,
        'blockedPackages': blockedPackages.toList(),
        'daily_limit_minutes': dailyLimitMinutes,
        'bedtime_start': bedtimeStart,
        'bedtime_end': bedtimeEnd,
        'app_limits': appLimits,
      };

  static dynamic _pick(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k];
    }
    return null;
  }

  static bool? _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v is num) return v.round();
    if (v is String) return num.tryParse(v)?.round();
    return null;
  }
}
