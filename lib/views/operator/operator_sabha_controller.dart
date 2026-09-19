import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../network/repository/operator/operator_repository.dart';
import '../../network/request/operator/operator_requests.dart';

class OperatorSabhaController extends GetxController {
  final OperatorRepository _repository = Get.find();

  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final Rxn<DateTime> date = Rxn<DateTime>();
  final Rxn<TimeOfDay> startTime = Rxn<TimeOfDay>();
  final Rxn<TimeOfDay> endTime = Rxn<TimeOfDay>();
  final isSaving = false.obs;

  @override
  void onClose() {
    titleController.dispose();
    super.onClose();
  }

  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) date.value = picked;
  }

  Future<void> pickStartTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) startTime.value = picked;
  }

  Future<void> pickEndTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) endTime.value = picked;
  }

  Future<bool> submit() async {
    if (!formKey.currentState!.validate()) return false;
    if (date.value == null ||
        startTime.value == null ||
        endTime.value == null) {
      Get.snackbar(
        'Missing details',
        'Please select date, start time and end time.',
      );
      return false;
    }
    isSaving.value = true;
    try {
      final d = date.value!;
      await _repository.scheduleSabha(
        ScheduleSabhaRequest(
          title: titleController.text.trim(),
          date: d,
          startTime: DateTime(
            d.year,
            d.month,
            d.day,
            startTime.value!.hour,
            startTime.value!.minute,
          ),
          endTime: DateTime(
            d.year,
            d.month,
            d.day,
            endTime.value!.hour,
            endTime.value!.minute,
          ),
        ),
      );
      titleController.clear();
      date.value = null;
      startTime.value = null;
      endTime.value = null;
      return true;
    } finally {
      isSaving.value = false;
    }
  }
}
