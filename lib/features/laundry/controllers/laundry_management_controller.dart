import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/laundry/laundry_repository.dart';
import '../../../core/network/responses/laundry/laundry_responses.dart';
import '../../../core/utils/app_snackbar.dart';

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

    // Student ID / Bank code can be 3 to 12 digits. Do not hit API for < 3 characters.
    if (clean.length < 3) {
      studentBalance.value = null;
      rechargeHistory.clear();
      return;
    }

    // Debounce duration: 400ms
    const delay = Duration(milliseconds: 400);

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
        AppSnackbar.error(
          'Student Not Found',
          message,
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
      AppSnackbar.success(
        'Recharge Successful',
        'Added â‚¹${amount.toStringAsFixed(0)} to student account.',
      );
      amountController.clear();
      await checkStudent(aadhar, isManual: true, force: true);
    } catch (e) {
      AppSnackbar.error('Error', 'Recharge failed: $e');
    } finally {
      isSaving.value = false;
    }
  }
}
