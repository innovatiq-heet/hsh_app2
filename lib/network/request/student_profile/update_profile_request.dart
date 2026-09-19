/// Only fields a student is allowed to self-edit are sent here — see
/// StudentProfileModel.studentBlockedFields for what's excluded.
class UpdateProfileRequest {
  final String firstName;
  final String middleName;
  final String lastName;
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
    required this.firstName,
    required this.middleName,
    required this.lastName,
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
}
