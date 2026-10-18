import 'package:intl/intl.dart';

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

  // Comprehensive profile & personal fields
  final String? dob;
  final String? aadhar;
  final String? address;
  final String? pinCode;
  final String? bloodGroup;
  final String? fatherName;
  final String? motherName;
  final String? fatherPhone;
  final String? motherPhone;
  final String? whatsappNumber;
  final String? status;
  final String? bankCode;
  final int? floor;

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
    this.dob,
    this.aadhar,
    this.address,
    this.pinCode,
    this.bloodGroup,
    this.fatherName,
    this.motherName,
    this.fatherPhone,
    this.motherPhone,
    this.whatsappNumber,
    this.status,
    this.bankCode,
    this.floor,
  });

  PhonebookStudent copyWith({
    String? id,
    String? studentId,
    String? name,
    String? enrollmentNumber,
    String? department,
    String? batch,
    String? email,
    List<PhonebookContact>? phones,
    String? room,
    String? groupName,
    String? updatedAt,
    String? dob,
    String? aadhar,
    String? address,
    String? pinCode,
    String? bloodGroup,
    String? fatherName,
    String? motherName,
    String? fatherPhone,
    String? motherPhone,
    String? whatsappNumber,
    String? status,
    String? bankCode,
    int? floor,
  }) {
    return PhonebookStudent(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      enrollmentNumber: enrollmentNumber ?? this.enrollmentNumber,
      department: department ?? this.department,
      batch: batch ?? this.batch,
      email: email ?? this.email,
      phones: phones ?? this.phones,
      room: room ?? this.room,
      groupName: groupName ?? this.groupName,
      updatedAt: updatedAt ?? this.updatedAt,
      dob: dob ?? this.dob,
      aadhar: aadhar ?? this.aadhar,
      address: address ?? this.address,
      pinCode: pinCode ?? this.pinCode,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      motherPhone: motherPhone ?? this.motherPhone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      status: status ?? this.status,
      bankCode: bankCode ?? this.bankCode,
      floor: floor ?? this.floor,
    );
  }

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

    final rawRoom = json['room']?.toString().trim() ?? json['room_num']?.toString().trim();
    final isRoomNa = rawRoom == null ||
        rawRoom.isEmpty ||
        rawRoom.toLowerCase() == 'n/a' ||
        rawRoom.toLowerCase() == 'none' ||
        rawRoom.toLowerCase() == 'null';
    final resolvedRoom = isRoomNa
        ? (dept.toLowerCase().contains('alumni') ? 'Alumni' : (derivedRoom ?? 'Alumni'))
        : rawRoom;

    // Derive Floor
    int? resolvedFloor;
    if (json['floor_num'] != null) {
      resolvedFloor = int.tryParse(json['floor_num'].toString());
    } else if (json['floor'] != null) {
      resolvedFloor = int.tryParse(json['floor'].toString());
    } else if (resolvedRoom != 'Alumni') {
      final digits = resolvedRoom.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 5) {
        resolvedFloor = int.tryParse(digits.substring(0, 2));
      } else if (digits.length >= 3) {
        resolvedFloor = int.tryParse(digits.substring(0, 1));
      }
    }

    final rawDob = json['dob']?.toString().trim();
    final cleanDob = (rawDob != null && rawDob.isNotEmpty && rawDob != 'null') ? rawDob : null;

    final rawAadhar = json['aadhar']?.toString().trim();
    final cleanAadhar = (rawAadhar != null && rawAadhar.isNotEmpty && rawAadhar != 'null') ? rawAadhar : null;

    final rawBankCode = json['bank_code']?.toString().trim() ?? json['bankCode']?.toString().trim();
    final cleanBankCode = (rawBankCode != null && rawBankCode.isNotEmpty && rawBankCode != 'null') ? rawBankCode : null;

    final rawFatherName = json['father_name']?.toString().trim() ?? json['middleName']?.toString().trim();
    final cleanFatherName = (rawFatherName != null && rawFatherName.isNotEmpty && rawFatherName != 'null') ? rawFatherName : null;

    final rawMotherName = json['mother_name']?.toString().trim() ?? json['motherName']?.toString().trim() ?? json['mother']?.toString().trim();
    final cleanMotherName = (rawMotherName != null && rawMotherName.isNotEmpty && rawMotherName != 'null') ? rawMotherName : null;

    final rawFatherPhone = json['father_phone']?.toString().trim() ?? json['fatherPhone']?.toString().trim();
    final cleanFatherPhone = (rawFatherPhone != null && rawFatherPhone.isNotEmpty && rawFatherPhone != 'null') ? rawFatherPhone : null;

    final rawMotherPhone = json['mother_phone']?.toString().trim() ?? json['motherPhone']?.toString().trim();
    final cleanMotherPhone = (rawMotherPhone != null && rawMotherPhone.isNotEmpty && rawMotherPhone != 'null') ? rawMotherPhone : null;

    final rawWhatsApp = json['whatsapp_number']?.toString().trim() ?? json['whatsAppNumber']?.toString().trim();
    final cleanWhatsApp = (rawWhatsApp != null && rawWhatsApp.isNotEmpty && rawWhatsApp != 'null') ? rawWhatsApp : null;

    final rawStatus = json['status']?.toString().trim();
    final cleanStatus = (rawStatus != null && rawStatus.isNotEmpty && rawStatus != 'null') ? rawStatus : null;

    final rawAddress = (json['address'] ?? json['permanent_address'] ?? json['home_address'])?.toString().trim();
    final cleanAddress = (rawAddress != null &&
            rawAddress.isNotEmpty &&
            rawAddress != 'null' &&
            !rawAddress.contains('Hari Smruti Hostel') &&
            !rawAddress.contains('Hari Saurabh Hostel'))
        ? rawAddress
        : null;

    final rawPin = json['pin_code']?.toString().trim() ?? json['pinCode']?.toString().trim();
    final cleanPin = (rawPin != null &&
            rawPin.isNotEmpty &&
            rawPin != 'null' &&
            (cleanAddress != null || rawPin != '388120'))
        ? rawPin
        : null;

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
      dob: cleanDob,
      aadhar: cleanAadhar,
      address: cleanAddress,
      pinCode: cleanPin,
      bloodGroup: json['blood_group']?.toString() ?? json['bloodGroup']?.toString(),
      fatherName: cleanFatherName,
      motherName: cleanMotherName,
      fatherPhone: cleanFatherPhone,
      motherPhone: cleanMotherPhone,
      whatsappNumber: cleanWhatsApp,
      status: cleanStatus,
      bankCode: cleanBankCode,
      floor: resolvedFloor,
    );
  }

  String get primaryPhone {
    if (phones.isEmpty) return 'No Phone';
    final primary =
        phones.firstWhere((p) => p.isPrimary, orElse: () => phones.first);
    return primary.phone.isNotEmpty ? primary.phone : primary.phoneNormalized;
  }

  bool get isAlumni {
    final r = (room ?? '').toLowerCase().trim();
    final b = (batch).toLowerCase().trim();
    final d = (department).toLowerCase().trim();
    final s = (status ?? '').toLowerCase().trim();
    return r == 'alumni' ||
        r == 'n/a' ||
        r.isEmpty ||
        b.contains('alumni') ||
        d.contains('alumni') ||
        s.contains('left') ||
        s.contains('cancel') ||
        s.contains('alumni');
  }

  bool get hasDob => dob != null && dob!.trim().isNotEmpty;
  bool get hasMotherName => motherName != null && motherName!.trim().isNotEmpty;
  bool get hasFatherPhone => fatherPhone != null && fatherPhone!.trim().isNotEmpty;
  bool get hasMotherPhone => motherPhone != null && motherPhone!.trim().isNotEmpty;
  bool get hasWhatsApp => whatsappNumber != null && whatsappNumber!.trim().isNotEmpty;

  /// Formatted Date of Birth: e.g. "29 Mar 2007"
  String get formattedDob {
    if (dob == null || dob!.isEmpty) return 'Not Provided';
    try {
      final clean = dob!.trim();
      DateTime? parsed = DateTime.tryParse(clean);
      if (parsed == null && clean.contains('-')) {
        final parts = clean.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            parsed = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          } else {
            parsed = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      }
      if (parsed != null) {
        return DateFormat('d MMM yyyy').format(parsed);
      }
      return clean;
    } catch (_) {
      return dob!;
    }
  }

  /// Calculated Age text: e.g. "19 yrs"
  String get ageText {
    if (dob == null || dob!.isEmpty) return '';
    try {
      DateTime? parsed = DateTime.tryParse(dob!.trim());
      if (parsed != null) {
        final now = DateTime.now();
        int age = now.year - parsed.year;
        if (now.month < parsed.month || (now.month == parsed.month && now.day < parsed.day)) {
          age--;
        }
        if (age > 0 && age < 100) return '$age yrs';
      }
    } catch (_) {}
    return '';
  }

  /// Masked Aadhar: e.g. "•••• •••• 4074"
  String get maskedAadhar {
    if (aadhar == null || aadhar!.isEmpty) return 'Not Provided';
    final clean = aadhar!.replaceAll(RegExp(r'\D'), '');
    if (clean.length >= 4) {
      final last4 = clean.substring(clean.length - 4);
      return '•••• •••• $last4';
    }
    return aadhar!;
  }

  /// True if the student has a registered permanent home address.
  bool get hasAddress =>
      address != null &&
      address!.trim().isNotEmpty &&
      address != 'null' &&
      !address!.contains('Hari Smruti Hostel') &&
      !address!.contains('Hari Saurabh Hostel');

  /// Complete Display Address (permanent home address or 'Not Provided')
  String get displayAddress {
    if (hasAddress) {
      if (pinCode != null &&
          pinCode!.trim().isNotEmpty &&
          pinCode != 'null' &&
          !address!.contains(pinCode!)) {
        return '${address!.trim()}, PIN: ${pinCode!.trim()}';
      }
      return address!.trim();
    }
    return 'Not Provided';
  }

  /// Formats all complete student details into a clean, shareable card for WhatsApp / SMS / Email
  String toShareText() {
    final buffer = StringBuffer();
    buffer.writeln('🎓 *Student Profile - Hari Smruti Hostel (HSH)*');
    buffer.writeln('👤 *Name:* $name');
    final w = groupName != null
        ? (groupName!.toLowerCase().endsWith('wing') ? groupName! : '$groupName Wing')
        : 'Hostel';
    if (room != null && room != 'Alumni' && room != 'N/A') {
      buffer.writeln('🚪 *Room:* $room ($w)');
    } else if (groupName != null) {
      buffer.writeln('🏢 *Wing:* $w');
    }
    if (floor != null) {
      buffer.writeln('📶 *Floor:* ${floor == 0 ? 'Ground Floor' : 'Floor $floor'}');
    }
    if (primaryPhone != 'No Phone') {
      buffer.writeln('📞 *Mobile:* $primaryPhone');
    }
    if (whatsappNumber != null && whatsappNumber!.isNotEmpty) {
      buffer.writeln('💬 *WhatsApp:* $whatsappNumber');
    }
    if (fatherName != null || (fatherPhone != null && fatherPhone!.isNotEmpty)) {
      final fName = fatherName ?? 'Father';
      final fPhone = fatherPhone != null ? ' (Ph: $fatherPhone)' : '';
      buffer.writeln('👨 *Father:* $fName$fPhone');
    }
    if (motherName != null || (motherPhone != null && motherPhone!.isNotEmpty)) {
      final mName = motherName ?? 'Mother';
      final mPhone = motherPhone != null ? ' (Ph: $motherPhone)' : '';
      buffer.writeln('👩 *Mother:* $mName$mPhone');
    }
    if (hasDob) {
      final ageStr = ageText.isNotEmpty ? ' ($ageText)' : '';
      buffer.writeln('🎂 *DOB:* $formattedDob$ageStr');
    }
    buffer.writeln('📍 *Address:* $displayAddress');
    if (aadhar != null && aadhar!.isNotEmpty) {
      buffer.writeln('🆔 *Aadhar:* $maskedAadhar');
    }
    if (studentId.isNotEmpty) {
      buffer.writeln('🏷️ *Student ID:* $studentId');
    }
    return buffer.toString().trim();
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
