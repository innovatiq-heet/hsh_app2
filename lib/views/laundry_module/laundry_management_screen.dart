import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import 'laundry_management_controller.dart';

/// Recharge/status-update actions are shared across staff/warden/admin —
/// not laundry-role-specific (spec §5.14).
class LaundryManagementScreen extends GetView<LaundryManagementController> {
  const LaundryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Recharge Student Balance', style: AppTextStyles.title),
            const SizedBox(height: AppDimens.gapSm),
            Text(
              'Enter the student\'s aadhar and the amount to add to their laundry balance.',
              style: AppTextStyles.bodySm,
            ),
            const SizedBox(height: AppDimens.gapLg),
            AppTextField(
              controller: controller.aadharController,
              label: 'Student Aadhar',
              prefixIcon: Icons.badge_outlined,
              validator: Validators.required,
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.amountController,
              label: 'Amount',
              prefixIcon: Icons.currency_rupee,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: Validators.amount,
            ),
            const SizedBox(height: AppDimens.gapXl),
            Obx(
              () => AppButton(
                label: 'Recharge',
                isLoading: controller.isSaving.value,
                onPressed: controller.recharge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
