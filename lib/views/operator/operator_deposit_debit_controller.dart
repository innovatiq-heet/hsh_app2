import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../network/repository/operator/operator_repository.dart';
import '../../network/request/fees/submit_payment_request.dart';

class OperatorDepositDebitController extends GetxController {
  final OperatorRepository _repository = Get.find();

  // Deposit form
  final depositFormKey = GlobalKey<FormState>();
  final depositAadharController = TextEditingController();
  final depositAmountController = TextEditingController();
  final depositNarrationController = TextEditingController();
  final isCredit = true.obs;
  final isSavingDeposit = false.obs;

  // Debit form
  final debitFormKey = GlobalKey<FormState>();
  final debitAadharController = TextEditingController();
  final debitLabelController = TextEditingController();
  final debitAmountController = TextEditingController();
  final debitYearController = TextEditingController(text: '2025-26');
  final isSavingDebit = false.obs;

  @override
  void onClose() {
    depositAadharController.dispose();
    depositAmountController.dispose();
    depositNarrationController.dispose();
    debitAadharController.dispose();
    debitLabelController.dispose();
    debitAmountController.dispose();
    debitYearController.dispose();
    super.onClose();
  }

  Future<bool> submitDeposit() async {
    if (!depositFormKey.currentState!.validate()) return false;
    isSavingDeposit.value = true;
    try {
      await _repository.recordDeposit(
        DepositEntryRequest(
          studentAadhar: depositAadharController.text.trim(),
          amount: double.parse(depositAmountController.text.trim()),
          isCredit: isCredit.value,
          narration: depositNarrationController.text.trim(),
        ),
      );
      depositAadharController.clear();
      depositAmountController.clear();
      depositNarrationController.clear();
      return true;
    } finally {
      isSavingDeposit.value = false;
    }
  }

  Future<bool> submitDebit() async {
    if (!debitFormKey.currentState!.validate()) return false;
    isSavingDebit.value = true;
    try {
      await _repository.postFeeDebit(
        FeeDebitRequest(
          studentAadhar: debitAadharController.text.trim(),
          label: debitLabelController.text.trim(),
          amount: double.parse(debitAmountController.text.trim()),
          academicYear: debitYearController.text.trim(),
        ),
      );
      debitAadharController.clear();
      debitLabelController.clear();
      debitAmountController.clear();
      return true;
    } finally {
      isSavingDebit.value = false;
    }
  }
}
