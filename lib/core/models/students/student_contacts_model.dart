class StudentAdditionalPhone {
  final int id;
  final int studentId;
  final String phone;
  final String phoneNormalized;
  final String label;
  final bool isPrimary;
  final bool isWhatsApp;
  final bool isPrimaryWhatsApp;
  final String? createdAt;
  final String? updatedAt;

  const StudentAdditionalPhone({
    required this.id,
    required this.studentId,
    required this.phone,
    required this.phoneNormalized,
    required this.label,
    this.isPrimary = false,
    this.isWhatsApp = false,
    this.isPrimaryWhatsApp = false,
    this.createdAt,
    this.updatedAt,
  });

  factory StudentAdditionalPhone.fromJson(Map<String, dynamic> json) {
    return StudentAdditionalPhone(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      studentId: int.tryParse(json['student_id']?.toString() ?? '0') ?? 0,
      phone: json['phone']?.toString() ?? '',
      phoneNormalized: json['phone_normalized']?.toString() ??
          json['phone']?.toString() ??
          '',
      label: json['label']?.toString() ?? 'Mobile',
      isPrimary: json['is_primary'] == 1 || json['is_primary'] == true,
      isWhatsApp: json['is_whatsapp'] == 1 || json['is_whatsapp'] == true,
      isPrimaryWhatsApp: json['is_primary_whatsapp'] == 1 ||
          json['is_primary_whatsapp'] == true,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'phone': phone,
        'phone_normalized': phoneNormalized,
        'label': label,
        'is_primary': isPrimary,
        'is_whatsapp': isWhatsApp,
        'is_primary_whatsapp': isPrimaryWhatsApp,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class StudentContactsData {
  final int studentId;
  final String name;
  final String? primaryPhone;
  final String? whatsappNumber;
  final String? fatherPhone;
  final String? motherPhone;
  final List<StudentAdditionalPhone> additionalContacts;

  const StudentContactsData({
    required this.studentId,
    required this.name,
    this.primaryPhone,
    this.whatsappNumber,
    this.fatherPhone,
    this.motherPhone,
    required this.additionalContacts,
  });

  factory StudentContactsData.fromJson(Map<String, dynamic> json) {
    final base = (json['base_contacts'] is Map)
        ? Map<String, dynamic>.from(json['base_contacts'] as Map)
        : <String, dynamic>{};

    final addList = <StudentAdditionalPhone>[];
    final rawAdditional = json['additional_contacts'] ?? json['additional_phones'];
    if (rawAdditional is List) {
      for (final item in rawAdditional) {
        if (item is Map) {
          addList.add(
            StudentAdditionalPhone.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return StudentContactsData(
      studentId: int.tryParse(json['student_id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      primaryPhone: (base['primary_phone'] ?? json['primary_phone'])?.toString(),
      whatsappNumber:
          (base['whatsapp_number'] ?? json['whatsapp_number'])?.toString(),
      fatherPhone: (base['father_phone'] ?? json['father_phone'])?.toString(),
      motherPhone: (base['mother_phone'] ?? json['mother_phone'])?.toString(),
      additionalContacts: addList,
    );
  }
}
