import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/payment_type.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/currency_formatting.dart';
import '../../utils/date_formatting.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/date_time_picker_field.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import 'pay_now_controller.dart';

class PayNowScreen extends GetView<PayNowController> {
  const PayNowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: Form(
        key: controller.formKey,
        child: CustomScrollView(
          slivers: [
            // Top Hero Header
            SliverGradientHeader(
              overline: 'Hostel Fee Portal',
              title: 'Make Payment',
              subtitle: 'Submit fee payment or bank transfer slip',
              expandedHeight: 250.0,
              leading: HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Get.back(),
              ),
              child: _OutstandingCard(controller: controller),
            ),

            SliverToBoxAdapter(
              child: Padding(
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment Mode Selection Header
                  const SectionHeader(
                    title: 'Payment Method',
                    actionLabel: 'Verified Gateways',
                  ),
                  const SizedBox(height: AppDimens.gapMd),

                  // Method selection cards
                  Obx(
                    () => Column(
                      children: [
                        _PaymentMethodCard(
                          title: 'UPI / Online Transfer',
                          subtitle: 'GPay, PhonePe, Paytm, or BHIM UPI',
                          icon: Icons.qr_code_scanner_rounded,
                          isSelected: controller.selectedType.value ==
                              PaymentType.online,
                          badgeText: 'Instant',
                          onTap: () => controller.selectedType.value =
                              PaymentType.online,
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        _PaymentMethodCard(
                          title: 'Cheque / Demand Draft',
                          subtitle: 'Payable to Hari Saurabh Hostel Trust',
                          icon: Icons.receipt_long_rounded,
                          isSelected: controller.selectedType.value ==
                              PaymentType.cheque,
                          onTap: () => controller.selectedType.value =
                              PaymentType.cheque,
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        _PaymentMethodCard(
                          title: 'Cash at Counter',
                          subtitle: 'Pay directly at Hostel Warden Office',
                          icon: Icons.payments_outlined,
                          isSelected:
                              controller.selectedType.value == PaymentType.cash,
                          onTap: () => controller.selectedType.value =
                              PaymentType.cash,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.gapXl),

                  // Contextual details for the selected mode
                  Obx(() {
                    switch (controller.selectedType.value) {
                      case PaymentType.online:
                        return _UpiPaymentSection(controller: controller);
                      case PaymentType.cheque:
                        return _ChequePaymentSection(controller: controller);
                      case PaymentType.cash:
                        return _CashPaymentSection(controller: controller);
                    }
                  }),

                  const SizedBox(height: AppDimens.gapXl),

                  // Amount & Narration
                  const SectionHeader(title: 'Amount & Remarks'),
                  const SizedBox(height: AppDimens.gapMd),

                  AppTextField(
                    controller: controller.amountController,
                    label: 'Amount to Pay',
                    hint: 'Enter amount in Rupees',
                    prefixIcon: Icons.currency_rupee_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: Validators.amount,
                  ),

                  const SizedBox(height: AppDimens.gapMd),

                  AppTextField(
                    controller: controller.narrationController,
                    label: 'Narration / Remarks (optional)',
                    hint: 'e.g. 1st Term Room Rent + Mess fee',
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 2,
                  ),

                  const SizedBox(height: AppDimens.gapXl),

                  // Proof Screenshot / Photo Upload
                  const SectionHeader(
                    title: 'Payment Proof (Optional)',
                    actionLabel: 'Screenshot/Photo',
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  _ProofAttachmentWidget(controller: controller),

                  const SizedBox(height: AppDimens.gapXxl),

                  // Submit Button
                  Obx(
                    () => AppButton(
                      label: 'Submit Payment Slip',
                      icon: Icons.check_circle_outline_rounded,
                      isLoading: controller.isSaving.value,
                      onPressed: () async {
                        final txn = await controller.submit();
                        if (txn != null) {
                          Get.offNamed(Routes.feeReceipt, arguments: txn);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: AppDimens.gapLg),
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

/// Header banner displaying outstanding net due with quick preset chips
class _OutstandingCard extends StatelessWidget {
  final PayNowController controller;

  const _OutstandingCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final due = controller.netDue;

    return Container(
      padding: const EdgeInsets.all(AppDimens.gapLg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CURRENT OUTSTANDING DUE',
                style: AppTextStyles.overline.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  border: Border.all(color: AppColors.warningOrange),
                ),
                child: Text(
                  'Due for 2025-26',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          Text(
            Money.format(due),
            style: AppTextStyles.displayLg.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppDimens.gapMd),
          Text(
            'Quick select payment amount:',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: AppDimens.gapSm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _AmountChip(
                  label: 'Full Due (${Money.format(due)})',
                  onTap: () => controller.selectAmount(due),
                ),
                const SizedBox(width: AppDimens.gapSm),
                _AmountChip(
                  label: '₹10,000',
                  onTap: () => controller.selectAmount(10000),
                ),
                const SizedBox(width: AppDimens.gapSm),
                _AmountChip(
                  label: '₹5,000',
                  onTap: () => controller.selectAmount(5000),
                ),
                const SizedBox(width: AppDimens.gapSm),
                _AmountChip(
                  label: '₹2,500',
                  onTap: () => controller.selectAmount(2500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AmountChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Selectable payment method card
class _PaymentMethodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final String? badgeText;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.gapLg),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft.withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppDimens.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: AppDimens.gapSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusSm),
                          ),
                          child: Text(
                            badgeText!,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.successGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// UPI details & UTR input
class _UpiPaymentSection extends StatelessWidget {
  final PayNowController controller;

  const _UpiPaymentSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Hostel UPI Information',
          actionLabel: 'Scan or Copy',
        ),
        const SizedBox(height: AppDimens.gapMd),
        AppCard(
          padding: const EdgeInsets.all(AppDimens.gapLg),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hostel VPA / UPI ID', style: AppTextStyles.caption),
                        const SizedBox(height: 2),
                        Text(
                          PayNowController.upiId,
                          style: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          PayNowController.upiName,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copy UPI ID',
                    onPressed: () => controller.copyToClipboard(
                      PayNowController.upiId,
                      'UPI ID',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.gapMd),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimens.gapSm + 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  '1. Pay via any UPI App -> 2. Copy the 12-digit UTR/Reference ID -> 3. Paste below',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapLg),
        AppTextField(
          controller: controller.transactionRefController,
          label: 'UPI Ref ID / UTR Number *',
          hint: 'e.g. 524391823910 or UPI-Ref',
          prefixIcon: Icons.confirmation_number_outlined,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: AppDimens.gapMd),
        AppTextField(
          controller: controller.bankNameController,
          label: 'UPI App Name (optional)',
          hint: 'e.g. Google Pay, PhonePe, Paytm, ICICI iMobile',
          prefixIcon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }
}

/// Cheque payment details
class _ChequePaymentSection extends StatelessWidget {
  final PayNowController controller;

  const _ChequePaymentSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Cheque Information'),
        const SizedBox(height: AppDimens.gapMd),
        AppTextField(
          controller: controller.chequeNumberController,
          label: 'Cheque Number *',
          hint: '6 digit number e.g. 000123',
          prefixIcon: Icons.receipt_rounded,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppDimens.gapMd),
        Obx(
          () => DateTimePickerField(
            label: 'Cheque Date *',
            displayValue: controller.chequeDate.value == null
                ? null
                : DateFormatting.dateOnly(controller.chequeDate.value!.toUtc()),
            onTap: () => controller.pickChequeDate(context),
          ),
        ),
        const SizedBox(height: AppDimens.gapMd),
        AppTextField(
          controller: controller.bankNameController,
          label: 'Bank & Branch Name',
          hint: 'e.g. HDFC Bank, Navrangpura Branch',
          prefixIcon: Icons.account_balance_outlined,
        ),
      ],
    );
  }
}

/// Cash counter instructions
class _CashPaymentSection extends StatelessWidget {
  final PayNowController controller;

  const _CashPaymentSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.gapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: const Icon(
                  Icons.store_mall_directory_outlined,
                  color: AppColors.successGreen,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hostel Accounts Counter',
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Mon - Sat: 9:00 AM - 5:00 PM',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          Text(
            'Deposit the exact cash at the hostel accounts counter. Enter the deposited amount below and submit to record your cash entry request.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Proof attachment picker with preview
class _ProofAttachmentWidget extends StatelessWidget {
  final PayNowController controller;

  const _ProofAttachmentWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final path = controller.attachedProofPath.value;
      if (path == null) {
        return InkWell(
          onTap: controller.pickProofImage,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppDimens.gapLg,
              horizontal: AppDimens.gapMd,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(height: AppDimens.gapSm),
                Text(
                  'Upload Payment Screenshot or Slip',
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PNG, JPG up to 5MB',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(AppDimens.gapMd),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: AppColors.successGreen),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              child: Image.file(
                File(path),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded),
              ),
            ),
            const SizedBox(width: AppDimens.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slip Attached',
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    path.split(Platform.pathSeparator).last,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.cancelledRed),
              onPressed: controller.removeProof,
            ),
          ],
        ),
      );
    });
  }
}
