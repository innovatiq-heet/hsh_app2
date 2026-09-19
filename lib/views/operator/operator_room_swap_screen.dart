import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import 'operator_room_swap_controller.dart';

class OperatorRoomSwapScreen extends GetView<OperatorRoomSwapController> {
  const OperatorRoomSwapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Room Swap')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the aadhar of the two students whose rooms should be swapped.',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: AppDimens.gapLg),
              AppTextField(
                controller: controller.aadharAController,
                label: 'Student A — Aadhar',
                prefixIcon: Icons.person_outline,
                validator: Validators.required,
              ),
              const SizedBox(height: AppDimens.gapMd),
              const Icon(Icons.swap_vert, color: AppColors.textMuted),
              const SizedBox(height: AppDimens.gapMd),
              AppTextField(
                controller: controller.aadharBController,
                label: 'Student B — Aadhar',
                prefixIcon: Icons.person_outline,
                validator: Validators.required,
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
