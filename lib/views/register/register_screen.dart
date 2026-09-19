import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_text_styles.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/brand.dart';
import 'register_controller.dart';

class RegisterScreen extends GetView<RegisterController> {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.headerBlue,
        body: Stack(
          children: [
            const Positioned.fill(child: BrandBackdrop()),
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 28, 36),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: Get.back,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.createAccount,
                                  style: AppTextStyles.displayMd.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Join Hari Saurabh Hostel',
                                  style: AppTextStyles.bodyMd.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _RegisterPanel(controller: controller),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterPanel extends StatelessWidget {
  final RegisterController controller;

  const _RegisterPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimens.gapMd),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppDimens.gapMd),
                  Expanded(
                    child: Text(
                      'Self-signup creates a student account. Staff accounts are issued by the hostel office.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.primary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AppTextField(
              controller: controller.nameController,
              label: AppStrings.fullName,
              prefixIcon: Icons.person_outline_rounded,
              validator: controller.validateRequired,
            ),
            const SizedBox(height: AppDimens.gapLg),
            AppTextField(
              controller: controller.emailController,
              label: AppStrings.email,
              prefixIcon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: controller.validateEmail,
            ),
            const SizedBox(height: AppDimens.gapLg),
            AppTextField(
              controller: controller.passwordController,
              label: AppStrings.password,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              validator: controller.validatePassword,
            ),
            const SizedBox(height: AppDimens.gapXl),
            Obx(
              () => AppButton(
                label: AppStrings.createAccount,
                icon: Icons.arrow_forward_rounded,
                isLoading: controller.isLoading.value,
                onPressed: controller.register,
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.alreadyHaveAccount,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: Get.back,
                  child: const Text(AppStrings.login),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
