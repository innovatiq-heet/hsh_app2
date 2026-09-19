import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/complaint_status.dart';
import '../../network/repository/complaints/complaints_repository.dart';
import '../../network/responses/complaints/complaint_response.dart';

class ComplainAdminDetailController extends GetxController {
  final ComplaintsRepository _repository = Get.find();
  late final String complaintId = Get.arguments as String;

  final isLoading = true.obs;
  final complaint = Rxn<ComplaintResponse>();
  final feedbackController = TextEditingController();
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    feedbackController.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    complaint.value = await _repository.detail(complaintId);
    isLoading.value = false;
  }

  Future<void> setStatus(ComplaintStatus status) async {
    isSaving.value = true;
    try {
      complaint.value = await _repository.updateStatus(complaintId, status);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> submitFeedback() async {
    if (feedbackController.text.trim().isEmpty) return;
    isSaving.value = true;
    try {
      complaint.value = await _repository.addFeedback(
        complaintId,
        feedbackController.text.trim(),
      );
      feedbackController.clear();
    } finally {
      isSaving.value = false;
    }
  }
}
