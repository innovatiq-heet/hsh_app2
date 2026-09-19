import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../network/repository/laundry/laundry_repository.dart';

class LaundryManagementController extends GetxController {
  final LaundryRepository _repository = Get.find();

  final formKey = GlobalKey<FormState>();
  final aadharController = TextEditingController();
  final amountController = TextEditingController();
  final isSaving = false.obs;
  final lastRechargedBalance = Rxn<double>();

  @override
  void onClose() {
    aadharController.dispose();
    amountController.dispose();
    super.onClose();
  }

  Future<void> recharge() async {
    if (!formKey.currentState!.validate()) return;
    isSaving.value = true;
    try {
      final amount = double.parse(amountController.text.trim());
      lastRechargedBalance.value = await _repository.recharge(
        aadharController.text.trim(),
        amount,
      );
      Get.snackbar(
        'Recharge successful',
        'New balance: ₹${lastRechargedBalance.value!.toStringAsFixed(0)}',
      );
      amountController.clear();
    } finally {
      isSaving.value = false;
    }
  }
}
