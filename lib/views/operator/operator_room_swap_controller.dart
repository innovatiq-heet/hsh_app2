import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../network/repository/operator/operator_repository.dart';
import '../../network/request/operator/operator_requests.dart';

class OperatorRoomSwapController extends GetxController {
  final OperatorRepository _repository = Get.find();

  final formKey = GlobalKey<FormState>();
  final aadharAController = TextEditingController();
  final aadharBController = TextEditingController();
  final isSaving = false.obs;

  @override
  void onClose() {
    aadharAController.dispose();
    aadharBController.dispose();
    super.onClose();
  }

  Future<bool> submit() async {
    if (!formKey.currentState!.validate()) return false;
    isSaving.value = true;
    try {
      await _repository.swapRooms(
        RoomSwapRequest(
          studentAadharA: aadharAController.text.trim(),
          studentAadharB: aadharBController.text.trim(),
        ),
      );
      return true;
    } finally {
      isSaving.value = false;
    }
  }
}
