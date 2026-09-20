import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/attendance_type.dart';
import '../../network/api_exception.dart';
import '../../network/repository/attendance/attendance_repository.dart';
import '../../network/repository/operator/operator_repository.dart';
import '../../network/request/attendance/mark_attendance_request.dart';

class OperatorAttendanceBehalfController extends GetxController {
  final OperatorRepository _operatorRepository = Get.find();
  final AttendanceRepository _attendanceRepository = Get.find();

  final formKey = GlobalKey<FormState>();
  final idOrAadharController = TextEditingController();
  final Rx<AttendanceType> selectedType = AttendanceType.aarti.obs;
  final Rxn<DateTime> date = Rxn<DateTime>(DateTime.now());
  final isSaving = false.obs;
  final errorMessage = ''.obs;

  @override
  void onClose() {
    idOrAadharController.dispose();
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
    errorMessage.value = '';

    final input = idOrAadharController.text.trim();
    final studentId = int.tryParse(input);
    final aadhar = studentId == null ? input : null;

    final request = MarkAttendanceOnBehalfRequest(
      studentId: studentId,
      studentAadhar: aadhar,
      type: selectedType.value,
      date: date.value ?? DateTime.now(),
      viaCode: false,
    );

    try {
      // Call both AttendanceRepository and OperatorRepository for sync
      await _attendanceRepository.markAdminAttendance(request);
      await _operatorRepository.logAttendanceOnBehalf(request);
      idOrAadharController.clear();
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      Get.snackbar('Error', e.message, backgroundColor: Colors.red.shade100);
      return false;
    } catch (e) {
      errorMessage.value = 'Failed to log attendance. Please retry.';
      Get.snackbar('Error', 'Failed to log attendance.', backgroundColor: Colors.red.shade100);
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
