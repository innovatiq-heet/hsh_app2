import '../../phonebook/models/phonebook_models.dart';

/// A father or mother whose birthday falls on a given day, from the
/// phonebook synced on this phone (`fatherDob` / `motherDob`, `yyyy-MM-dd`).
///
/// Display and phone-WhatsApp only: nothing here is sent to the server or used
/// to act on a student.
class ParentBirthday {
  /// `father` or `mother` (same values as the template audiences).
  final String role;
  final String parentName;
  final String phone;
  final DateTime dob;

  /// Age they turn on [day]; null when the year looks wrong.
  final int? turning;

  /// Their children in the hostel (siblings share parents).
  final List<String> studentNames;

  /// First child's details, for the photo, room and group.
  final String? studentAadhar;
  final String? bankCode;
  final String? room;
  final String? groupName;
  final bool isAlumni;

  /// Numeric `students.id` of their children (server list only; the phonebook
  /// has none). The server bot needs one to send.
  final List<int> studentIds;

  /// The server already wished them today.
  final bool alreadySent;

  const ParentBirthday({
    required this.role,
    required this.parentName,
    required this.phone,
    required this.dob,
    required this.turning,
    required this.studentNames,
    this.studentAadhar,
    this.bankCode,
    this.room,
    this.groupName,
    this.isAlumni = false,
    this.studentIds = const [],
    this.alreadySent = false,
  });

  /// One entry of `todaysParentBirthdays` / `tomorrowsParentBirthdays`.
  factory ParentBirthday.fromServer(Map<String, dynamic> json) {
    final kids = (json['students'] is List ? json['students'] as List : const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final first = kids.isEmpty ? const <String, dynamic>{} : kids.first;
    final role = json['role'] == 'mother' ? 'mother' : 'father';
    final room = (first['room'] ?? '').toString().trim();
    final status = (first['status'] ?? '').toString().toLowerCase();
    final isAlumni = room.isEmpty ||
        room.toLowerCase() == 'n/a' ||
        room.toLowerCase() == 'alumni' ||
        status.contains('left') ||
        status.contains('cancel') ||
        status.contains('alumni');
    final dob = parseDob(json['dob']?.toString()) ?? DateTime(1900);
    final turning = json['turning'];
    final name = (json['parentName'] ?? '').toString().trim();
    return ParentBirthday(
      role: role,
      parentName: name.isNotEmpty ? name : (role == 'father' ? 'Father' : 'Mother'),
      phone: (json['phone'] ?? '').toString().trim(),
      dob: dob,
      turning: turning is num ? turning.toInt() : int.tryParse('${turning ?? ''}'),
      studentNames: [for (final k in kids) (k['name'] ?? 'Student').toString()],
      bankCode: first['studentCode']?.toString(),
      room: room.isEmpty ? null : room,
      groupName: first['groupName']?.toString(),
      isAlumni: isAlumni,
      // Numeric students.id only: a positive integer without a leading zero.
      // Anything else (a bank code like "0812", "HSH-…") is never kept, so it
      // can't be sent as an id (AGENTS.md, student identity).
      studentIds: [for (final k in kids) _studentId(k['studentId'])].whereType<int>().toList(),
      alreadySent: json['alreadySentToday'] == true,
    );
  }

  static int? _studentId(dynamic v) {
    if (v is int) return v > 0 ? v : null;
    final text = '${v ?? ''}'.trim();
    return RegExp(r'^[1-9][0-9]*$').hasMatch(text) ? int.parse(text) : null;
  }

  ParentBirthday copyWith({bool? alreadySent}) => ParentBirthday(
        role: role,
        parentName: parentName,
        phone: phone,
        dob: dob,
        turning: turning,
        studentNames: studentNames,
        studentAadhar: studentAadhar,
        bankCode: bankCode,
        room: room,
        groupName: groupName,
        isAlumni: isAlumni,
        studentIds: studentIds,
        alreadySent: alreadySent ?? this.alreadySent,
      );

  /// Same parent (role + phone, else name) in two lists.
  String get key =>
      '$role|${phone.replaceAll(RegExp(r'\D'), '').isNotEmpty ? phone.replaceAll(RegExp(r'\D'), '') : parentName.toLowerCase()}';

  bool get isFather => role == 'father';

  /// "Father of Rohan Sharma", "Mother of Rohan & Meet Sharma", "Father of Rohan +2".
  String get relationLine {
    final who = isFather ? 'Father' : 'Mother';
    if (studentNames.length == 1) return '$who of ${studentNames.first}';
    if (studentNames.length == 2) return '$who of ${studentNames[0]} & ${studentNames[1]}';
    return '$who of ${studentNames.first} +${studentNames.length - 1}';
  }

  ParentBirthday _withSibling(String name) => ParentBirthday(
        role: role,
        parentName: parentName,
        phone: phone,
        dob: dob,
        turning: turning,
        studentNames: [...studentNames, name],
        studentAadhar: studentAadhar,
        bankCode: bankCode,
        room: room,
        groupName: groupName,
        isAlumni: isAlumni,
      );

  /// `yyyy-MM-dd` (also `yyyy-MM-ddTHH…` and epoch milliseconds). Null when
  /// it can't be read.
  static DateTime? parseDob(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty || v == 'null') return null;
    final ms = int.tryParse(v);
    if (ms != null) {
      if (ms <= 0) return null;
      // Epoch values are midnight IST; shift so the calendar day is right.
      final ist = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).add(const Duration(hours: 5, minutes: 30));
      return DateTime(ist.year, ist.month, ist.day);
    }
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(v);
    if (m == null) return null;
    final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  /// Whether a birthday on [dob] is celebrated on [day]. 29 February is
  /// celebrated on 28 February in other years.
  static bool fallsOn(DateTime dob, DateTime day) {
    if (dob.month == 2 && dob.day == 29 && !_isLeap(day.year)) {
      return day.month == 2 && day.day == 28;
    }
    return dob.month == day.month && dob.day == day.day;
  }

