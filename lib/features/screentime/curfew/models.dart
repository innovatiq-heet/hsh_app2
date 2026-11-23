/// Data classes for the Screen Time curfew-session and dashboard APIs.
/// Field names follow the JSON (snake_case) from `/api/screen-time/...`.
library;

import 'curfew_schedule.dart';

int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
int? _intOrNull(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
bool _bool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
DateTime? _time(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
List<String> _strings(dynamic v) => v is List ? v.map((e) => '$e').toList() : const [];
List<Map<String, dynamic>> _maps(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];

// ---------------------------------------------------------------------------
// Sessions
// ---------------------------------------------------------------------------

class CurfewSession {
  CurfewSession({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.days,
    required this.scheduleText,
    required this.isActive,
    required this.studentCount,
    required this.pausedCount,
    required this.runningNow,
    this.nextStartAt,
    this.updatedAt,
    this.isPaused,
    this.isEffective,
  });

  final int id;
  final String name;
  final String startTime;
  final String endTime;
  final List<String> days;

  /// "22:00–06:00 every day"
  final String scheduleText;
  final bool isActive;
  final int studentCount;
  final int pausedCount;
  final bool runningNow;
  final DateTime? nextStartAt;
  final DateTime? updatedAt;

  /// Only on `GET /students/:id/sessions`: paused for that student / enforced on their phone.
  final bool? isPaused;
  final bool? isEffective;

  CurfewWindow get window => CurfewWindow(startTime: startTime, endTime: endTime, days: days);

  factory CurfewSession.fromJson(Map<String, dynamic> j) => CurfewSession(
        id: _int(j['id']),
        name: '${j['name']}',
        startTime: '${j['start_time']}',
        endTime: '${j['end_time']}',
        days: _strings(j['days']),
        scheduleText: j['schedule_text'] as String? ?? '${j['start_time']}–${j['end_time']} ${describeDays(_strings(j['days']))}',
        isActive: _bool(j['is_active']),
        studentCount: _int(j['student_count']),
        pausedCount: _int(j['paused_count']),
        runningNow: _bool(j['running_now']),
        nextStartAt: _time(j['next_start_at']),
        updatedAt: _time(j['updated_at']),
        isPaused: j.containsKey('is_paused') ? _bool(j['is_paused']) : null,
        isEffective: j.containsKey('is_effective') ? _bool(j['is_effective']) : null,
      );
}

/// Body for create / edit. Unset fields are left out (PATCH is partial).
class SessionDraft {
  SessionDraft({this.name, this.startTime, this.endTime, this.days, this.isActive});

  String? name;
  String? startTime;
  String? endTime;
  List<String>? days;
  bool? isActive;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (startTime != null) 'start_time': startTime,
        if (endTime != null) 'end_time': endTime,
        if (days != null) 'days': days,
        if (isActive != null) 'is_active': isActive,
      };
}

/// Which students a bulk add / remove / preview is about (union of all parts).
/// Student ids are numeric `students.id` only — never bank codes.
class StudentSelection {
  const StudentSelection({
    this.studentIds = const [],
    this.floorIds = const [],
    this.groups = const [],
    this.tagIds = const [],
    this.allActive = false,
  });

  final List<int> studentIds;
  final List<int> floorIds;
  final List<String> groups;
  final List<int> tagIds;
  final bool allActive;

  bool get isEmpty => !allActive && studentIds.isEmpty && floorIds.isEmpty && groups.isEmpty && tagIds.isEmpty;

  Map<String, dynamic> toJson() => {
        if (studentIds.isNotEmpty) 'student_ids': studentIds,
        if (floorIds.isNotEmpty) 'floor_ids': floorIds,
        if (groups.isNotEmpty) 'groups': groups,
        if (tagIds.isNotEmpty) 'tag_ids': tagIds,
        if (allActive) 'all_active': true,
      };
}

class SelectionPreview {
  SelectionPreview({
    required this.matchedCount,
    required this.alreadyAssignedCount,
    required this.toAddCount,
    required this.noDeviceCount,
    required this.invalidStudentIds,
    required this.sample,
  });

  final int matchedCount;
  final int alreadyAssignedCount;
  final int toAddCount;
  final int noDeviceCount;
  final List<int> invalidStudentIds;
  final List<StudentRef> sample;

  factory SelectionPreview.fromJson(Map<String, dynamic> j) => SelectionPreview(
        matchedCount: _int(j['matched_count']),
        alreadyAssignedCount: _int(j['already_assigned_count']),
        toAddCount: _int(j['to_add_count']),
        noDeviceCount: _int(j['no_device_count']),
        invalidStudentIds: (j['invalid_student_ids'] as List? ?? const []).map(_int).toList(),
        sample: _maps(j['sample']).map(StudentRef.fromJson).toList(),
      );
}

class StudentRef {
  StudentRef({required this.id, this.name, this.roomNumber, this.groupName, this.floorId});

  final int id;
  final String? name;
  final String? roomNumber;
  final String? groupName;
  final int? floorId;

  String get subtitle => [if (roomNumber != null) 'Room $roomNumber', ?groupName].join(' · ');

  factory StudentRef.fromJson(Map<String, dynamic> j) => StudentRef(
        id: _int(j['id']),
        name: j['name'] as String?,
        roomNumber: j['room_number']?.toString(),
        groupName: j['group_name'] as String?,
        floorId: _intOrNull(j['floor_id']),
      );
}

class SessionStudent {
  SessionStudent({required this.student, required this.isPaused, this.pausedAt, this.isResident = true});

  final StudentRef student;
  final bool isPaused;
  final DateTime? pausedAt;

  /// false = left / alumni / inactive (still assigned; remove them).
  final bool isResident;

  factory SessionStudent.fromJson(Map<String, dynamic> j) => SessionStudent(
        student: StudentRef.fromJson(j),
        isPaused: _bool(j['is_paused']),
        pausedAt: _time(j['paused_at']),
        isResident: j['is_resident'] == null || _bool(j['is_resident']),
      );
}

class SessionDetail {
  SessionDetail({required this.session, required this.students, required this.total});

  final CurfewSession session;
  final List<SessionStudent> students;
  final int total;

  factory SessionDetail.fromJson(Map<String, dynamic> j) => SessionDetail(
        session: CurfewSession.fromJson((j['session'] as Map).cast<String, dynamic>()),
        students: _maps(j['students']).map(SessionStudent.fromJson).toList(),
        total: _int(j['students_total']),
      );
}

class LiveStudent {
  LiveStudent({required this.student, this.currentApp, required this.sessionUseTodayMinutes});

  final StudentRef student;
  final String? currentApp;
  final int sessionUseTodayMinutes;

  factory LiveStudent.fromJson(Map<String, dynamic> j) => LiveStudent(
        student: StudentRef.fromJson(j),
        currentApp: j['current_app'] as String?,
        sessionUseTodayMinutes: _int(j['session_use_today_minutes']),
      );
}

class SessionLive {
  SessionLive({
    required this.session,
    required this.runningNow,
    this.endsAt,
    this.nextStartAt,
    required this.effectiveCount,
    required this.onlineCount,
    required this.offlineCount,
    required this.usingPhone,
  });

  final CurfewSession session;
  final bool runningNow;
  final DateTime? endsAt;
  final DateTime? nextStartAt;
  final int effectiveCount;
  final int onlineCount;
  final int offlineCount;
  final List<LiveStudent> usingPhone;

  factory SessionLive.fromJson(Map<String, dynamic> j) => SessionLive(
        session: CurfewSession.fromJson((j['session'] as Map).cast<String, dynamic>()),
        runningNow: _bool(j['running_now']),
        endsAt: _time(j['ends_at']),
        nextStartAt: _time(j['next_start_at']),
        effectiveCount: _int(j['effective_count']),
        onlineCount: _int(j['online_count']),
        offlineCount: _int(j['offline_count']),
        usingPhone: _maps(j['using_phone']).map(LiveStudent.fromJson).toList(),
      );
}

class SessionLogEntry {
  SessionLogEntry({required this.id, required this.action, required this.message, required this.sessionName, this.createdAt});

  final int id;

  /// created, migrated, edited, switched_on, switched_off, deleted,
  /// students_added, students_removed, student_paused, student_resumed
  final String action;

  /// Ready to show: "Manual Operator switched Night Curfew off".
  final String message;
  final String sessionName;
  final DateTime? createdAt;

  factory SessionLogEntry.fromJson(Map<String, dynamic> j) => SessionLogEntry(
        id: _int(j['id']),
        action: '${j['action']}',
        message: '${j['message']}',
        sessionName: '${j['session_name']}',
        createdAt: _time(j['created_at']),
      );
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class AttentionReason {
  AttentionReason({required this.type, required this.severity, required this.message, required this.value});

  /// protection_removed, offline, session_use, over_limit, block_attempts
  final String type;

  /// high, medium, low
  final String severity;
  final String message;
  final int value;

  factory AttentionReason.fromJson(Map<String, dynamic> j) => AttentionReason(
        type: '${j['type']}',
        severity: '${j['severity']}',
        message: '${j['message']}',
        value: _int(j['value']),
      );
}

class AttentionItem {
  AttentionItem({required this.student, required this.severity, required this.connectionStatus, required this.reasons});

  final StudentRef student;
  final String severity;
  final String connectionStatus;
  final List<AttentionReason> reasons;

  factory AttentionItem.fromJson(Map<String, dynamic> j) => AttentionItem(
        student: StudentRef.fromJson((j['student'] as Map).cast<String, dynamic>()),
        severity: '${j['severity']}',
        connectionStatus: '${j['connection_status']}',
        reasons: _maps(j['reasons']).map(AttentionReason.fromJson).toList(),
      );
}

class AttentionPage {
  AttentionPage({required this.items, required this.total, required this.countsByType});

  final List<AttentionItem> items;
  final int total;
  final Map<String, int> countsByType;

  factory AttentionPage.fromJson(Map<String, dynamic> j) => AttentionPage(
        items: _maps(j['data']).map(AttentionItem.fromJson).toList(),
        total: _int(j['total']),
        countsByType: ((j['counts_by_type'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', _int(v))),
      );
}

class RunningSession {
  RunningSession({required this.id, required this.name, required this.studentCount, required this.usingPhoneCount});

  final int id;
  final String name;
  final int studentCount;
  final int usingPhoneCount;

  factory RunningSession.fromJson(Map<String, dynamic> j) => RunningSession(
        id: _int(j['id']),
        name: '${j['name']}',
        studentCount: _int(j['student_count']),
        usingPhoneCount: _int(j['using_phone_count']),
      );
}

class TopApp {
  TopApp({required this.appName, required this.minutes, required this.students});

  final String appName;
  final int minutes;
  final int students;

  factory TopApp.fromJson(Map<String, dynamic> j) => TopApp(
        appName: '${j['app_name'] ?? j['package_name']}',
        minutes: _int(j['minutes']),
        students: _int(j['students']),
      );
}

class TrendDay {
  TrendDay({required this.date, required this.avgScreenTimeMinutes, required this.avgSessionUseMinutes});

  final String date;
  final int avgScreenTimeMinutes;
  final int avgSessionUseMinutes;

  factory TrendDay.fromJson(Map<String, dynamic> j) => TrendDay(
        date: '${j['date']}',
        avgScreenTimeMinutes: _int(j['avg_screen_time_minutes']),
        avgSessionUseMinutes: _int(j['avg_session_use_minutes']),
      );
}

class ScreenTimeOverview {
  ScreenTimeOverview(this.raw);

  /// The whole `data` object, for fields not wrapped below.
  final Map<String, dynamic> raw;

  Map<String, dynamic> _o(String k) => ((raw[k] as Map?) ?? const {}).cast<String, dynamic>();

  int get totalStudents => _int(_o('students')['total']);
  int get neverConnected => _int(_o('students')['never_connected']);
  int get online => _int((_o('students')['connection'] as Map?)?['online']);
  int get quiet => _int((_o('students')['connection'] as Map?)?['quiet']);
  int get offline => _int((_o('students')['connection'] as Map?)?['offline']);

  int get inSession => _int(_o('right_now')['in_session']);
  int get usingPhoneInSession => _int(_o('right_now')['using_phone_in_session']);
  int get locked => _int(_o('right_now')['locked']);
  int get protectionRemoved => _int(_o('right_now')['protection_removed']);
  List<RunningSession> get sessionsRunning => _maps(_o('right_now')['sessions_running']).map(RunningSession.fromJson).toList();

  int get attentionCount => _int(_o('needs_action')['attention_count']);
  int get highSeverityCount => _int(_o('needs_action')['high_severity_count']);
  int get pendingAppRequests => _int(_o('needs_action')['pending_app_requests']);
  int get unreadAlerts => _int(_o('needs_action')['unread_alerts']);

  int get avgScreenTimeToday => _int(_o('today')['avg_screen_time_minutes']);
  int get totalSessionUseToday => _int(_o('today')['total_session_use_minutes']);
  int get overDailyLimit => _int(_o('today')['over_daily_limit']);
  Map<String, int> get blockAttempts =>
      ((_o('today')['block_attempts'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', _int(v)));
  List<TopApp> get topApps => _maps(_o('today')['top_apps']).map(TopApp.fromJson).toList();

  List<TrendDay> get trendDays => _maps(_o('trend')['days']).map(TrendDay.fromJson).toList();
  int get weekAvgScreenTime => _int(_o('trend')['avg_screen_time_minutes']);
  int? get weekChangePct => _intOrNull(_o('trend')['change_pct']);
}

class RuleLine {
  RuleLine({required this.kind, required this.text, required this.state, this.runningNow = false, this.sessionId});

  /// session, personal, daily_limit, blocked_apps, app_limits, app_installs, locked
  final String kind;

  /// "Night Curfew 22:00–06:00 every day"
  final String text;

  /// on, off, paused
  final String state;
  final bool runningNow;
  final int? sessionId;

  factory RuleLine.fromJson(Map<String, dynamic> j) => RuleLine(
        kind: '${j['kind']}',
        text: '${j['text']}',
        state: '${j['state']}',
        runningNow: _bool(j['running_now']),
        sessionId: _intOrNull(j['session_id']),
      );
}

class StudentSummary {
  StudentSummary(this.raw);

  final Map<String, dynamic> raw;

  Map<String, dynamic> _o(String k) => ((raw[k] as Map?) ?? const {}).cast<String, dynamic>();

  StudentRef get student => StudentRef.fromJson(_o('student'));

  String get connectionStatus => '${_o('status')['connection_status']}';
  String? get currentApp => _o('status')['current_app'] as String?;
  bool get isScreenOn => _bool(_o('status')['is_screen_on']);
  bool get inCurfewNow => _bool(_o('status')['in_curfew_now']);
  bool get protectionRemoved => _bool(_o('status')['protection_removed']);
  int? get batteryLevel => _intOrNull(_o('status')['battery_level']);

  List<RuleLine> get rules => _maps(raw['rules']).map(RuleLine.fromJson).toList();
  List<CurfewSession> get sessions => _maps(raw['sessions']).map(CurfewSession.fromJson).toList();

  int get todayMinutes => _int(_o('today')['total_minutes']);
  int get todaySessionUse => _int(_o('today')['session_use_minutes']);

  int get dailyAvg => _int(_o('usage')['daily_avg_minutes']);
  int get previousDailyAvg => _int(_o('usage')['previous_daily_avg_minutes']);
  int? get changePct => _intOrNull(_o('usage')['change_pct']);
  int get rangeSessionUse => _int(_o('usage')['session_use_minutes']);
  List<Map<String, dynamic>> get days => _maps(_o('usage')['days']);
  List<TopApp> get topApps => _maps(_o('usage')['top_apps']).map(TopApp.fromJson).toList();

  List<AttentionReason> get problems => _maps(_o('problems')['attention']).map(AttentionReason.fromJson).toList();
  Map<String, int> get blockAttemptsByReason =>
      ((_o('problems')['block_attempts_by_reason'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', _int(v)));
  List<Map<String, dynamic>> get recentAlerts => _maps(_o('problems')['recent_alerts']);
}

/// "45 min", "3 h 10 min", "2 d 4 h" (same as the server's messages).
String formatMinutes(int total) {
  final m = total < 0 ? 0 : total;
  if (m < 60) return '$m min';
  final days = m ~/ 1440;
  final hours = (m % 1440) ~/ 60;
  final mins = m % 60;
  if (days > 0) return hours > 0 ? '$days d $hours h' : '$days d';
  return mins > 0 ? '$hours h $mins min' : '$hours h';
}
