/// Only fields a student is allowed to self-edit are sent here — see
/// StudentProfileModel.studentBlockedFields for what's excluded. Notably,
/// this doesn't include name fields: the backend's update allow-list
/// (API_HANDOFF.md §5.2) doesn't mention them either.
class UpdateProfileRequest {
  final String phone;
  final String whatsappNumber;
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

  const UpdateProfileRequest({
    required this.phone,
    required this.whatsappNumber,
    required this.bloodGroup,
    required this.address,
    required this.pinCode,
    required this.fatherFirstName,
    required this.fatherPhone,
    required this.fatherProfession,
    required this.motherFirstName,
    required this.motherPhone,
    required this.playsCricket,
    required this.playsBadminton,
    required this.goesToGym,
    required this.vehicleNumber,
  });

  /// Keys match exactly what `PATCH /students/:aadhar` accepts.
  Map<String, dynamic> toJson() => {
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
