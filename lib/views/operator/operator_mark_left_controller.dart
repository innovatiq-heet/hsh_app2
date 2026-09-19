import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../network/repository/operator/operator_repository.dart';
import '../../network/request/operator/operator_requests.dart';

class OperatorMarkLeftController extends GetxController {
  final OperatorRepository _repository = Get.find();

  final formKey = GlobalKey<FormState>();
  final aadharController = TextEditingController();
  final reasonController = TextEditingController();
  final isSaving = false.obs;

  @override
  void onClose() {
    aadharController.dispose();
    reasonController.dispose();
    super.onClose();
  }

  Future<bool> submit() async {
    if (!formKey.currentState!.validate()) return false;
    isSaving.value = true;
    try {
      await _repository.markStudentLeft(
        MarkStudentLeftRequest(
          studentAadhar: aadharController.text.trim(),
          reason: reasonController.text.trim(),
        ),
      );
      return true;
    } finally {
      isSaving.value = false;
    }
  }
}
