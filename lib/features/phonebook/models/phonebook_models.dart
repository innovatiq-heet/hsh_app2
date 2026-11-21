import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../../../core/utils/string_formatting.dart';
import '../../../core/utils/student_photo.dart';
import '../services/phone_number_normalizer.dart';

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
      phoneNormalized:
          json['phone_normalized']?.toString() ??
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
  final String? fatherDob;
  final String? fatherBusiness;
  final String? motherDob;
  final String? motherBusiness;
  final String? anniversary;
  final String? city;
  final String? district;
  final String? state;
  final String? whatsappNumber;
  final String? status;
  final String? bankCode;
  final int? floor;
  final List<StudentTag> tags;

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
    this.fatherDob,
    this.fatherBusiness,
    this.motherDob,
    this.motherBusiness,
    this.anniversary,
    this.city,
    this.district,
    this.state,
    this.whatsappNumber,
    this.status,
    this.bankCode,
    this.floor,
    this.tags = const [],
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
    String? fatherDob,
    String? fatherBusiness,
    String? motherDob,
    String? motherBusiness,
    String? anniversary,
    String? city,
    String? district,
    String? state,
    String? whatsappNumber,
    String? status,
    String? bankCode,
    int? floor,
    List<StudentTag>? tags,
  }) {
    return PhonebookStudent(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      name: name != null ? formatPersonName(name) : this.name,
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
      fatherName: fatherName != null
          ? formatPersonName(fatherName)
          : this.fatherName,
      motherName: motherName != null
          ? formatPersonName(motherName)
          : this.motherName,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      motherPhone: motherPhone ?? this.motherPhone,
      fatherDob: fatherDob ?? this.fatherDob,
      fatherBusiness: fatherBusiness ?? this.fatherBusiness,
      motherDob: motherDob ?? this.motherDob,
      motherBusiness: motherBusiness ?? this.motherBusiness,
      anniversary: anniversary ?? this.anniversary,
      city: city ?? this.city,
      district: district ?? this.district,
      state: state ?? this.state,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      status: status ?? this.status,
      bankCode: bankCode ?? this.bankCode,
      floor: floor ?? this.floor,
      tags: tags ?? this.tags,
    );
  }

  /// Hostel floor of a room number: 1–18 is the ground floor (0), 101–118 floor 1,
  /// 201–218 floor 2 and so on up to 901–918 floor 9. The common rooms 3000–9000
  /// count on their own floor (3000 is floor 3). Null for anything else.
  static int? floorOfRoom(String? room) {
    final digits = room?.replaceAll(RegExp(r'\D'), '') ?? '';
    final number = int.tryParse(digits);
    if (number == null || number <= 0) return null;
    if (number < 100) return 0;
    if (number < 1000) return number ~/ 100;
    if (number < 10000) return number ~/ 1000;
    return null;
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
          phone:
              json['phone_raw']?.toString() ?? json['phone']?.toString() ?? '',
          phoneNormalized: json['phone']?.toString() ?? '',
          label: json['phone_label']?.toString() ?? 'Student Mobile',
          isPrimary: json['is_primary'] == 1 || json['is_primary'] == true,
        ),
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
    } else if ([
      'param',
      'pavitra',
      'pulkit',
      'paramanand',
    ].contains(dept.toLowerCase().trim())) {
      derivedGroup = dept.trim();
    }

    final rawRoom =
        json['room']?.toString().trim() ?? json['room_num']?.toString().trim();
    final isRoomNa =
        rawRoom == null ||
        rawRoom.isEmpty ||
        rawRoom.toLowerCase() == 'n/a' ||
        rawRoom.toLowerCase() == 'none' ||
        rawRoom.toLowerCase() == 'null';
    final resolvedRoom = isRoomNa
        ? (dept.toLowerCase().contains('alumni')
              ? 'Alumni'
              : (derivedRoom ?? 'Alumni'))
        : rawRoom;

    // Derive Floor
    int? resolvedFloor;
    if (json['floor_num'] != null) {
      resolvedFloor = int.tryParse(json['floor_num'].toString());
    } else if (json['floor'] != null) {
      resolvedFloor = int.tryParse(json['floor'].toString());
    } else if (resolvedRoom != 'Alumni') {
      resolvedFloor = floorOfRoom(resolvedRoom);
    }

    final rawDob = json['dob']?.toString().trim();
    final cleanDob = (rawDob != null && rawDob.isNotEmpty && rawDob != 'null')
        ? rawDob
        : null;

    final rawAadhar = json['aadhar']?.toString().trim();
    final cleanAadhar =
        (rawAadhar != null && rawAadhar.isNotEmpty && rawAadhar != 'null')
        ? rawAadhar
        : null;

    final rawBankCode =
        json['bank_code']?.toString().trim() ??
        json['bankCode']?.toString().trim();
    final cleanBankCode =
        (rawBankCode != null && rawBankCode.isNotEmpty && rawBankCode != 'null')
        ? rawBankCode
        : null;

    final rawFatherName =
        json['father_name']?.toString().trim() ??
        json['middleName']?.toString().trim();
    final cleanFatherName =
        (rawFatherName != null &&
            rawFatherName.isNotEmpty &&
            rawFatherName != 'null')
        ? rawFatherName
        : null;

    final rawMotherName =
        json['mother_name']?.toString().trim() ??
        json['motherName']?.toString().trim() ??
        json['mother']?.toString().trim();
    final cleanMotherName =
        (rawMotherName != null &&
            rawMotherName.isNotEmpty &&
            rawMotherName != 'null')
        ? rawMotherName
        : null;

    final rawFatherPhone =
        json['father_phone']?.toString().trim() ??
        json['fatherPhone']?.toString().trim();
    final cleanFatherPhone =
        (rawFatherPhone != null &&
            rawFatherPhone.isNotEmpty &&
            rawFatherPhone != 'null')
        ? rawFatherPhone
        : null;

    final rawMotherPhone =
        json['mother_phone']?.toString().trim() ??
        json['motherPhone']?.toString().trim();
    final cleanMotherPhone =
        (rawMotherPhone != null &&
            rawMotherPhone.isNotEmpty &&
            rawMotherPhone != 'null')
        ? rawMotherPhone
        : null;

    final rawWhatsApp =
        json['whatsapp_number']?.toString().trim() ??
        json['whatsAppNumber']?.toString().trim();
    final cleanWhatsApp =
        (rawWhatsApp != null && rawWhatsApp.isNotEmpty && rawWhatsApp != 'null')
        ? rawWhatsApp
        : null;

    final rawStatus = json['status']?.toString().trim();
    final cleanStatus =
        (rawStatus != null && rawStatus.isNotEmpty && rawStatus != 'null')
        ? rawStatus
        : null;

    final rawAddress =
        (json['address'] ?? json['permanent_address'] ?? json['home_address'])
            ?.toString()
            .trim();
    final cleanAddress =
        (rawAddress != null &&
            rawAddress.isNotEmpty &&
            rawAddress != 'null' &&
            !rawAddress.contains('Hari Saurabh Hostel'))
        ? rawAddress
        : null;

    final rawPin =
        json['pin_code']?.toString().trim() ??
        json['pinCode']?.toString().trim();
    final cleanPin =
        (rawPin != null &&
            rawPin.isNotEmpty &&
            rawPin != 'null' &&
            (cleanAddress != null || rawPin != '388120'))
        ? rawPin
        : null;

    final rawFatherDob =
        json['father_dob']?.toString().trim() ??
        json['fatherDob']?.toString().trim();
    final cleanFatherDob =
        (rawFatherDob != null &&
            rawFatherDob.isNotEmpty &&
            rawFatherDob != 'null')
        ? rawFatherDob
        : null;

    final rawFatherBiz =
        json['father_business']?.toString().trim() ??
        json['fatherBusiness']?.toString().trim() ??
        json['fatherProfession']?.toString().trim();
    final cleanFatherBiz =
        (rawFatherBiz != null &&
            rawFatherBiz.isNotEmpty &&
            rawFatherBiz != 'null')
        ? rawFatherBiz
        : null;

    final rawMotherDob =
        json['mother_dob']?.toString().trim() ??
        json['motherDob']?.toString().trim();
    final cleanMotherDob =
        (rawMotherDob != null &&
            rawMotherDob.isNotEmpty &&
            rawMotherDob != 'null')
        ? rawMotherDob
        : null;

    final rawMotherBiz =
        json['mother_business']?.toString().trim() ??
        json['motherBusiness']?.toString().trim();
    final cleanMotherBiz =
        (rawMotherBiz != null &&
            rawMotherBiz.isNotEmpty &&
            rawMotherBiz != 'null')
        ? rawMotherBiz
        : null;

    final rawAnniversary = json['anniversary']?.toString().trim();
    final cleanAnniversary =
        (rawAnniversary != null &&
            rawAnniversary.isNotEmpty &&
            rawAnniversary != 'null')
        ? rawAnniversary
        : null;

    final rawCity =
        json['city']?.toString().trim() ?? json['city_name']?.toString().trim();
    final cleanCity =
        (rawCity != null && rawCity.isNotEmpty && rawCity != 'null')
        ? rawCity
        : null;

    final rawDistrict = json['district']?.toString().trim();
    final cleanDistrict =
        (rawDistrict != null && rawDistrict.isNotEmpty && rawDistrict != 'null')
        ? rawDistrict
        : null;

    final rawState = json['state']?.toString().trim();
    final cleanState =
        (rawState != null && rawState.isNotEmpty && rawState != 'null')
        ? rawState
        : null;

    List<StudentTag> tagsList = [];
    dynamic rawTags = json['tags'];
    if (rawTags is String && rawTags.trim().isNotEmpty) {
      try {
        rawTags = jsonDecode(rawTags);
      } catch (_) {}
    }
    if (rawTags != null && rawTags is List) {
      tagsList = dedupeTags(
        rawTags.whereType<Map>().map(
          (t) => StudentTag.fromJson(Map<String, dynamic>.from(t)),
        ),
      );
    }

    final formattedFatherName = cleanFatherName != null
        ? formatPersonName(cleanFatherName)
        : null;
    final formattedMotherName = cleanMotherName != null
        ? formatPersonName(cleanMotherName)
        : null;

    return PhonebookStudent(
      id: json['id']?.toString() ?? json['internal_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      name: formatPersonName(json['name']?.toString()),
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
      bloodGroup:
          json['blood_group']?.toString() ?? json['bloodGroup']?.toString(),
      fatherName: formattedFatherName,
      motherName: formattedMotherName,
      fatherPhone: cleanFatherPhone,
      motherPhone: cleanMotherPhone,
      fatherDob: cleanFatherDob,
      fatherBusiness: cleanFatherBiz,
      motherDob: cleanMotherDob,
      motherBusiness: cleanMotherBiz,
      anniversary: cleanAnniversary,
      city: cleanCity,
      district: cleanDistrict,
      state: cleanState,
      whatsappNumber: cleanWhatsApp,
      status: cleanStatus,
      bankCode: cleanBankCode,
      floor: resolvedFloor,
      tags: tagsList,
    );
  }

  /// True if student has a tag with the specified name (case-insensitive)
  bool hasTag(String tagName) {
    final norm = tagName.trim().toLowerCase();
    return tags.any((t) => t.name.trim().toLowerCase() == norm);
  }

  String get primaryPhone {
    if (phones.isEmpty) return 'No Phone';
    final primary = phones.firstWhere(
      (p) => p.isPrimary,
      orElse: () => phones.first,
    );
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
  bool get hasFatherPhone =>
      fatherPhone != null && fatherPhone!.trim().isNotEmpty;
  bool get hasMotherPhone =>
      motherPhone != null && motherPhone!.trim().isNotEmpty;
  bool get hasFatherDob => fatherDob != null && fatherDob!.trim().isNotEmpty;
  bool get hasFatherBusiness =>
      fatherBusiness != null && fatherBusiness!.trim().isNotEmpty;
  bool get hasMotherDob => motherDob != null && motherDob!.trim().isNotEmpty;
  bool get hasMotherBusiness =>
      motherBusiness != null && motherBusiness!.trim().isNotEmpty;
  bool get hasAnniversary =>
      anniversary != null && anniversary!.trim().isNotEmpty;
  bool get hasHometown => hometown.isNotEmpty;
  bool get hasWhatsApp =>
      whatsappNumber != null && whatsappNumber!.trim().isNotEmpty;

  /// Formatted Parents' Marriage Anniversary
  String get anniversaryFormatted {
    if (anniversary == null || anniversary!.trim().isEmpty) return '';
    final clean = anniversary!.trim();
    final ms = int.tryParse(clean);
    if (ms != null && ms > 0) {
      try {
        final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
            .add(const Duration(hours: 5, minutes: 30));
        return DateFormat('d MMM yyyy').format(dt);
      } catch (_) {}
    }
    try {
      final dt = DateTime.tryParse(clean);
      if (dt != null) {
        return DateFormat('d MMM yyyy').format(dt);
      }
    } catch (_) {}
    return clean;
  }

  /// Formatted Hometown / Region (City, District, State)
  String get hometown {
    final seen = <String>{};
    final parts = <String>[];
    for (final s in [city, district, state]) {
      final trimmed = s?.trim();
      if (trimmed != null &&
          trimmed.isNotEmpty &&
          seen.add(trimmed.toLowerCase())) {
        parts.add(trimmed);
      }
    }
    return parts.join(', ');
  }

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
            parsed = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          } else {
            parsed = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
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
        if (now.month < parsed.month ||
            (now.month == parsed.month && now.day < parsed.day)) {
          age--;
        }
        if (age > 0 && age < 100) return '$age yrs';
      }
    } catch (_) {}
    return '';
  }

  /// The student's photo, named after the 12-digit Aadhar; null without one.
  String? get photoUrl => studentPhotoUrl(aadhar);

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
    buffer.writeln('🎓 *Student Profile - Hari Saurabh Hostel (HSH)*');
    buffer.writeln('👤 *Name:* $name');
    final w = groupName != null
        ? (groupName!.toLowerCase().endsWith('wing')
              ? groupName!
              : '$groupName Wing')
        : 'Hostel';
    if (room != null && room != 'Alumni' && room != 'N/A') {
      buffer.writeln('🚪 *Room:* $room ($w)');
    } else if (groupName != null) {
      buffer.writeln('🏢 *Wing:* $w');
    }
    if (floor != null) {
      buffer.writeln(
        '📶 *Floor:* ${floor == 0 ? 'Ground Floor' : 'Floor $floor'}',
      );
    }
    final hasWa = whatsappNumber != null && whatsappNumber!.isNotEmpty;
    final hasPrim = primaryPhone != 'No Phone' && primaryPhone.isNotEmpty;
    final isSameWaAndMobile = hasWa &&
        hasPrim &&
        PhoneNumberNormalizer.isSame(primaryPhone, whatsappNumber);

    if (isSameWaAndMobile) {
      buffer.writeln('📱 *Mobile & WhatsApp:* $primaryPhone');
    } else {
      if (hasPrim) {
        buffer.writeln('📞 *Mobile:* $primaryPhone');
      }
      if (hasWa) {
        buffer.writeln('💬 *WhatsApp:* $whatsappNumber');
      }
    }
    if (fatherName != null ||
        (fatherPhone != null && fatherPhone!.isNotEmpty) ||
        hasFatherBusiness) {
      final fName = fatherName ?? 'Father';
      final fPhone = fatherPhone != null ? ' (Ph: $fatherPhone)' : '';
      final fBiz = hasFatherBusiness ? ' • $fatherBusiness' : '';
      buffer.writeln('👨 *Father:* $fName$fBiz$fPhone');
    }
    for (final p in phones) {
      if (!p.label.toLowerCase().contains('father')) continue;
      if (fatherPhone != null &&
          fatherPhone!.isNotEmpty &&
          PhoneNumberNormalizer.isSame(p.phone, fatherPhone)) {
        continue;
      }
      buffer.writeln('📞 *${p.label}:* ${p.phone}');
    }
    if (motherName != null ||
        (motherPhone != null && motherPhone!.isNotEmpty) ||
        hasMotherBusiness) {
      final mName = motherName ?? 'Mother';
      final mPhone = motherPhone != null ? ' (Ph: $motherPhone)' : '';
      final mBiz = hasMotherBusiness ? ' • $motherBusiness' : '';
      buffer.writeln('👩 *Mother:* $mName$mBiz$mPhone');
    }
    for (final p in phones) {
      if (!p.label.toLowerCase().contains('mother')) continue;
      if (motherPhone != null &&
          motherPhone!.isNotEmpty &&
          PhoneNumberNormalizer.isSame(p.phone, motherPhone)) {
        continue;
      }
      buffer.writeln('📞 *${p.label}:* ${p.phone}');
    }
    if (hasAnniversary) {
      buffer.writeln('💍 *Parents’ Anniversary:* $anniversaryFormatted');
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
