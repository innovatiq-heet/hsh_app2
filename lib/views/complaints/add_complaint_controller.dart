import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../abstracts/mixins/aadhar_resolving_mixin.dart';
import '../../network/repository/complaints/complaints_repository.dart';
import '../../network/repository/fees/fees_repository.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/request/complaints/submit_complaint_request.dart';

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

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) images.add(File(picked.path));
  }

  void removeImage(int index) => images.removeAt(index);

  Future<bool> submit() async {
    if (!formKey.currentState!.validate()) return false;
    if (selectedCategory.value == null) {
      Get.snackbar('Missing category', 'Please select a category');
      return false;
    }
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
          category: selectedCategory.value!,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          images: images,
        ),
      );
      return true;
    } finally {
      isSaving.value = false;
    }
  }
}
