import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../network/api_exception.dart';
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
  final lookupError = Rxn<String>();

  Timer? _debounceTimer;
  int _searchRequestId = 0;
  String? _lastSearchedAadhar;

  @override
  void onClose() {
    _debounceTimer?.cancel();
    aadharController.dispose();
    amountController.dispose();
    super.onClose();
  }

  /// Debounced handler invoked on each character typed into the Aadhar input field.
  void onAadharChanged(String rawValue) {
    _debounceTimer?.cancel();
    final clean = rawValue.trim();

    // If input is cleared, reset states immediately without network calls
    if (clean.isEmpty) {
      _lastSearchedAadhar = null;
      studentBalance.value = null;
      rechargeHistory.clear();
      lookupError.value = null;
      isLoadingBalance.value = false;
      isLoadingHistory.value = false;
      return;
    }

    lookupError.value = null;

    // Aadhar numbers are 12 digits. Do not hit API for short incomplete inputs.
    if (clean.length < 10) {
      studentBalance.value = null;
      rechargeHistory.clear();
      return;
    }

    // Debounce duration: 400ms for complete 12-digit number, 600ms if 10-11 digits
    final delay = clean.length >= 12
        ? const Duration(milliseconds: 400)
        : const Duration(milliseconds: 600);

    _debounceTimer = Timer(delay, () {
      checkStudent(clean, isManual: false);
    });
  }

  /// Executes lookup with debounce cancellation, request deduplication,
  /// and race-condition immunity.
  Future<void> checkStudent(
    String aadhar, {
    bool isManual = true,
    bool force = false,
  }) async {
    _debounceTimer?.cancel();
    final clean = aadhar.trim();
    if (clean.isEmpty) return;

    // Prevent redundant consecutive requests for the same Aadhar unless forced
    if (!force && clean == _lastSearchedAadhar && studentBalance.value != null) {
      return;
    }

    final requestId = ++_searchRequestId;
    isLoadingBalance.value = true;
    isLoadingHistory.value = true;
    lookupError.value = null;

    try {
      final results = await Future.wait([
        _repository.balance(aadhar: clean),
        _repository.recharges(clean),
      ]);

      // If a newer request was dispatched while this one was awaiting, discard this response
      if (requestId != _searchRequestId) return;

      studentBalance.value = results[0] as LaundryBalanceModel;
      rechargeHistory.assignAll(results[1] as List<LaundryRechargeModel>);
      _lastSearchedAadhar = clean;
      lookupError.value = null;
    } catch (e) {
      if (requestId != _searchRequestId) return;

      final message = e is ApiException ? e.message : e.toString();
      lookupError.value = message;
      studentBalance.value = null;
      rechargeHistory.clear();

      if (isManual) {
        Get.snackbar(
          'Student Not Found',
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (requestId == _searchRequestId) {
        isLoadingBalance.value = false;
        isLoadingHistory.value = false;
      }
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
      await checkStudent(aadhar, isManual: true, force: true);
    } catch (e) {
      Get.snackbar('Error', 'Recharge failed: $e');
    } finally {
      isSaving.value = false;
    }
  }
}
