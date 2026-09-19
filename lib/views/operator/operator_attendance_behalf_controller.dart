import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/attendance_type.dart';
import '../../network/repository/operator/operator_repository.dart';
import '../../network/request/attendance/mark_attendance_request.dart';

class OperatorAttendanceBehalfController extends GetxController {
  final OperatorRepository _repository = Get.find();

  final formKey = GlobalKey<FormState>();
  final aadharController = TextEditingController();
  final Rx<AttendanceType> selectedType = AttendanceType.aarti.obs;
  final Rxn<DateTime> date = Rxn<DateTime>(DateTime.now());
  final isSaving = false.obs;

  @override
  void onClose() {
    aadharController.dispose();
    super.onClose();
  }

  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date.value ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) date.value = picked;
  }

  Future<bool> submit() async {
    if (!formKey.currentState!.validate()) return false;
    isSaving.value = true;
    try {
      await _repository.logAttendanceOnBehalf(
        MarkAttendanceOnBehalfRequest(
          studentAadhar: aadharController.text.trim(),
          type: selectedType.value,
          date: date.value ?? DateTime.now(),
        ),
      );
      aadharController.clear();
      return true;
    } finally {
      isSaving.value = false;
    }
  }
}
