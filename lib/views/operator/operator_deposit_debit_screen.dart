import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_strings.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import 'operator_deposit_debit_controller.dart';

class OperatorDepositDebitScreen
    extends GetView<OperatorDepositDebitController> {
  const OperatorDepositDebitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Deposit & Debit Entry'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Deposit'),
              Tab(text: 'Fee Debit'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              child: Form(
                key: controller.depositFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: controller.depositAadharController,
                      label: 'Student Aadhar',
                      validator: Validators.required,
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    Obx(
                      () => SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Credit')),
                          ButtonSegment(value: false, label: Text('Debit')),
                        ],
                        selected: {controller.isCredit.value},
                        onSelectionChanged: (s) =>
                            controller.isCredit.value = s.first,
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    AppTextField(
                      controller: controller.depositAmountController,
                      label: 'Amount',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: Validators.amount,
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    AppTextField(
                      controller: controller.depositNarrationController,
                      label: 'Narration',
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppDimens.gapXl),
                    Obx(
                      () => AppButton(
                        label: AppStrings.submit,
                        isLoading: controller.isSavingDeposit.value,
                        onPressed: () async {
                          final ok = await controller.submitDeposit();
                          if (ok) {
                            Get.snackbar('Saved', 'Deposit entry recorded.');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              child: Form(
                key: controller.debitFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: controller.debitAadharController,
                      label: 'Student Aadhar',
                      validator: Validators.required,
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    AppTextField(
                      controller: controller.debitLabelController,
                      label: 'Charge Label (e.g. Electricity)',
                      validator: Validators.required,
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    AppTextField(
                      controller: controller.debitAmountController,
                      label: 'Amount',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: Validators.amount,
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    AppTextField(
                      controller: controller.debitYearController,
                      label: 'Academic Year',
                    ),
                    const SizedBox(height: AppDimens.gapXl),
                    Obx(
                      () => AppButton(
                        label: AppStrings.submit,
                        isLoading: controller.isSavingDebit.value,
                        onPressed: () async {
                          final ok = await controller.submitDebit();
                          if (ok) Get.snackbar('Saved', 'Fee debit posted.');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
