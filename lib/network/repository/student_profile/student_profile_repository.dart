import '../../../common_models/student_profile/student_profile_model.dart';
import '../../../constants/app_config.dart';
import '../../request/student_profile/update_profile_request.dart';

class StudentProfileRepository {
  StudentProfileModel? _cached;

  Future<StudentProfileModel> fetchProfile(String aadhar) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    _cached ??= StudentProfileModel.mock(aadhar: aadhar);
    return _cached!;
  }

  Future<StudentProfileModel> updateProfile(
    String aadhar,
    UpdateProfileRequest request,
  ) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final current = _cached ?? StudentProfileModel.mock(aadhar: aadhar);
    _cached = current.copyWith(
      firstName: request.firstName,
      middleName: request.middleName,
      lastName: request.lastName,
      phone: request.phone,
      whatsappNumber: request.whatsappNumber,
      bloodGroup: request.bloodGroup,
      address: request.address,
      pinCode: request.pinCode,
      fatherFirstName: request.fatherFirstName,
      fatherPhone: request.fatherPhone,
      fatherProfession: request.fatherProfession,
      motherFirstName: request.motherFirstName,
      motherPhone: request.motherPhone,
      playsCricket: request.playsCricket,
      playsBadminton: request.playsBadminton,
      goesToGym: request.goesToGym,
      vehicleNumber: request.vehicleNumber,
    );
    return _cached!;
  }
}
