import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/complaints/complaints_repository.dart';
import '../../../core/network/request/complaints/submit_complaint_request.dart';
import '../../../services/aadhar_service.dart';
import '../student_profile/student_profile_controller.dart';

class AddComplaintController extends GetxController {
  final ComplaintsRepository _repository = Get.find();
  final AadharService _aadharService = Get.find();

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
    _loadCategories();
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }

  Future<void> _loadCategories() async {
    categories.assignAll(await _repository.categories());
    if (categories.isNotEmpty) selectedCategory.value = categories.first;
  }

  Future<void> pickImage() => pickImageFromSource(ImageSource.gallery);

  Future<void> pickImageFromCamera() => pickImageFromSource(ImageSource.camera);

  Future<void> pickImageFromSource(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked != null) images.add(File(picked.path));
  }

  void removeImage(int index) => images.removeAt(index);

  void setQuickTitle(String title) => titleController.text = title;

  Future<bool> submit() async {
    if (!formKey.currentState!.validate()) return false;
    if (selectedCategory.value == null) {
      Get.snackbar('Missing category', 'Please select a category');
      return false;
    }

    // The backend requires `room` alongside `aadhar`; it's never derived
    // server-side, so it must be sent explicitly.
    final profileCtrl = Get.isRegistered<StudentProfileController>()
        ? Get.find<StudentProfileController>()
        : null;
    final room = profileCtrl?.profile.value?.room;
    if (room == null || room.isEmpty) {
      Get.snackbar(
        'Profile still loading',
        'Open your Profile tab once so it can load, then try again.',
      );
      return false;
    }

    isSaving.value = true;
    try {
      final aadhar = await _aadharService.resolve();
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
