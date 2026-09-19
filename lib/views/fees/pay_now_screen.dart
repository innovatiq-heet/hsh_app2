import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/payment_type.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/date_time_picker_field.dart';
import 'pay_now_controller.dart';

class PayNowScreen extends GetView<PayNowController> {
  const PayNowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay Now')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Payment Type', style: AppTextStyles.label),
              const SizedBox(height: AppDimens.gapSm),
              Obx(
                () => SegmentedButton<PaymentType>(
                  segments: PaymentType.values
                      .map(
                        (t) => ButtonSegment(
                          value: t,
                          label: Text(t.label),
                          icon: Icon(t.icon, size: 16),
                        ),
                      )
                      .toList(),
                  selected: {controller.selectedType.value},
                  onSelectionChanged: (s) =>
                      controller.selectedType.value = s.first,
                ),
              ),
              const SizedBox(height: AppDimens.gapLg),
              AppTextField(
                controller: controller.amountController,
                label: 'Amount',
                prefixIcon: Icons.currency_rupee,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: Validators.amount,
              ),
              Obx(() {
                if (controller.selectedType.value != PaymentType.cheque) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    const SizedBox(height: AppDimens.gapMd),
                    AppTextField(
                      controller: controller.chequeNumberController,
                      label: 'Cheque Number',
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    Obx(
                      () => DateTimePickerField(
                        label: 'Cheque Date',
                        displayValue: controller.chequeDate.value == null
                            ? null
                            : DateFormatting.dateOnly(
                                controller.chequeDate.value!.toUtc(),
                              ),
                        onTap: () => controller.pickChequeDate(context),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: AppDimens.gapMd),
              AppTextField(
                controller: controller.bankNameController,
                label: 'Bank Name (optional)',
              ),
              const SizedBox(height: AppDimens.gapMd),
              AppTextField(
                controller: controller.narrationController,
                label: 'Narration (optional)',
                maxLines: 3,
              ),
              const SizedBox(height: AppDimens.gapXl),
              Obx(
                () => AppButton(
                  label: AppStrings.submit,
                  isLoading: controller.isSaving.value,
                  onPressed: () async {
                    final ok = await controller.submit();
                    if (ok) Get.back();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
