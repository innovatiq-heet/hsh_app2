import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../common_enums/user_role.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_text_styles.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/brand.dart';
import 'login_controller.dart';

class LoginScreen extends GetView<LoginController> {
  const LoginScreen({super.key});

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
                      padding: const EdgeInsets.fromLTRB(28, 48, 28, 40),
                      child: Column(
                        children: [
                          const BrandLogo(),
                          const SizedBox(height: 22),
                          Text(
                            'Hari Saurabh',
                            style: AppTextStyles.displayLg.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your hostel, all in one place',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FormPanel(controller: controller),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  final LoginController controller;

  const _FormPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      padding: EdgeInsets.fromLTRB(
        28,
        32,
        28,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome back', style: AppTextStyles.displayMd),
            const SizedBox(height: 6),
            Text(
              'Sign in to continue to your account',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
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
                label: AppStrings.login,
                icon: Icons.arrow_forward_rounded,
                isLoading: controller.isLoading.value,
                onPressed: controller.login,
              ),
            ),
            const SizedBox(height: AppDimens.gapXl),
            _DevRoleSwitcher(controller: controller),
            const SizedBox(height: AppDimens.gapLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.dontHaveAccount,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () => Get.toNamed(Routes.register),
                  child: const Text(AppStrings.createAccount),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// TODO(api): remove once real login returns role from the JWT — every
/// shell is reachable through this for UI review without a backend.
class _DevRoleSwitcher extends StatelessWidget {
  final LoginController controller;

  const _DevRoleSwitcher({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.gapLg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text('PREVIEW AS · DEV ONLY', style: AppTextStyles.overline),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          Obx(
            () => Wrap(
              spacing: AppDimens.gapSm,
              runSpacing: AppDimens.gapSm,
              children: UserRole.values
                  .where((r) => r != UserRole.unknown)
                  .map(
                    (role) => ChoiceChip(
                      label: Text(role.label),
                      selected: controller.devRole.value == role,
                      onSelected: (_) => controller.devRole.value = role,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
