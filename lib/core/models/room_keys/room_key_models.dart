/// Room keys: every door and cupboard key of a hostel room, with the number
/// stamped on it and who has it. Contract: docs/ROOM_KEYS_DOCS.md.
library;

/// What a key opens.
enum KeyType {
  door('door', 'Door'),
  cupboard('cupboard', 'Cupboard');

  const KeyType(this.wire, this.label);

  /// Value sent to and read from the API.
  final String wire;
  final String label;

  static KeyType fromWire(Object? value) =>
      value?.toString().trim().toLowerCase() == 'door' ? KeyType.door : KeyType.cupboard;
}

/// Where a key is.
enum KeyStatus {
  /// With [RoomKey.studentId].
  assigned('assigned', 'With student'),

  /// Kept at the hostel office.
  office('office', 'In office'),

  /// Reported lost ([RoomKey.studentId] keeps who had it).
  lost('lost', 'Lost');

  const KeyStatus(this.wire, this.label);

  final String wire;
  final String label;

  static KeyStatus fromWire(Object? value) {
    final v = value?.toString().trim().toLowerCase();
    return KeyStatus.values.firstWhere((s) => s.wire == v, orElse: () => KeyStatus.office);
  }
}

/// What can be done to a key (`POST /room-keys/:id/action`).
enum KeyAction {
  assign('assign'),
  returnToOffice('return'),
  lost('lost'),
  found('found');

  const KeyAction(this.wire);
  final String wire;
}

/// Room numbers as people type them ("204", " a-12 ") compared as one.
String normalizeRoom(Object? room) => room?.toString().trim().toUpperCase() ?? '';

/// A numeric `students.id` from an API value, or null. Positive integers only:
/// a bank code ("0768") must never become an id (AGENTS.md §4).
int? _studentId(Object? raw) {
  if (raw is int) return raw > 0 ? raw : null;
  final s = raw?.toString().trim() ?? '';
  return RegExp(r'^[1-9]\d*$').hasMatch(s) ? int.parse(s) : null;
}

String? _text(Object? raw) {
  final s = raw?.toString().trim() ?? '';
  return s.isEmpty || s == 'null' ? null : s;
}

/// One physical key of a room.
class RoomKey {
  final int id;
  final String roomNumber;
  final KeyType type;

  /// The number stamped on the key.
  final String keyNumber;

  /// Optional name, e.g. "Main door" or "Cupboard A".
  final String? label;
  final KeyStatus status;

  /// Numeric `students.id` of who has it (assigned) or had it (lost).
  final int? studentId;
  final String? studentName;

  /// That student's current room, to spot a student who moved.
  final String? studentRoom;

  /// False once that student has left the hostel or the account is inactive.
  final bool studentActive;
  final String? notes;
  final DateTime? updatedAt;
  final String? updatedBy;

  const RoomKey({
    required this.id,
    required this.roomNumber,
    required this.type,
    required this.keyNumber,
    this.label,
    this.status = KeyStatus.office,
    this.studentId,
    this.studentName,
    this.studentRoom,
    this.studentActive = true,
    this.notes,
    this.updatedAt,
    this.updatedBy,
  });

