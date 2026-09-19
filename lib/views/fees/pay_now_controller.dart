import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/payment_type.dart';
import '../../network/repository/fees/fees_repository.dart';
import '../../network/request/fees/submit_payment_request.dart';

class PayNowController extends GetxController {
  final FeesRepository _repository = Get.find();

  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final chequeNumberController = TextEditingController();
  final bankNameController = TextEditingController();
  final narrationController = TextEditingController();

  final Rx<PaymentType> selectedType = PaymentType.online.obs;
  final Rxn<DateTime> chequeDate = Rxn<DateTime>();
  final isSaving = false.obs;

  @override
  void onClose() {
    amountController.dispose();
    chequeNumberController.dispose();
    bankNameController.dispose();
    narrationController.dispose();
    super.onClose();
  }

  Future<void> pickChequeDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) chequeDate.value = picked;
  }

  Future<bool> submit() async {
    if (!formKey.currentState!.validate()) return false;
    if (selectedType.value == PaymentType.cheque) {
      if (chequeNumberController.text.trim().isEmpty ||
          chequeDate.value == null) {
        Get.snackbar('Missing details', 'Cheque number and date are required.');
        return false;
      }
    }
    isSaving.value = true;
    try {
      await _repository.submitPayment(
        SubmitPaymentRequest(
          amount: double.parse(amountController.text.trim()),
          type: selectedType.value,
          chequeNumber: selectedType.value == PaymentType.cheque
              ? chequeNumberController.text.trim()
              : null,
          chequeDate: selectedType.value == PaymentType.cheque
              ? chequeDate.value
              : null,
          bankName: bankNameController.text.trim().isEmpty
              ? null
              : bankNameController.text.trim(),
          narration: narrationController.text.trim().isEmpty
              ? null
              : narrationController.text.trim(),
        ),
      );
      return true;
    } finally {
      isSaving.value = false;
    }
  }
}
