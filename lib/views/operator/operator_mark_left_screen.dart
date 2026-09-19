import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_strings.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import 'operator_mark_left_controller.dart';

class OperatorMarkLeftScreen extends GetView<OperatorMarkLeftController> {
  const OperatorMarkLeftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mark Student Left')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: controller.aadharController,
                label: 'Student Aadhar',
                prefixIcon: Icons.badge_outlined,
                validator: Validators.required,
              ),
              const SizedBox(height: AppDimens.gapMd),
              AppTextField(
                controller: controller.reasonController,
                label: 'Reason',
                maxLines: 3,
              ),
              const SizedBox(height: AppDimens.gapXl),
              Obx(
                () => AppButton(
                  label: AppStrings.submit,
                  variant: AppButtonVariant.danger,
                  isLoading: controller.isSaving.value,
                  onPressed: () async {
                    final ok = await controller.submit();
                    if (ok) Get.back();
                  },
                ),
              ),
              const SizedBox(height: AppDimens.gapSm),
              const Text(
                'This archives the student\'s room and status — this action cannot be easily undone.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
