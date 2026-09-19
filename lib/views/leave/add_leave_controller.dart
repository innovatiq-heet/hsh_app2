import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../network/repository/leave/leave_repository.dart';
import '../../network/request/leave/apply_leave_request.dart';

class AddLeaveController extends GetxController {
  final LeaveRepository _repository = Get.find();

  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();

  final Rxn<DateTime> startTime = Rxn<DateTime>();
  final Rxn<DateTime> endTime = Rxn<DateTime>();
  final isSaving = false.obs;

  @override
  void onClose() {
    reasonController.dispose();
    super.onClose();
  }

  Future<void> pickStart(BuildContext context) async {
    final picked = await _pickDateTime(
      context,
      startTime.value ?? DateTime.now(),
    );
    if (picked != null) startTime.value = picked;
  }

  Future<void> pickEnd(BuildContext context) async {
    final picked = await _pickDateTime(
      context,
      endTime.value ?? (startTime.value ?? DateTime.now()),
    );
    if (picked != null) endTime.value = picked;
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String? get validationError {
    if (startTime.value == null) return 'Please select a start date & time';
    if (endTime.value == null) return 'Please select an end date & time';
    if (endTime.value!.isBefore(startTime.value!)) {
      return 'End must be after start';
    }
    return null;
  }

  Future<bool> submit() async {
    if (!formKey.currentState!.validate()) return false;
    final error = validationError;
    if (error != null) {
      Get.snackbar('Invalid dates', error);
      return false;
    }
    isSaving.value = true;
    try {
      await _repository.apply(
        ApplyLeaveRequest(
          startTime: startTime.value!.toUtc(),
          endTime: endTime.value!.toUtc(),
          reason: reasonController.text.trim(),
        ),
      );
      return true;
    } finally {
      isSaving.value = false;
    }
  }
}
