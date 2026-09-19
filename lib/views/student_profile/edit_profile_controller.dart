import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_models/student_profile/student_profile_model.dart';
import '../../network/api_exception.dart';
import '../../network/repository/student_profile/student_profile_repository.dart';
import '../../network/request/student_profile/update_profile_request.dart';

class EditProfileController extends GetxController {
  final StudentProfileRepository _repository = Get.find();

  late final StudentProfileModel initialProfile =
      Get.arguments as StudentProfileModel;

  // Name fields are display-only — the backend's update allow-list doesn't
  // include them (see StudentProfileModel.studentBlockedFields), so these
  // controllers exist only to show the current value, never to send it.
  late final firstNameController = TextEditingController(
    text: initialProfile.firstName,
  );
  late final middleNameController = TextEditingController(
    text: initialProfile.middleName,
  );
  late final lastNameController = TextEditingController(
    text: initialProfile.lastName,
  );
  late final phoneController = TextEditingController(
    text: initialProfile.phone,
  );
  late final whatsappController = TextEditingController(
    text: initialProfile.whatsappNumber,
  );
  late final bloodGroupController = TextEditingController(
    text: initialProfile.bloodGroup,
  );
  late final addressController = TextEditingController(
    text: initialProfile.address,
  );
  late final pinCodeController = TextEditingController(
    text: initialProfile.pinCode,
  );
  late final fatherNameController = TextEditingController(
    text: initialProfile.fatherFirstName,
  );
  late final fatherPhoneController = TextEditingController(
    text: initialProfile.fatherPhone,
  );
  late final fatherProfessionController = TextEditingController(
    text: initialProfile.fatherProfession,
  );
  late final motherNameController = TextEditingController(
    text: initialProfile.motherFirstName,
  );
  late final motherPhoneController = TextEditingController(
    text: initialProfile.motherPhone,
  );
  late final vehicleNumberController = TextEditingController(
    text: initialProfile.vehicleNumber,
  );

  late final RxBool playsCricket = initialProfile.playsCricket.obs;
  late final RxBool playsBadminton = initialProfile.playsBadminton.obs;
  late final RxBool goesToGym = initialProfile.goesToGym.obs;

  final isSaving = false.obs;

  bool isEditable(String fieldKey) =>
      StudentProfileModel.isEditableByStudent(fieldKey);

  @override
  void onClose() {
    for (final c in [
      firstNameController,
      middleNameController,
      lastNameController,
      phoneController,
      whatsappController,
      bloodGroupController,
      addressController,
      pinCodeController,
      fatherNameController,
      fatherPhoneController,
      fatherProfessionController,
      motherNameController,
      motherPhoneController,
      vehicleNumberController,
    ]) {
      c.dispose();
    }
    super.onClose();
  }

  Future<void> save() async {
    isSaving.value = true;
    try {
      await _repository.updateProfile(
        initialProfile.aadhar,
        UpdateProfileRequest(
          phone: phoneController.text.trim(),
          whatsappNumber: whatsappController.text.trim(),
          bloodGroup: bloodGroupController.text.trim(),
          address: addressController.text.trim(),
          pinCode: pinCodeController.text.trim(),
          fatherFirstName: fatherNameController.text.trim(),
          fatherPhone: fatherPhoneController.text.trim(),
          fatherProfession: fatherProfessionController.text.trim(),
          motherFirstName: motherNameController.text.trim(),
          motherPhone: motherPhoneController.text.trim(),
          playsCricket: playsCricket.value,
          playsBadminton: playsBadminton.value,
          goesToGym: goesToGym.value,
          vehicleNumber: vehicleNumberController.text.trim(),
        ),
      );
      Get.back(result: true);
      Get.snackbar('Success', 'Profile updated successfully');
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      isSaving.value = false;
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Update Failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
    );
  }
}
