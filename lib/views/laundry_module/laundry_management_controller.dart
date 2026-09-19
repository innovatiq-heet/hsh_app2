import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/responses/laundry/laundry_responses.dart';

class LaundryManagementController extends GetxController {
  final LaundryRepository _repository = Get.find();

  final formKey = GlobalKey<FormState>();
  final aadharController = TextEditingController();
  final amountController = TextEditingController();

  final isSaving = false.obs;
  final isLoadingHistory = false.obs;
  final isLoadingBalance = false.obs;

  final studentBalance = Rxn<LaundryBalanceModel>();
  final rechargeHistory = <LaundryRechargeModel>[].obs;

  @override
  void onClose() {
    aadharController.dispose();
    amountController.dispose();
    super.onClose();
  }

  Future<void> checkStudent(String aadhar) async {
    final clean = aadhar.trim();
    if (clean.isEmpty) return;

    isLoadingBalance.value = true;
    isLoadingHistory.value = true;
    try {
      final results = await Future.wait([
        _repository.balance(aadhar: clean),
        _repository.recharges(clean),
      ]);
      studentBalance.value = results[0] as LaundryBalanceModel;
      rechargeHistory.assignAll(results[1] as List<LaundryRechargeModel>);
    } catch (e) {
      Get.snackbar('Notice', 'Could not fetch student details: $e');
    } finally {
      isLoadingBalance.value = false;
      isLoadingHistory.value = false;
    }
  }

  Future<void> recharge() async {
    if (!formKey.currentState!.validate()) return;
    isSaving.value = true;
    final aadhar = aadharController.text.trim();
    final amount = double.parse(amountController.text.trim());

    try {
      await _repository.recharge(aadhar, amount);
      Get.snackbar(
        'Recharge Successful',
        'Added ₹${amount.toStringAsFixed(0)} to student account.',
        snackPosition: SnackPosition.BOTTOM,
      );
      amountController.clear();
      await checkStudent(aadhar);
    } catch (e) {
      Get.snackbar('Error', 'Recharge failed: $e');
    } finally {
      isSaving.value = false;
    }
  }
}
