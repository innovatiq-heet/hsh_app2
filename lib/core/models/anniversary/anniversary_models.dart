import '../birthday/birthday_models.dart';

/// Single additional phone entry for a parent.
class ParentAdditionalPhone {
  final String phone;
  final String label;
  final bool isWhatsApp;

  const ParentAdditionalPhone({
    required this.phone,
    required this.label,
    required this.isWhatsApp,
  });

  factory ParentAdditionalPhone.fromJson(Map<String, dynamic> json) {
    return ParentAdditionalPhone(
      phone: (json['phone'] ?? '').toString().trim(),
      label: (json['label'] ?? '').toString().trim(),
      isWhatsApp: json['isWhatsApp'] == true || json['is_whatsapp'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'label': label,
        'isWhatsApp': isWhatsApp,
      };
}

/// Student model for Parents' Marriage Anniversary greetings.
/// Contains both Father and Mother details and phone numbers.
class AnniversaryStudentRecord {
  final int studentId;
  final String name;
  final String studentCode;
  final String room;
  final String? groupName;
  final String? status;
  final String fatherName;
  final String motherName;
  final String fatherPhone;
  final String motherPhone;
  final List<ParentAdditionalPhone> extraFatherPhones;
  final List<ParentAdditionalPhone> extraMotherPhones;
  final String anniversaryDate;
  final bool alreadySentToday;

  const AnniversaryStudentRecord({
    required this.studentId,
    required this.name,
    required this.studentCode,
    this.room = 'N/A',
    this.groupName,
    this.status,
    this.fatherName = '',
    this.motherName = '',
    this.fatherPhone = '',
    this.motherPhone = '',
    this.extraFatherPhones = const [],
    this.extraMotherPhones = const [],
    this.anniversaryDate = '',
    this.alreadySentToday = false,
  });

  factory AnniversaryStudentRecord.fromJson(Map<String, dynamic> json) {
    final rawExtrasFather = json['extraFatherPhones'] ?? json['extra_father_phones'];
    final rawExtrasMother = json['extraMotherPhones'] ?? json['extra_mother_phones'];

    List<ParentAdditionalPhone> parsePhones(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => ParentAdditionalPhone.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return const [];
    }

    return AnniversaryStudentRecord(
      studentId: json['studentId'] is int
          ? json['studentId']
          : int.tryParse('${json['studentId'] ?? json['student_id']}') ?? 0,
      name: (json['name'] ?? 'Student').toString(),
      studentCode: (json['studentCode'] ?? json['student_code'] ?? '').toString(),
      room: (json['room'] ?? json['room_number'] ?? 'N/A').toString(),
      groupName: _textOrNull(json['groupName'] ?? json['group_name']),
      status: _textOrNull(json['status'] ?? json['student_status']),
      fatherName: (json['fatherName'] ?? json['father_name'] ?? '').toString(),
      motherName: (json['motherName'] ?? json['mother_name'] ?? '').toString(),
      fatherPhone: (json['fatherPhone'] ?? json['father_phone'] ?? '').toString(),
      motherPhone: (json['motherPhone'] ?? json['mother_phone'] ?? '').toString(),
      extraFatherPhones: parsePhones(rawExtrasFather),
      extraMotherPhones: parsePhones(rawExtrasMother),
      anniversaryDate: json['anniversaryDate'] != null
          ? '${json['anniversaryDate']}'.split('T').first
          : (json['parents_anniversary'] != null ? '${json['parents_anniversary']}'.split('T').first : ''),
      alreadySentToday: json['alreadySentToday'] == true || json['already_sent_today'] == 1,
    );
  }

  static String? _textOrNull(dynamic v) {
    final text = v?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// Combined formatted parents name string (e.g., "Mr. Ramesh & Mrs. Sunita Patel").
  String get parentsNames {
    final f = fatherName.trim();
    final m = motherName.trim();
    if (f.isNotEmpty && m.isNotEmpty) {
      return '$f & $m';
    }
    if (f.isNotEmpty) return f;
    if (m.isNotEmpty) return m;
    return 'Parents of $name';
  }

  /// Sanitized digits only for Father.
  String get cleanFatherPhone => fatherPhone.replaceAll(RegExp(r'\D'), '');

  /// Sanitized digits only for Mother.
  String get cleanMotherPhone => motherPhone.replaceAll(RegExp(r'\D'), '');

  bool get hasFatherPhone => cleanFatherPhone.length >= 6;
  bool get hasMotherPhone => cleanMotherPhone.length >= 6;
  bool get hasAnyPhone => hasFatherPhone || hasMotherPhone;

  /// Years of marriage completed (e.g. 25).
  int? get yearsOfMarriage {
    if (anniversaryDate.length >= 4) {
      final year = int.tryParse(anniversaryDate.substring(0, 4));
      if (year != null && year > 1900) {
        final currentYear = DateTime.now().year;
        final diff = currentYear - year;
        if (diff >= 0 && diff < 120) return diff;
      }
    }
    return null;
  }

  /// Label for marriage milestone (e.g., "25th Anniversary", "Silver Jubilee (25th)").
  String get yearsMilestoneLabel {
    final y = yearsOfMarriage;
    if (y == null || y <= 0) return 'Marriage Anniversary';
    String suffix = 'th';
    if (y % 10 == 1 && y % 100 != 11) {
      suffix = 'st';
    } else if (y % 10 == 2 && y % 100 != 12) {
      suffix = 'nd';
    } else if (y % 10 == 3 && y % 100 != 13) {
      suffix = 'rd';
    }

    if (y == 25) return 'Silver Jubilee (25th)';
    if (y == 50) return 'Golden Jubilee (50th)';
    if (y == 60) return 'Diamond Jubilee (60th)';
    return '$y$suffix Anniversary';
  }

  /// Same rule as birthday/phonebook for alumni.
  bool get isAlumni {
    final r = room.toLowerCase().trim();
    return r.isEmpty || r == 'n/a' || r == 'alumni' || BirthdayStudentModel.statusMeansAlumni(status);
  }
}

/// Settings and template configuration for Parents' Anniversary automation.
class AnniversaryConfigModel {
  final bool anniversaryEnabled;
  final String sendTime;
  final String anniversaryMessageTemplate;
  final String? anniversaryLastRunDate;
  final String? imageUrl;

  const AnniversaryConfigModel({
    this.anniversaryEnabled = true,
    this.sendTime = '08:30',
    this.anniversaryMessageTemplate =
        'Dear {parents_names}, 💍🎉 Wishing you a very Happy Marriage Anniversary from Hari Saurabh Hostel family! May your bond always be blessed with love, good health, and lifelong happiness! 🌟✨ - HSH Warden Team',
    this.anniversaryLastRunDate,
    this.imageUrl,
  });

  factory AnniversaryConfigModel.fromJson(Map<String, dynamic> json) {
    return AnniversaryConfigModel(
      anniversaryEnabled: json['anniversaryEnabled'] == true ||
          json['anniversary_enabled'] == 1 ||
          json['isEnabled'] == true ||
          json['is_enabled'] == 1,
      sendTime: json['sendTime'] ?? json['send_time'] ?? '08:30',
      anniversaryMessageTemplate: json['anniversaryMessageTemplate'] ??
          json['anniversary_message_template'] ??
          json['messageTemplate'] ??
          'Dear {parents_names}, 💍🎉 Wishing you a very Happy Marriage Anniversary from Hari Saurabh Hostel family! May your bond always be blessed with love, good health, and lifelong happiness! 🌟✨ - HSH Warden Team',
      anniversaryLastRunDate: json['anniversaryLastRunDate'] != null
          ? '${json['anniversaryLastRunDate']}'.split('T').first
          : null,
      imageUrl: json['imageUrl'] ?? json['image_url'],
    );
  }

  Map<String, dynamic> toJson() => {
        'anniversaryEnabled': anniversaryEnabled,
        'sendTime': sendTime,
        'anniversaryMessageTemplate': anniversaryMessageTemplate,
        'imageUrl': imageUrl,
      };

  AnniversaryConfigModel copyWith({
    bool? anniversaryEnabled,
    String? sendTime,
    String? anniversaryMessageTemplate,
    String? anniversaryLastRunDate,
    String? imageUrl,
  }) {
    return AnniversaryConfigModel(
      anniversaryEnabled: anniversaryEnabled ?? this.anniversaryEnabled,
      sendTime: sendTime ?? this.sendTime,
      anniversaryMessageTemplate: anniversaryMessageTemplate ?? this.anniversaryMessageTemplate,
      anniversaryLastRunDate: anniversaryLastRunDate ?? this.anniversaryLastRunDate,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// Full dashboard payload returned by `GET /api/whatsapp/anniversary`.
class AnniversaryDashboardData {
  final AnniversaryConfigModel config;
  final List<AnniversaryStudentRecord> todaysAnniversaries;
  final List<AnniversaryStudentRecord> tomorrowsAnniversaries;
  final List<BirthdayLogModel> recentLogs;
  final bool isWhatsAppConnected;
  final String? senderPhone;
  final bool isLeader;
  final String? leaderGroup;

  const AnniversaryDashboardData({
    required this.config,
    required this.todaysAnniversaries,
    required this.tomorrowsAnniversaries,
    required this.recentLogs,
    required this.isWhatsAppConnected,
    this.senderPhone,
    this.isLeader = false,
    this.leaderGroup,
  });

  factory AnniversaryDashboardData.fromJson(Map<String, dynamic> json) {
    final cfg = json['config'] is Map
        ? AnniversaryConfigModel.fromJson(Map<String, dynamic>.from(json['config']))
        : const AnniversaryConfigModel();

    final todayList = (json['todaysAnniversaries'] as List?)
            ?.map((e) => AnniversaryStudentRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    final tomorrowList = (json['tomorrowsAnniversaries'] as List?)
            ?.map((e) => AnniversaryStudentRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    final logsList = (json['recentLogs'] as List?)
            ?.map((e) => BirthdayLogModel.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    return AnniversaryDashboardData(
      config: cfg,
      todaysAnniversaries: todayList,
      tomorrowsAnniversaries: tomorrowList,
      recentLogs: logsList,
      isWhatsAppConnected: json['isWhatsAppConnected'] == true,
      senderPhone: json['senderPhone']?.toString(),
      isLeader: json['isLeader'] == true,
      leaderGroup: json['leaderGroup']?.toString(),
    );
  }
}