  static bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  /// Fathers and mothers of [students] whose birthday is on [day], fathers
  /// first, then by name. A parent shared by siblings is listed once.
  /// [group] keeps only that hostel group (case-insensitive); null keeps all.
  static List<ParentBirthday> on(Iterable<PhonebookStudent> students, DateTime day, {String? group}) {
    final wanted = group?.trim().toLowerCase();
    final byKey = <String, ParentBirthday>{};

    void add(PhonebookStudent s, String role, String? name, String? phone, String? rawDob) {
      final dob = parseDob(rawDob);
      if (dob == null || !fallsOn(dob, day)) return;
      final parentName = (name ?? '').trim();
      final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
      if (parentName.isEmpty && digits.isEmpty) return;
      // Same parent of two siblings: same role, birthday and phone (or name).
      final key = '$role|${dob.toIso8601String()}|${digits.isNotEmpty ? digits : parentName.toLowerCase()}';
      final existing = byKey[key];
      if (existing != null) {
        if (!existing.studentNames.contains(s.name)) byKey[key] = existing._withSibling(s.name);
        return;
      }
      final age = day.year - dob.year;
      byKey[key] = ParentBirthday(
        role: role,
        parentName: parentName.isNotEmpty ? parentName : (role == 'father' ? 'Father' : 'Mother'),
        phone: (phone ?? '').trim(),
        dob: dob,
        turning: age > 0 && age < 120 ? age : null,
        studentNames: [s.name],
        studentAadhar: s.aadhar,
        bankCode: s.bankCode,
        room: s.room,
        groupName: s.groupName,
        isAlumni: s.isAlumni,
      );
    }

    for (final s in students) {
      if (wanted != null && wanted.isNotEmpty && (s.groupName ?? '').trim().toLowerCase() != wanted) continue;
      add(s, 'father', s.fatherName, s.fatherPhone, s.fatherDob);
      add(s, 'mother', s.motherName, s.motherPhone, s.motherDob);
    }

    final list = byKey.values.toList()
      ..sort((a, b) {
        if (a.isFather != b.isFather) return a.isFather ? -1 : 1;
        return a.parentName.toLowerCase().compareTo(b.parentName.toLowerCase());
      });
    return list;
  }
}
