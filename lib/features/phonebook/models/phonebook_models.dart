class PhonebookContact {
  final String? id;
  final String phone;
  final String phoneNormalized;
  final String label;
  final bool isPrimary;

  const PhonebookContact({
    this.id,
    required this.phone,
    required this.phoneNormalized,
    this.label = 'Mobile',
    this.isPrimary = true,
  });

  factory PhonebookContact.fromJson(Map<String, dynamic> json) {
    return PhonebookContact(
      id: json['id']?.toString(),
      phone: json['phone']?.toString() ?? '',
      phoneNormalized: json['phone_normalized']?.toString() ??
          json['phone']?.toString() ??
          '',
      label: json['label']?.toString() ?? 'Mobile',
      isPrimary: json['is_primary'] == 1 || json['is_primary'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'phone_normalized': phoneNormalized,
      'label': label,
      'is_primary': isPrimary ? 1 : 0,
    };
  }
}

class PhonebookStudent {
  final String id;
  final String studentId;
  final String name;
  final String enrollmentNumber;
  final String department;
  final String batch;
  final String? email;
  final List<PhonebookContact> phones;
  final String? room;
  final String? groupName;
  final String? updatedAt;

  const PhonebookStudent({
    required this.id,
    required this.studentId,
    required this.name,
    required this.enrollmentNumber,
    required this.department,
    required this.batch,
    this.email,
    this.phones = const [],
    this.room,
    this.groupName,
    this.updatedAt,
  });

  factory PhonebookStudent.fromJson(Map<String, dynamic> json) {
    List<PhonebookContact> phonesList = [];
    if (json['phones'] != null && json['phones'] is List) {
      phonesList = (json['phones'] as List)
          .whereType<Map<String, dynamic>>()
          .map((p) => PhonebookContact.fromJson(p))
          .toList();
    } else if (json['phone'] != null) {
      phonesList = [
        PhonebookContact(
          phone: json['phone_raw']?.toString() ?? json['phone']?.toString() ?? '',
          phoneNormalized: json['phone']?.toString() ?? '',
          label: json['phone_label']?.toString() ?? 'Student Mobile',
          isPrimary: json['is_primary'] == 1 || json['is_primary'] == true,
        )
      ];
    }

    final dept = json['department']?.toString() ?? '';
    String? derivedRoom;
    String? derivedGroup;

    if (dept.contains('Room ')) {
      final parts = dept.split('Room ');
      if (parts.length > 1) {
        derivedRoom = parts[1].trim();
      }
    }
    if (dept.contains(' • ')) {
      derivedGroup = dept.split(' • ').first.trim();
    } else if (['param', 'pavitra', 'pulkit', 'paramanand']
        .contains(dept.toLowerCase().trim())) {
      derivedGroup = dept.trim();
    }

    final rawRoom = json['room']?.toString().trim();
    final isRoomNa = rawRoom == null ||
        rawRoom.isEmpty ||
        rawRoom.toLowerCase() == 'n/a' ||
        rawRoom.toLowerCase() == 'none' ||
        rawRoom.toLowerCase() == 'null';
    final resolvedRoom = isRoomNa
        ? (dept.toLowerCase().contains('alumni') ? 'Alumni' : (derivedRoom ?? 'Alumni'))
        : rawRoom;

    return PhonebookStudent(
      id: json['id']?.toString() ?? json['internal_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      enrollmentNumber: json['enrollment_number']?.toString() ?? '',
      department: dept,
      batch: json['batch']?.toString() ?? 'ACTIVE',
      email: json['email']?.toString(),
      phones: phonesList,
      room: resolvedRoom,
      groupName: json['group_name']?.toString() ?? derivedGroup,
      updatedAt: json['updated_at']?.toString(),
    );
  }

  String get primaryPhone {
    if (phones.isEmpty) return 'No Phone';
    final primary =
        phones.firstWhere((p) => p.isPrimary, orElse: () => phones.first);
    return primary.phone.isNotEmpty ? primary.phone : primary.phoneNormalized;
  }
}

class PhonebookSyncResult {
  final bool success;
  final int totalStudents;
  final int totalPhones;
  final String? errorMessage;
  final DateTime syncTime;

  PhonebookSyncResult({
    required this.success,
    required this.totalStudents,
    required this.totalPhones,
    this.errorMessage,
    DateTime? syncTime,
  }) : syncTime = syncTime ?? DateTime.now();
}
