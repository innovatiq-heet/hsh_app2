import '../../enums/admission_status.dart';

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
  final String dob;

  final String address;
  final String pinCode;
  final String city;
  final String district;
  final String state;

  final String fatherFirstName;
  final String fatherMiddleName;
  final String fatherLastName;
  final String fatherPhone;
  final String fatherProfession;
  final String fatherBusiness;
  final String fatherDob;
  final String motherFirstName;
  final String motherMiddleName;
  final String motherLastName;
  final String motherPhone;
  final String motherBusiness;
  final String motherDob;
  final String anniversary;

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
    this.dob = '',
    this.address = '',
    this.pinCode = '',
    this.city = '',
    this.district = '',
    this.state = '',
    this.fatherFirstName = '',
    this.fatherMiddleName = '',
    this.fatherLastName = '',
    this.fatherPhone = '',
    this.fatherProfession = '',
    this.fatherBusiness = '',
    this.fatherDob = '',
    this.motherFirstName = '',
    this.motherMiddleName = '',
    this.motherLastName = '',
    this.motherPhone = '',
    this.motherBusiness = '',
    this.motherDob = '',
    this.anniversary = '',
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

  String get fatherFullName {
    final parts = [fatherFirstName, fatherMiddleName, fatherLastName]
        .where((e) => e.trim().isNotEmpty)
        .join(' ');
    return parts.isNotEmpty ? parts : fatherFirstName;
  }

  String get motherFullName {
    final parts = [motherFirstName, motherMiddleName, motherLastName]
        .where((e) => e.trim().isNotEmpty)
        .join(' ');
    return parts.isNotEmpty ? parts : motherFirstName;
  }

  String get anniversaryFormatted {
    if (anniversary.trim().isEmpty) return '';
    final ms = int.tryParse(anniversary.trim());
    if (ms != null && ms > 0) {
      try {
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        final y = dt.year.toString().padLeft(4, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      } catch (_) {}
    }
    return anniversary.trim();
  }

  String get hometown {
    final seen = <String>{};
    final parts = <String>[];
    for (final s in [city, district, state]) {
      final trimmed = s.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed.toLowerCase())) {
        parts.add(trimmed);
      }
    }
    return parts.join(', ');
  }

  /// Parses student data from backend or external AVD API.
  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentProfileModel(
      aadhar: json['aadhar']?.toString().trim() ?? '',
      firstName: json['firstName']?.toString().trim() ?? '',
      middleName: json['middleName']?.toString().trim() ?? '',
      lastName: json['lastName']?.toString().trim() ?? '',
      phone: json['phone']?.toString().trim() ??
          json['phone_number']?.toString().trim() ??
          '',
      whatsappNumber: json['whatsAppNumber']?.toString().trim() ??
          json['whatsappNumber']?.toString().trim() ??
          json['whats_app_number']?.toString().trim() ??
          '',
      email: json['email']?.toString().trim() ?? '',
      room: json['room']?.toString().trim() ??
          json['room_number']?.toString().trim() ??
          '',
      status: statusFromApi(json['status']?.toString()),
      subStatus: json['subStatus']?.toString().trim() ?? '',
      bloodGroup: json['bloodGroup']?.toString().trim() ??
          json['blood_group']?.toString().trim() ??
          '',
      dob: json['dob']?.toString().trim() ??
          json['date_of_birth']?.toString().trim() ??
          '',
      address: json['address']?.toString().trim() ?? '',
      pinCode: json['pinCode']?.toString().trim() ??
          json['pin_code']?.toString().trim() ??
          '',
      city: json['city']?.toString().trim() ??
          json['city_name']?.toString().trim() ??
          '',
      district: json['district']?.toString().trim() ?? '',
      state: json['state']?.toString().trim() ?? '',
      fatherFirstName: json['fatherFirstName']?.toString().trim() ?? '',
      fatherMiddleName: json['fatherMiddleName']?.toString().trim() ?? '',
      fatherLastName: json['fatherLastName']?.toString().trim() ?? '',
      fatherPhone: json['fatherPhone']?.toString().trim() ??
          json['father_phone']?.toString().trim() ??
          '',
      fatherProfession: json['fatherProfession']?.toString().trim() ??
          json['fatherBusiness']?.toString().trim() ??
          '',
      fatherBusiness: json['fatherBusiness']?.toString().trim() ??
          json['fatherProfession']?.toString().trim() ??
          '',
      fatherDob: json['fatherDob']?.toString().trim() ??
          json['father_dob']?.toString().trim() ??
          '',
      motherFirstName: json['motherFirstName']?.toString().trim() ?? '',
      motherMiddleName: json['motherMiddleName']?.toString().trim() ?? '',
      motherLastName: json['motherLastName']?.toString().trim() ?? '',
      motherPhone: json['motherPhone']?.toString().trim() ??
          json['mother_phone']?.toString().trim() ??
          '',
      motherBusiness: json['motherBusiness']?.toString().trim() ??
          json['mother_business']?.toString().trim() ??
          '',
      motherDob: json['motherDob']?.toString().trim() ??
          json['mother_dob']?.toString().trim() ??
          '',
      anniversary: json['anniversary']?.toString().trim() ?? '',
      playsCricket: json['cricket'] as bool? ?? false,
      playsBadminton: json['badminton'] as bool? ?? false,
      goesToGym: json['gym'] as bool? ?? false,
      vehicleNumber: json['vehicleNumber']?.toString().trim() ??
          json['vehicle_number']?.toString().trim() ??
          '',
      category: json['category']?.toString().trim() ?? '',
      groupName: json['groupName']?.toString().trim() ??
          json['group_name']?.toString().trim() ??
          '',
      bankCode: json['bankCode']?.toString().trim() ??
          json['bank_code']?.toString().trim() ??
          '',
      bankCodeChecked: json['bankCodeChecked'] as bool? ?? false,
      notes: json['notes']?.toString().trim() ?? '',
    );
  }

  /// Creates a fallback profile from basic session or lookup information
  /// (e.g. for alumni or newly admitted students prior to room allocation).
  factory StudentProfileModel.fallback({
    required String name,
    required String bankCode,
    required String phone,
    required String email,
    String room = '',
    String aadhar = '',
  }) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return StudentProfileModel(
      aadhar: aadhar,
      firstName: first,
      lastName: last,
      phone: phone,
      email: email,
      room: room,
      bankCode: bankCode,
    );
  }

  static AdmissionStatus statusFromApi(String? value) {
    final lower = value?.toLowerCase().trim();
    switch (lower) {
      case 'staying':
      case 'active':
      case 'renewed-admission':
      case 'new-admission':
        return AdmissionStatus.active;
      case 'left':
      case 'rejected-admission':
        return AdmissionStatus.left;
      case 'pending':
      case 'pendingapproval':
      case 'pending-admission':
        return AdmissionStatus.pendingApproval;
      default:
        return AdmissionStatus.active;
    }
  }

  StudentProfileModel mergeWith(StudentProfileModel other) {
    return StudentProfileModel(
      aadhar: other.aadhar.isNotEmpty ? other.aadhar : aadhar,
      firstName: other.firstName.isNotEmpty ? other.firstName : firstName,
      middleName: other.middleName.isNotEmpty ? other.middleName : middleName,
      lastName: other.lastName.isNotEmpty ? other.lastName : lastName,
      phone: other.phone.isNotEmpty ? other.phone : phone,
      whatsappNumber: other.whatsappNumber.isNotEmpty
          ? other.whatsappNumber
          : whatsappNumber,
      email: other.email.isNotEmpty ? other.email : email,
      room: other.room.isNotEmpty ? other.room : room,
      status: other.status,
      subStatus: other.subStatus.isNotEmpty ? other.subStatus : subStatus,
      bloodGroup: other.bloodGroup.isNotEmpty ? other.bloodGroup : bloodGroup,
      dob: other.dob.isNotEmpty ? other.dob : dob,
      address: other.address.isNotEmpty ? other.address : address,
      pinCode: other.pinCode.isNotEmpty ? other.pinCode : pinCode,
      city: other.city.isNotEmpty ? other.city : city,
      district: other.district.isNotEmpty ? other.district : district,
      state: other.state.isNotEmpty ? other.state : state,
      fatherFirstName: other.fatherFirstName.isNotEmpty
          ? other.fatherFirstName
          : fatherFirstName,
      fatherMiddleName: other.fatherMiddleName.isNotEmpty
          ? other.fatherMiddleName
          : fatherMiddleName,
      fatherLastName: other.fatherLastName.isNotEmpty
          ? other.fatherLastName
          : fatherLastName,
      fatherPhone: other.fatherPhone.isNotEmpty
          ? other.fatherPhone
          : fatherPhone,
      fatherProfession: other.fatherProfession.isNotEmpty
          ? other.fatherProfession
          : fatherProfession,
      fatherBusiness: other.fatherBusiness.isNotEmpty
          ? other.fatherBusiness
          : fatherBusiness,
      fatherDob: other.fatherDob.isNotEmpty ? other.fatherDob : fatherDob,
      motherFirstName: other.motherFirstName.isNotEmpty
          ? other.motherFirstName
          : motherFirstName,
      motherMiddleName: other.motherMiddleName.isNotEmpty
          ? other.motherMiddleName
          : motherMiddleName,
      motherLastName: other.motherLastName.isNotEmpty
          ? other.motherLastName
          : motherLastName,
      motherPhone: other.motherPhone.isNotEmpty
          ? other.motherPhone
          : motherPhone,
      motherBusiness: other.motherBusiness.isNotEmpty
          ? other.motherBusiness
          : motherBusiness,
      motherDob: other.motherDob.isNotEmpty ? other.motherDob : motherDob,
      anniversary: other.anniversary.isNotEmpty
          ? other.anniversary
          : anniversary,
      playsCricket: other.playsCricket || playsCricket,
      playsBadminton: other.playsBadminton || playsBadminton,
      goesToGym: other.goesToGym || goesToGym,
      vehicleNumber: other.vehicleNumber.isNotEmpty
          ? other.vehicleNumber
          : vehicleNumber,
      category: other.category.isNotEmpty ? other.category : category,
      groupName: other.groupName.isNotEmpty ? other.groupName : groupName,
      bankCode: other.bankCode.isNotEmpty ? other.bankCode : bankCode,
      bankCodeChecked: other.bankCodeChecked || bankCodeChecked,
      notes: other.notes.isNotEmpty ? other.notes : notes,
    );
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
    String? aadhar,
    String? firstName,
    String? middleName,
    String? lastName,
    String? phone,
    String? whatsappNumber,
    String? email,
    String? room,
    AdmissionStatus? status,
    String? subStatus,
    String? bloodGroup,
    String? dob,
    String? address,
    String? pinCode,
    String? city,
    String? district,
    String? state,
    String? fatherFirstName,
    String? fatherMiddleName,
    String? fatherLastName,
    String? fatherPhone,
    String? fatherProfession,
    String? fatherBusiness,
    String? fatherDob,
    String? motherFirstName,
    String? motherMiddleName,
    String? motherLastName,
    String? motherPhone,
    String? motherBusiness,
    String? motherDob,
    String? anniversary,
    bool? playsCricket,
    bool? playsBadminton,
    bool? goesToGym,
    String? vehicleNumber,
    String? category,
    String? groupName,
    String? bankCode,
    bool? bankCodeChecked,
    String? notes,
  }) {
    return StudentProfileModel(
      aadhar: aadhar ?? this.aadhar,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      email: email ?? this.email,
      room: room ?? this.room,
      status: status ?? this.status,
      subStatus: subStatus ?? this.subStatus,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      dob: dob ?? this.dob,
      address: address ?? this.address,
      pinCode: pinCode ?? this.pinCode,
      city: city ?? this.city,
      district: district ?? this.district,
      state: state ?? this.state,
      fatherFirstName: fatherFirstName ?? this.fatherFirstName,
      fatherMiddleName: fatherMiddleName ?? this.fatherMiddleName,
      fatherLastName: fatherLastName ?? this.fatherLastName,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      fatherProfession: fatherProfession ?? this.fatherProfession,
      fatherBusiness: fatherBusiness ?? this.fatherBusiness,
      fatherDob: fatherDob ?? this.fatherDob,
      motherFirstName: motherFirstName ?? this.motherFirstName,
      motherMiddleName: motherMiddleName ?? this.motherMiddleName,
      motherLastName: motherLastName ?? this.motherLastName,
      motherPhone: motherPhone ?? this.motherPhone,
      motherBusiness: motherBusiness ?? this.motherBusiness,
      motherDob: motherDob ?? this.motherDob,
      anniversary: anniversary ?? this.anniversary,
      playsCricket: playsCricket ?? this.playsCricket,
      playsBadminton: playsBadminton ?? this.playsBadminton,
      goesToGym: goesToGym ?? this.goesToGym,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      category: category ?? this.category,
      groupName: groupName ?? this.groupName,
      bankCode: bankCode ?? this.bankCode,
      bankCodeChecked: bankCodeChecked ?? this.bankCodeChecked,
      notes: notes ?? this.notes,
    );
  }

  /// Full serialization for local cache persistence (SharedPreferences/SessionStore).
  Map<String, dynamic> toJson() => {
    'aadhar': aadhar,
    'firstName': firstName,
    'middleName': middleName,
    'lastName': lastName,
    'phone': phone,
    'whatsAppNumber': whatsappNumber,
    'email': email,
    'room': room,
    'status': status.name,
    'subStatus': subStatus,
    'bloodGroup': bloodGroup,
    'dob': dob,
    'address': address,
    'pinCode': pinCode,
    'city': city,
    'district': district,
    'state': state,
    'fatherFirstName': fatherFirstName,
    'fatherMiddleName': fatherMiddleName,
    'fatherLastName': fatherLastName,
    'fatherPhone': fatherPhone,
    'fatherProfession': fatherProfession,
    'fatherBusiness': fatherBusiness,
    'fatherDob': fatherDob,
    'motherFirstName': motherFirstName,
    'motherMiddleName': motherMiddleName,
    'motherLastName': motherLastName,
    'motherPhone': motherPhone,
    'motherBusiness': motherBusiness,
    'motherDob': motherDob,
    'anniversary': anniversary,
    'cricket': playsCricket,
    'badminton': playsBadminton,
    'gym': goesToGym,
    'vehicleNumber': vehicleNumber,
    'category': category,
    'groupName': groupName,
    'bankCode': bankCode,
    'bankCodeChecked': bankCodeChecked,
    'notes': notes,
  };

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