  factory RoomKey.fromJson(Map<String, dynamic> j) => RoomKey(
    id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
    roomNumber: normalizeRoom(j['room_number'] ?? j['roomNumber']),
    type: KeyType.fromWire(j['key_type'] ?? j['keyType']),
    keyNumber: _text(j['key_number'] ?? j['keyNumber']) ?? '',
    label: _text(j['label']),
    status: KeyStatus.fromWire(j['status']),
    studentId: _studentId(j['student_id'] ?? j['studentId']),
    studentName: _text(j['student_name'] ?? j['studentName']),
    studentRoom: _text(j['student_room'] ?? j['studentRoom']),
    studentActive: !(j['student_active'] == false || j['student_active'] == 0 || j['student_active'] == '0'),
    notes: _text(j['notes']),
    updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '')?.toLocal(),
    updatedBy: _text(j['updated_by'] ?? j['updatedBy']),
  );

  static final _slotLabel = RegExp(r'^(?:CUPBOARD[\s-]*)?([A-G])(?![A-Z0-9])');

  /// Cupboard slot letter ('A' to 'G') if labeled as such, else null.
  String? get cupboardSlot {
    if (type != KeyType.cupboard || label == null) return null;
    return _slotLabel.firstMatch(label!.trim().toUpperCase())?.group(1);
  }

  /// "Door 204" / "Cupboard 1123" / "Cupboard A · Key 1123".
  String get title {
    if (type == KeyType.cupboard && cupboardSlot != null) {
      return keyNumber.isNotEmpty ? 'Cupboard $cupboardSlot · Key $keyNumber' : 'Cupboard $cupboardSlot';
    }
    return '${type.label} $keyNumber';
  }

  /// User-facing descriptive title including custom labels.
  String get displayTitle {
    if (type == KeyType.cupboard) {
      if (cupboardSlot != null) {
        return keyNumber.isNotEmpty ? 'Cupboard $cupboardSlot · Key $keyNumber' : 'Cupboard $cupboardSlot';
      }
      if (label != null && label!.trim().isNotEmpty) {
        return '$title · ${label!.trim()}';
      }
      return title;
    }
    return label != null && label!.trim().isNotEmpty ? '$title · ${label!.trim()}' : title;
  }

  /// A key still marked with a student who has left the hostel or now lives
  /// in another room: the office should collect it.
  bool get studentMovedOrLeft {
    if (status != KeyStatus.assigned || studentId == null) return false;
    if (!studentActive) return true;
    final now = normalizeRoom(studentRoom);
    return now.isNotEmpty && now != roomNumber;
  }

  /// Lost, or with a student who moved or left.
  bool get needsAttention => status == KeyStatus.lost || studentMovedOrLeft;

  /// Applies `POST /room-keys/:id/action` locally, for an optimistic update.
  RoomKey afterAction(KeyAction action, {int? studentId, String? studentName, String? studentRoom}) {
    switch (action) {
      case KeyAction.assign:
        return _copy(
          status: KeyStatus.assigned,
          studentId: studentId,
          studentName: studentName,
          studentRoom: studentRoom,
          studentActive: true,
        );
      case KeyAction.returnToOffice:
      case KeyAction.found:
        return _copy(status: KeyStatus.office, clearStudent: true);
      case KeyAction.lost:
        return _copy(status: KeyStatus.lost);
    }
  }

  RoomKey _copy({
    KeyStatus? status,
    int? studentId,
    String? studentName,
    String? studentRoom,
    bool? studentActive,
    bool clearStudent = false,
  }) => RoomKey(
    id: id,
    roomNumber: roomNumber,
    type: type,
    keyNumber: keyNumber,
    label: label,
    status: status ?? this.status,
    studentId: clearStudent ? null : (studentId ?? this.studentId),
    studentName: clearStudent ? null : (studentName ?? this.studentName),
    studentRoom: clearStudent ? null : (studentRoom ?? this.studentRoom),
    studentActive: clearStudent ? true : (studentActive ?? this.studentActive),
    notes: notes,
    updatedAt: updatedAt,
    updatedBy: updatedBy,
  );
}

/// A key to add (`POST /room-keys/batch`).
class NewRoomKey {
  final KeyType type;
  final String keyNumber;
  final String? label;

  /// Numeric `students.id` to hand it to at once; null keeps it in the office.
  final int? studentId;

  const NewRoomKey({required this.type, required this.keyNumber, this.label, this.studentId});

  Map<String, dynamic> toJson() => {
    'key_type': type.wire,
    'key_number': keyNumber.trim(),
    if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
    'student_id': ?studentId,
  };
}

/// One line of a key's history (`GET /room-keys/:id/history`).
class RoomKeyLog {
  final String action;
  final int? studentId;
  final String? studentName;
  final String? note;
  final String? byName;
  final DateTime? at;

  const RoomKeyLog({required this.action, this.studentId, this.studentName, this.note, this.byName, this.at});

  factory RoomKeyLog.fromJson(Map<String, dynamic> j) => RoomKeyLog(
    action: _text(j['action']) ?? 'edited',
    studentId: _studentId(j['student_id'] ?? j['studentId']),
    studentName: _text(j['student_name'] ?? j['studentName']),
    note: _text(j['note']),
    byName: _text(j['by_name'] ?? j['byName']),
    at: DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal(),
  );

  /// "Given to Asha Patel", "Returned to office", ...
  String get summary {
    final who = studentName ?? (studentId != null ? 'student #$studentId' : null);
    switch (action) {
      case 'created':
        return who == null ? 'Added' : 'Added and given to $who';
      case 'assigned':
        return who == null ? 'Given to a student' : 'Given to $who';
      case 'returned':
        return who == null ? 'Returned to office' : 'Returned to office by $who';
      case 'lost':
        return who == null ? 'Reported lost' : 'Reported lost ($who)';
      case 'found':
        return 'Found, back in office';
      case 'deleted':
        return 'Removed';
      default:
        return 'Details changed';
    }
  }
}

/// Cupboard slot letters. Two-student rooms use A and B; common rooms hold up
/// to seven students, so they go on to G.
const cupboardSlotLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
