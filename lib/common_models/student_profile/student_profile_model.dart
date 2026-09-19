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

  /// `GET /students/:aadhar` → `data.student` (API_HANDOFF.md §5.1). Every
  /// field is defaulted so a sparse response (or one missing a field this
  /// app doesn't know about yet) never throws.
  /// Parses the backend `data.student` object from GET /students/:aadhar.
  ///
  /// Key mappings (backend → model):
  ///   whatsAppNumber → whatsappNumber
  ///   cricket        → playsCricket
  ///   badminton      → playsBadminton
  ///   gym            → goesToGym
  ///   status string  → AdmissionStatus enum
  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentProfileModel(
      aadhar: json['aadhar']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      middleName: json['middleName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      whatsappNumber: json['whatsAppNumber']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      room: json['room']?.toString() ?? '',
      status: _statusFromApi(json['status']?.toString()),
      subStatus: json['subStatus']?.toString() ?? '',
      bloodGroup: json['bloodGroup']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      pinCode: json['pinCode']?.toString() ?? '',
      fatherFirstName: json['fatherFirstName']?.toString() ?? '',
      fatherPhone: json['fatherPhone']?.toString() ?? '',
      fatherProfession: json['fatherProfession']?.toString() ?? '',
      motherFirstName: json['motherFirstName']?.toString() ?? '',
      motherPhone: json['motherPhone']?.toString() ?? '',
      playsCricket: json['cricket'] as bool? ?? false,
      playsBadminton: json['badminton'] as bool? ?? false,
      goesToGym: json['gym'] as bool? ?? false,
      vehicleNumber: json['vehicleNumber']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      groupName: json['groupName']?.toString() ?? '',
      bankCode: json['bankCode']?.toString() ?? '',
      bankCodeChecked: json['bankCodeChecked'] as bool? ?? false,
      notes: json['notes']?.toString() ?? '',
    );
  }

  static AdmissionStatus _statusFromApi(String? value) {
    switch (value) {
      case 'staying':
      case 'active':
        return AdmissionStatus.active;
      case 'left':
        return AdmissionStatus.left;
      case 'pending':
      case 'pendingApproval':
        return AdmissionStatus.pendingApproval;
      default:
        return AdmissionStatus.active;
    }
  }

  /// Fields a student is never allowed to edit on their own profile
  /// (API_HANDOFF.md §5.2). `firstName`/`middleName`/`lastName` are included
  /// too: the backend's update allow-list doesn't mention them, so a name
  /// change would silently be dropped — better to show them as read-only
  /// than let a student believe an edit was saved.
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
    'firstName',
    'middleName',
    'lastName',
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

  /// Same allow-list the backend accepts on `PATCH /students/:aadhar`
  /// (API_HANDOFF.md §5.2), keyed by the API's own field names. Lets any
  /// code already holding a full [StudentProfileModel] (e.g. an operator
  /// edit flow) build a safe update payload without hand-picking fields.
  Map<String, dynamic> toUpdateJson() => {
    'whatsAppNumber': whatsappNumber,
    'phone': phone,
    'address': address,
    'pinCode': pinCode,
    'bloodGroup': bloodGroup,
    'fatherFirstName': fatherFirstName,
    'fatherPhone': fatherPhone,
    'fatherProfession': fatherProfession,
    'motherFirstName': motherFirstName,
    'motherPhone': motherPhone,
    'cricket': playsCricket,
    'badminton': playsBadminton,
    'gym': goesToGym,
    'vehicleNumber': vehicleNumber,
  };
}
