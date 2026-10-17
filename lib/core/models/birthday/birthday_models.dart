class BirthdayConfigModel {
  final int id;
  final bool isEnabled;
  final String sendTime;
  final String targetAudience;
  final bool preferWhatsAppNumber;
  final String? adminNotificationPhone;
  final String messageTemplate;
  final String? imageUrl;
  final String? lastRunDate;

  const BirthdayConfigModel({
    this.id = 1,
    this.isEnabled = true,
    this.sendTime = '08:00',
    this.targetAudience = 'student_only',
    this.preferWhatsAppNumber = true,
    this.adminNotificationPhone,
    this.messageTemplate =
        'Dear {student_name}, 🎂🎉 Wishing you a very Happy Birthday from Hari Saurabh Hostel family! May your special day bring you immense joy, good health, and success! 🌟✨ - HSH Warden Team',
    this.imageUrl,
    this.lastRunDate,
  });

  factory BirthdayConfigModel.fromJson(Map<String, dynamic> json) {
    return BirthdayConfigModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 1,
      isEnabled: json['isEnabled'] == true || json['is_enabled'] == 1 || json['isEnabled'] == 1,
      sendTime: json['sendTime'] ?? json['send_time'] ?? '08:00',
      targetAudience: json['targetAudience'] ?? json['target_audience'] ?? 'student_only',
      preferWhatsAppNumber: json['preferWhatsAppNumber'] == true ||
          json['prefer_whatsapp_number'] == 1 ||
          json['preferWhatsAppNumber'] == 1,
      adminNotificationPhone: json['adminNotificationPhone'] ?? json['admin_notification_phone'],
      messageTemplate: json['messageTemplate'] ?? json['message_template'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'],
      lastRunDate: json['lastRunDate'] != null ? '${json['lastRunDate']}'.split('T').first : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'sendTime': sendTime,
      'targetAudience': targetAudience,
      'preferWhatsAppNumber': preferWhatsAppNumber,
      'adminNotificationPhone': adminNotificationPhone,
      'messageTemplate': messageTemplate,
      'imageUrl': imageUrl,
    };
  }

  BirthdayConfigModel copyWith({
    bool? isEnabled,
    String? sendTime,
    String? targetAudience,
    bool? preferWhatsAppNumber,
    String? adminNotificationPhone,
    String? messageTemplate,
    String? imageUrl,
  }) {
    return BirthdayConfigModel(
      id: id,
      isEnabled: isEnabled ?? this.isEnabled,
      sendTime: sendTime ?? this.sendTime,
      targetAudience: targetAudience ?? this.targetAudience,
      preferWhatsAppNumber: preferWhatsAppNumber ?? this.preferWhatsAppNumber,
      adminNotificationPhone: adminNotificationPhone ?? this.adminNotificationPhone,
      messageTemplate: messageTemplate ?? this.messageTemplate,
      imageUrl: imageUrl ?? this.imageUrl,
      lastRunDate: lastRunDate,
    );
  }
}

class BirthdayStudentModel {
  final int studentId;
  final String name;
  final String studentCode;
  final String phone;
  final String whatsappNumber;
  final String parentPhone;
  final String room;
  final String dob;
  final bool alreadySentToday;
  final bool isActive;

  const BirthdayStudentModel({
    required this.studentId,
    required this.name,
    required this.studentCode,
    this.phone = '',
    this.whatsappNumber = '',
    this.parentPhone = '',
    this.room = 'N/A',
    this.dob = '',
    this.alreadySentToday = false,
    this.isActive = true,
  });

  factory BirthdayStudentModel.fromJson(Map<String, dynamic> json) {
    return BirthdayStudentModel(
      studentId: json['studentId'] is int
          ? json['studentId']
          : int.tryParse('${json['studentId'] ?? json['student_id']}') ?? 0,
      name: (json['name'] ?? 'Student').toString(),
      studentCode: (json['studentCode'] ?? json['student_code'] ?? '').toString(),
      phone: (json['phone'] ?? json['phone_number'] ?? '').toString(),
      whatsappNumber: (json['whatsappNumber'] ?? json['whatsapp_number'] ?? json['phone'] ?? '').toString(),
      parentPhone: (json['parentPhone'] ?? json['parent_phone'] ?? '').toString(),
      room: (json['room'] ?? json['room_number'] ?? 'N/A').toString(),
      dob: json['dob'] != null ? '${json['dob']}'.split('T').first : '',
      alreadySentToday: json['alreadySentToday'] == true || json['already_sent_today'] == 1,
      isActive: json['isActive'] != false && json['is_active'] != 0,
    );
  }
}

class BirthdayLogModel {
  final int id;
  final int studentId;
  final String studentName;
  final String studentCode;
  final String room;
  final String wishDate;
  final String phone;
  final String recipientType;
  final String message;
  final String status;
  final String sentAt;

  const BirthdayLogModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.room,
    required this.wishDate,
    required this.phone,
    required this.recipientType,
    required this.message,
    required this.status,
    required this.sentAt,
  });

  factory BirthdayLogModel.fromJson(Map<String, dynamic> json) {
    return BirthdayLogModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      studentId: json['studentId'] is int
          ? json['studentId']
          : int.tryParse('${json['studentId'] ?? json['student_id']}') ?? 0,
      studentName: (json['studentName'] ?? json['student_name'] ?? 'Student').toString(),
      studentCode: (json['studentCode'] ?? json['student_code'] ?? '').toString(),
      room: (json['room'] ?? json['room_number'] ?? 'N/A').toString(),
      wishDate: json['wishDate'] != null ? '${json['wishDate']}'.split('T').first : '',
      phone: (json['phone'] ?? '').toString(),
      recipientType: (json['recipientType'] ?? json['recipient_type'] ?? 'student').toString(),
      message: (json['message'] ?? '').toString(),
      status: (json['status'] ?? 'sent').toString(),
      sentAt: (json['sentAt'] ?? json['sent_at'] ?? '').toString(),
    );
  }

  bool get isSent => status.toLowerCase() == 'sent';
}

class BirthdayDashboardData {
  final BirthdayConfigModel config;
  final List<BirthdayStudentModel> todaysBirthdays;
  final List<BirthdayStudentModel> tomorrowsBirthdays;
  final List<BirthdayLogModel> recentLogs;
  final bool isWhatsAppConnected;
  final String? senderPhone;

  const BirthdayDashboardData({
    required this.config,
    required this.todaysBirthdays,
    required this.tomorrowsBirthdays,
    required this.recentLogs,
    required this.isWhatsAppConnected,
    this.senderPhone,
  });

  factory BirthdayDashboardData.fromJson(Map<String, dynamic> json) {
    final cfg = json['config'] is Map
        ? BirthdayConfigModel.fromJson(Map<String, dynamic>.from(json['config']))
        : const BirthdayConfigModel();
    final todayList = (json['todaysBirthdays'] as List?)
            ?.map((e) => BirthdayStudentModel.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    final tomorrowList = (json['tomorrowsBirthdays'] as List?)
            ?.map((e) => BirthdayStudentModel.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    final logsList = (json['recentLogs'] as List?)
            ?.map((e) => BirthdayLogModel.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    return BirthdayDashboardData(
      config: cfg,
      todaysBirthdays: todayList,
      tomorrowsBirthdays: tomorrowList,
      recentLogs: logsList,
      isWhatsAppConnected: json['isWhatsAppConnected'] == true,
      senderPhone: json['senderPhone']?.toString(),
    );
  }
}
