import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../network/api_exception.dart';
import '../../network/repository/attendance/attendance_repository.dart';
import '../../network/request/operator/operator_requests.dart';
import '../../network/responses/attendance/attendance_models.dart';

class OperatorSabhaController extends GetxController with LoadStateMixin {
  final AttendanceRepository _repository = Get.find();

  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final Rxn<DateTime> date = Rxn<DateTime>();
  final Rxn<TimeOfDay> startTime = Rxn<TimeOfDay>();
  final Rxn<TimeOfDay> endTime = Rxn<TimeOfDay>();
  final isSaving = false.obs;
  final sabhas = <SabhaSession>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    titleController.dispose();
    super.onClose();
  }

  Future<void> load() => guard(() async {
    final list = await _repository.upcomingSabhas();
    sabhas.assignAll(list);
  });

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
      final sTime = DateTime(
        d.year,
        d.month,
        d.day,
        startTime.value!.hour,
        startTime.value!.minute,
      );
      final eTime = DateTime(
        d.year,
        d.month,
        d.day,
        endTime.value!.hour,
        endTime.value!.minute,
      );

      final req = ScheduleSabhaRequest(
        title: titleController.text.trim(),
        date: d,
        startTime: sTime,
        endTime: eTime,
        current: true,
      );

      await _repository.scheduleSabha(req);

      titleController.clear();
      date.value = null;
      startTime.value = null;
      endTime.value = null;

      await load();
      return true;
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message);
      return false;
    } catch (e) {
      Get.snackbar('Error', 'Failed to schedule sabha.');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteSabha(String id) async {
    try {
      await _repository.deleteSabha(id);
      sabhas.removeWhere((s) => s.id == id);
      Get.snackbar('Deleted', 'Sabha session removed.');
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message);
    } catch (_) {
      Get.snackbar('Error', 'Could not delete sabha.');
    }
  }
}
