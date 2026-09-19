import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/complaint_status.dart';
import '../../network/repository/complaints/complaints_repository.dart';
import '../../network/request/complaints/update_complaint_request.dart';
import '../../network/responses/complaints/complaint_response.dart';

class ComplainAdminDetailController extends GetxController {
  final ComplaintsRepository _repository = Get.find();
  late final String complaintId = (Get.arguments ?? '').toString();

  final isLoading = true.obs;
  final complaint = Rxn<ComplaintResponse>();
  final feedbackController = TextEditingController();
  final reviewController = TextEditingController();
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    feedbackController.dispose();
    reviewController.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final res = await _repository.detail(complaintId);
      complaint.value = res;
      if (res.feedback != null) feedbackController.text = res.feedback!;
      if (res.review != null) reviewController.text = res.review!;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> setStatus(ComplaintStatus status) async {
    isSaving.value = true;
    try {
      complaint.value = await _repository.updateComplaint(
        complaintId,
        UpdateComplaintRequest(status: status),
      );
      Get.snackbar('Status Updated', 'Moved to ${status.label}.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> submitReviewNote() async {
    if (reviewController.text.trim().isEmpty) return;
    isSaving.value = true;
    try {
      complaint.value = await _repository.updateComplaint(
        complaintId,
        UpdateComplaintRequest(
          status: ComplaintStatus.reviewed,
          review: reviewController.text.trim(),
        ),
      );
      Get.snackbar('Saved', 'Staff review note logged.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> submitFeedback() async {
    if (feedbackController.text.trim().isEmpty) return;
    isSaving.value = true;
    try {
      complaint.value = await _repository.updateComplaint(
        complaintId,
        UpdateComplaintRequest(
          status: ComplaintStatus.resolved,
          response: feedbackController.text.trim(),
        ),
      );
      Get.snackbar('Resolved', 'Resolution note saved & closed.');
    } finally {
      isSaving.value = false;
    }
  }
}
