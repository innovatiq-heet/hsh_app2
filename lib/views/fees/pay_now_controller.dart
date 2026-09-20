import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../common_enums/payment_type.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../network/repository/fees/fees_repository.dart';
import '../../network/request/fees/submit_payment_request.dart';
import '../../network/responses/fees/fee_responses.dart';
import 'fees_controller.dart';

class PayNowController extends GetxController {
  final FeesRepository _repository = Get.find();
  final ImagePicker _imagePicker = ImagePicker();

  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final chequeNumberController = TextEditingController();
  final bankNameController = TextEditingController();
  final transactionRefController = TextEditingController();
  final narrationController = TextEditingController();

  final Rx<PaymentType> selectedType = PaymentType.online.obs;
  final Rxn<DateTime> chequeDate = Rxn<DateTime>();
  final Rxn<String> attachedProofPath = Rxn<String>();
  final isSaving = false.obs;

  // Hostel banking constants for student convenience
  static const String upiId = 'hsh.hostel@icici';
  static const String upiName = 'Hari Saurabh Hostel Trust';
  static const String bankAccountNo = '002405009871';
  static const String bankIfsc = 'ICIC0000024';
  static const String bankName = 'ICICI Bank (University Branch)';

  double get netDue {
    if (Get.isRegistered<FeesController>()) {
      final summary = Get.find<FeesController>().summary.value;
      if (summary != null) return summary.netDue;
    }
    return 25000.0;
  }

  @override
  void onInit() {
    super.onInit();
    // Pre-fill initial amount with outstanding net due if available
    final initialDue = netDue;
    if (initialDue > 0) {
      amountController.text = initialDue.toStringAsFixed(0);
    }
  }

  @override
  void onClose() {
    amountController.dispose();
    chequeNumberController.dispose();
    bankNameController.dispose();
    transactionRefController.dispose();
    narrationController.dispose();
    super.onClose();
  }

  void selectAmount(double amount) {
    amountController.text = amount.toStringAsFixed(0);
  }

  void copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Copied',
      '$label copied to clipboard',
      backgroundColor: AppColors.headerBlue,
      colorText: Colors.white,
      icon: const Icon(Icons.copy_rounded, color: Colors.white),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(AppDimens.gapMd),
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> pickProofImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file != null) {
        attachedProofPath.value = file.path;
      }
    } catch (e) {
      Get.snackbar('Image Picker', 'Could not select image: $e');
    }
  }

  void removeProof() {
    attachedProofPath.value = null;
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

  Future<FeeTransactionResponse?> submit() async {
    if (!formKey.currentState!.validate()) return null;

    final type = selectedType.value;

    if (type == PaymentType.cheque) {
      if (chequeNumberController.text.trim().isEmpty ||
          chequeDate.value == null) {
        Get.snackbar(
          'Missing details',
          'Cheque number and date are required.',
          backgroundColor: AppColors.cancelledRed,
          colorText: Colors.white,
        );
        return null;
      }
    } else if (type == PaymentType.online) {
      if (transactionRefController.text.trim().isEmpty) {
        Get.snackbar(
          'Missing Reference',
          'Please enter the UPI Reference ID or UTR number.',
          backgroundColor: AppColors.warningOrange,
          colorText: Colors.white,
        );
        return null;
      }
    }

    isSaving.value = true;
    try {
      final txn = await _repository.submitPayment(
        SubmitPaymentRequest(
          amount: double.parse(amountController.text.trim()),
          type: type,
          chequeNumber: type == PaymentType.cheque
              ? chequeNumberController.text.trim()
              : null,
          chequeDate: type == PaymentType.cheque ? chequeDate.value : null,
          bankName: type == PaymentType.online
              ? (bankNameController.text.trim().isEmpty
                  ? 'UPI / NetBanking'
                  : bankNameController.text.trim())
              : (bankNameController.text.trim().isEmpty
                  ? null
                  : bankNameController.text.trim()),
          narration: narrationController.text.trim().isEmpty
              ? null
              : narrationController.text.trim(),
          transactionRef: type == PaymentType.online
              ? transactionRefController.text.trim()
              : null,
          attachmentPath: attachedProofPath.value,
        ),
      );

      // Also refresh the parent FeesController if active
      if (Get.isRegistered<FeesController>()) {
        Get.find<FeesController>().load();
      }

      return txn;
    } finally {
      isSaving.value = false;
    }
  }
}
