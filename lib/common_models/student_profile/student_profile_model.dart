import '../../common_enums/admission_status.dart';

/// Shared student profile model — used by the student's own Profile screen
/// and by the operator directory/admin edit screens alike.
class StudentProfileModel {
  final String aadhar;
  final String firstName;
  final String middleName;
  final String lastName;
  final String phone;
  final String whatsappNumber;
  final String email;
  final String room;
  final AdmissionStatus status;
  final String subStatus;
  final String bloodGroup;

  final String address;
  final String pinCode;

  final String fatherFirstName;
  final String fatherPhone;
  final String fatherProfession;
  final String motherFirstName;
  final String motherPhone;

  final bool playsCricket;
  final bool playsBadminton;
  final bool goesToGym;

  final String vehicleNumber;

  final String category;
  final String groupName;
  final String bankCode;
  final bool bankCodeChecked;
  final String notes;

  const StudentProfileModel({
    required this.aadhar,
    required this.firstName,
    this.middleName = '',
    required this.lastName,
    required this.phone,
    this.whatsappNumber = '',
    required this.email,
    required this.room,
    this.status = AdmissionStatus.active,
    this.subStatus = '',
    this.bloodGroup = '',
    this.address = '',
    this.pinCode = '',
    this.fatherFirstName = '',
    this.fatherPhone = '',
    this.fatherProfession = '',
    this.motherFirstName = '',
    this.motherPhone = '',
    this.playsCricket = false,
    this.playsBadminton = false,
    this.goesToGym = false,
    this.vehicleNumber = '',
    this.category = '',
    this.groupName = '',
    this.bankCode = '',
    this.bankCodeChecked = false,
    this.notes = '',
  });

  String get fullName => [
    firstName,
    middleName,
    lastName,
  ].where((e) => e.trim().isNotEmpty).join(' ');

  /// Fields a student is never allowed to edit on their own profile (spec
  /// §5.3 / §7.3). Reused by both the student edit form (disables these
  /// inputs) and, eventually, request-building code (never sends these
  /// as student-initiated changes).
  static const Set<String> studentBlockedFields = {
    'aadhar',
    'email',
    'status',
    'subStatus',
    'room',
    'category',
    'groupName',
    'bankCode',
    'bankCodeChecked',
    'notes',
  };

  static bool isEditableByStudent(String fieldKey) =>
      !studentBlockedFields.contains(fieldKey);

  StudentProfileModel copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? phone,
    String? whatsappNumber,
    String? bloodGroup,
    String? address,
    String? pinCode,
    String? fatherFirstName,
    String? fatherPhone,
    String? fatherProfession,
    String? motherFirstName,
    String? motherPhone,
    bool? playsCricket,
    bool? playsBadminton,
    bool? goesToGym,
    String? vehicleNumber,
  }) {
    return StudentProfileModel(
      aadhar: aadhar,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      email: email,
      room: room,
      status: status,
      subStatus: subStatus,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
      pinCode: pinCode ?? this.pinCode,
      fatherFirstName: fatherFirstName ?? this.fatherFirstName,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      fatherProfession: fatherProfession ?? this.fatherProfession,
      motherFirstName: motherFirstName ?? this.motherFirstName,
      motherPhone: motherPhone ?? this.motherPhone,
      playsCricket: playsCricket ?? this.playsCricket,
      playsBadminton: playsBadminton ?? this.playsBadminton,
      goesToGym: goesToGym ?? this.goesToGym,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      category: category,
      groupName: groupName,
      bankCode: bankCode,
      bankCodeChecked: bankCodeChecked,
      notes: notes,
    );
  }

  factory StudentProfileModel.mock({String? aadhar, String? room}) {
    return StudentProfileModel(
      aadhar: aadhar ?? '123456789012',
      firstName: 'Krutarth',
      middleName: 'B',
      lastName: 'Solanki',
      phone: '9876543210',
      whatsappNumber: '9876543210',
      email: 'krutarth.solanki@example.com',
      room: room ?? 'A-204',
      status: AdmissionStatus.active,
      bloodGroup: 'O+',
      address: '12, Shanti Nagar Society, Ahmedabad',
      pinCode: '380001',
      fatherFirstName: 'Bharat',
      fatherPhone: '9898989898',
      fatherProfession: 'Business',
      motherFirstName: 'Kajal',
      motherPhone: '9797979797',
      playsCricket: true,
      playsBadminton: false,
      goesToGym: true,
      vehicleNumber: 'GJ01AB1234',
      category: 'General',
      groupName: 'Group A',
      bankCode: 'HDFC0001234',
      bankCodeChecked: true,
      notes: 'No remarks.',
    );
  }
}
