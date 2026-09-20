import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../storage/session_store.dart';
import '../../utils/date_formatting.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import 'laundry_management_controller.dart';

class LaundryManagementScreen extends GetView<LaundryManagementController> {
  const LaundryManagementScreen({super.key});

  Future<void> _logout() async {
    await SessionStore.instance.clear();
    Get.offAllNamed(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Gradient Header
        SliverGradientHeader(
          overline: 'Student Accounts',
          title: 'Laundry Recharge',
          subtitle: 'Check student balance and add laundry credits',
          expandedHeight: 220.0,
          actions: [
            HeaderIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              onPressed: () {
                final aadhar = controller.aadharController.text.trim();
                if (aadhar.isNotEmpty) {
                  controller.checkStudent(aadhar);
                }
              },
            ),
            HeaderIconButton(
              icon: Icons.logout_rounded,
              tooltip: 'Log out',
              onPressed: _logout,
            ),
          ],
          child: Obx(() {
            final bal = controller.studentBalance.value;
            if (bal == null) {
              return const HeaderPill(
                icon: Icons.badge_outlined,
                label: 'Search student to view wallet',
              );
            }
            return Row(
              children: [
                HeaderPill(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Balance: ₹${bal.balance.toStringAsFixed(0)}',
                ),
                const SizedBox(width: AppDimens.gapSm),
                HeaderPill(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Spent: ₹${bal.totalSpend.toStringAsFixed(0)}',
                ),
              ],
            );
          }),
        ),

        // Main Body Form & History
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
            AppDimens.screenPadding,
            AppDimens.gapLg,
            AppDimens.screenPadding,
            100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Recharge Form Card
              AppCard(
                child: Form(
                  key: controller.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Student Balance Lookup',
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter student Aadhar number to view current balance and top-up funds.',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapLg),

                      // Aadhar search field
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: controller.aadharController,
                              label: 'Student Aadhar Number',
                              hint: 'Enter 12-digit Aadhar number',
                              prefixIcon: Icons.badge_outlined,
                              keyboardType: TextInputType.number,
                              validator: Validators.required,
                              onChanged: (val) {
                                if (val.trim().length >= 10) {
                                  controller.checkStudent(val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: AppDimens.gapSm),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Obx(
                              () => SizedBox(
                                height: 50,
                                width: 50,
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusMd,
                                      ),
                                    ),
                                  ),
                                  tooltip: 'Lookup Student',
                                  icon: controller.isLoadingBalance.value
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.search_rounded,
                                          color: Colors.white,
                                        ),
                                  onPressed: () => controller.checkStudent(
                                    controller.aadharController.text.trim(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.gapMd),

                      // Student Balance Preview Card
                      Obx(() {
                        final bal = controller.studentBalance.value;
                        if (bal == null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(
                            bottom: AppDimens.gapMd,
                          ),
                          padding: const EdgeInsets.all(AppDimens.gapMd),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primarySoft,
                                AppColors.primarySoft.withValues(alpha: 0.3),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMd),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppDimens.gapSm),
                                  Text(
                                    'Account for ${bal.aadhar}',
                                    style: AppTextStyles.bodySm.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimens.gapMd),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Available Balance',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${bal.balance.toStringAsFixed(0)}',
                                          style:
                                              AppTextStyles.displayMd.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 36,
                                    color: AppColors.border,
                                  ),
                                  const SizedBox(width: AppDimens.gapMd),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Total Spent',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${bal.totalSpend.toStringAsFixed(0)}',
                                          style:
                                              AppTextStyles.title.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      // Amount Input
                      AppTextField(
                        controller: controller.amountController,
                        label: 'Amount to add (₹)',
                        hint: 'e.g. 200',
                        prefixIcon: Icons.currency_rupee,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: Validators.amount,
                      ),
                      const SizedBox(height: AppDimens.gapSm),

                      // Quick Amount Chips
                      Wrap(
                        spacing: AppDimens.gapSm,
                        runSpacing: AppDimens.gapSm,
                        children: [100, 200, 500, 1000].map((amt) {
                          return ActionChip(
                            avatar: const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: Text(
                              '₹$amt',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: AppColors.primarySoft,
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusPill),
                            ),
                            onPressed: () {
                              controller.amountController.text = '$amt';
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppDimens.gapLg),

                      Obx(
                        () => AppButton(
                          label: 'Recharge Student Wallet',
                          icon: Icons.account_balance_wallet_rounded,
                          isLoading: controller.isSaving.value,
                          onPressed: controller.recharge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.gapXl),

              // Recharge Transaction History
              const SectionHeader(title: 'Recharge History'),
              const SizedBox(height: AppDimens.gapSm),

              Obx(() {
                if (controller.isLoadingHistory.value) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppDimens.gapXl),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final history = controller.rechargeHistory;
                if (history.isEmpty) {
                  return AppCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimens.gapLg,
                        ),
                        child: Text(
                          controller.aadharController.text.isEmpty
                              ? 'Enter student Aadhar number above to view recharge history.'
                              : 'No recharge transactions recorded for this student.',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: history.map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.successGreen.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_downward_rounded,
                                color: AppColors.successGreen,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: AppDimens.gapMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recharge #${r.id}',
                                    style: AppTextStyles.subtitle.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormatting.dateTime(r.time),
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '+₹${r.amount.toStringAsFixed(0)}',
                              style: AppTextStyles.subtitle.copyWith(
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
      ),
    ],
  );
  }
}
