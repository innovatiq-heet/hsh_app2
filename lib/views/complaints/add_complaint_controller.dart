import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../abstracts/mixins/aadhar_resolving_mixin.dart';
import '../../network/api_exception.dart';
import '../../network/repository/complaints/complaints_repository.dart';
import '../../network/repository/fees/fees_repository.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/request/complaints/submit_complaint_request.dart';
import '../student_profile/student_profile_controller.dart';

class AddComplaintController extends GetxController with AadharResolvingMixin {
  final ComplaintsRepository _repository = Get.find();
  final FeesRepository _feesRepository = Get.find();
  final LaundryRepository _laundryRepository = Get.find();

  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  final categories = <String>[].obs;
  final Rxn<String> selectedCategory = Rxn<String>();
  final images = <File>[].obs;
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadCategories();
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }

  Future<void> loadCategories() async {
    categories.assignAll(await _repository.categories());
    if (categories.isNotEmpty) selectedCategory.value = categories.first;
  }

  Future<void> pickImage() => pickImageFromSource(ImageSource.gallery);

  Future<void> pickImageFromSource(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked != null) images.add(File(picked.path));
  }

  void removeImage(int index) => images.removeAt(index);

  void setQuickTitle(String title) {
    titleController.text = title;
  }

  Future<bool> submit() async {
    if (!formKey.currentState!.validate()) return false;
    if (selectedCategory.value == null) {
      Get.snackbar('Missing category', 'Please select a category');
      return false;
    }
    // The backend's create-complaint validation requires `room` alongside
    // `aadhar` — it's never derived server-side from the student record, so
    // it has to be sent explicitly. Reusing the already-loaded profile here
    // matches how services_screen/vehicle_redirect_screen read the room.
    final room = (Get.isRegistered<StudentProfileController>()
            ? Get.find<StudentProfileController>().profile.value?.room
            : null) ?? '';

    isSaving.value = true;
    try {
      final aadhar = await resolveAadhar(
        fromFeeSummary: _feesRepository.resolveAadhar,
        fromLaundryBalance: () async =>
            (await _laundryRepository.balance()).studentAadhar,
      );
      await _repository.submit(
        SubmitComplaintRequest(
          studentAadhar: aadhar,
          room: room,
          category: selectedCategory.value!,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          images: images,
        ),
      );
      return true;
    } on ApiException catch (e) {
      Get.snackbar(
        'Submission Failed',
        e.message,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return false;
    } catch (_) {
      Get.snackbar(
        'Submission Failed',
        'Something went wrong. Please try again.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
