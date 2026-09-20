import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../common_enums/payment_type.dart';
import '../../common_enums/transaction_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/fees/fee_responses.dart';
import '../../utils/currency_formatting.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';

class PaymentReceiptScreen extends StatelessWidget {
  const PaymentReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FeeTransactionResponse? transaction =
        Get.arguments as FeeTransactionResponse?;

    if (transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Receipt')),
        body: const Center(child: Text('No transaction details available.')),
      );
    }

    final receiptNo =
        transaction.receiptNumber ?? 'HSH-REC-${transaction.id.toUpperCase()}';

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Receipt',
            onPressed: () => _showShareSuccess(context, receiptNo),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.gapMd,
          AppDimens.screenPadding,
          AppDimens.gapXxl,
        ),
        child: Column(
          children: [
            // Receipt Card
            AppCard(
              padding: EdgeInsets.zero,
              radius: AppDimens.radiusXl,
              child: Column(
                children: [
                  // Receipt Top Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.gapXl,
                      horizontal: AppDimens.gapLg,
                    ),
                    decoration: const BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppDimens.radiusXl),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        Text(
                          'HARI SAURABH HOSTEL',
                          style: AppTextStyles.overline.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Official Payment Slip',
                          style: AppTextStyles.title.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapLg),
                        Text(
                          Money.format(transaction.amount),
                          style: AppTextStyles.displayXl.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        _StatusPill(status: transaction.status),
                      ],
                    ),
                  ),

                  // Perforated / Cut Divider
                  const _ReceiptDivider(),

                  // Receipt Body
                  Padding(
                    padding: const EdgeInsets.all(AppDimens.gapXl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReceiptRow(
                          label: 'Receipt Number',
                          value: receiptNo,
                          canCopy: true,
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        _ReceiptRow(
                          label: 'Date & Time',
                          value: DateFormatting.dateTime(transaction.submittedAt),
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        _ReceiptRow(
                          label: 'Payment Mode',
                          value: transaction.type.label,
                          leadingIcon: transaction.type.icon,
                        ),
                        if (transaction.transactionRef != null &&
                            transaction.transactionRef!.isNotEmpty) ...[
                          const SizedBox(height: AppDimens.gapMd),
                          _ReceiptRow(
                            label: 'Reference / UTR',
                            value: transaction.transactionRef!,
                            canCopy: true,
                          ),
                        ],
                        if (transaction.chequeNumber != null) ...[
                          const SizedBox(height: AppDimens.gapMd),
                          _ReceiptRow(
                            label: 'Cheque Number',
                            value: '#${transaction.chequeNumber}',
                          ),
                        ],
                        if (transaction.chequeDate != null) ...[
                          const SizedBox(height: AppDimens.gapMd),
                          _ReceiptRow(
                            label: 'Cheque Date',
                            value: DateFormatting.dateOnly(transaction.chequeDate!),
                          ),
                        ],
                        if (transaction.bankName != null &&
                            transaction.bankName!.isNotEmpty) ...[
                          const SizedBox(height: AppDimens.gapMd),
                          _ReceiptRow(
                            label: 'Bank / Channel',
                            value: transaction.bankName!,
                          ),
                        ],
                        if (transaction.narration != null &&
                            transaction.narration!.isNotEmpty) ...[
                          const SizedBox(height: AppDimens.gapMd),
                          _ReceiptRow(
                            label: 'Remarks',
                            value: transaction.narration!,
                          ),
                        ],

                        const SizedBox(height: AppDimens.gapLg),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: AppDimens.gapLg),

                        // Ledger allocation card
                        Container(
                          padding: const EdgeInsets.all(AppDimens.gapMd),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMd),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius:
                                      BorderRadius.circular(AppDimens.radiusSm),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppDimens.gapMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Account Ledger Allocation',
                                      style: AppTextStyles.bodySm.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      transaction.status ==
                                              TransactionStatus.approved
                                          ? 'Credited to Student Hostel Account'
                                          : 'Pending approval by Hostel Accounts',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimens.gapXl),

                        // Digitally Verified Stamp
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: AppColors.textMuted.withValues(alpha: 0.6),
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'DIGITALLY GENERATED RECEIPT',
                                style: AppTextStyles.overline.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                'No signature required · Hari Saurabh Hostel ERP',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimens.gapXl),

            // Action Buttons
            AppButton(
              label: 'Download PDF Receipt',
              icon: Icons.download_rounded,
              onPressed: () => _showDownloadSuccess(context, receiptNo),
            ),
            const SizedBox(height: AppDimens.gapMd),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                side: const BorderSide(color: AppColors.primary),
              ),
              icon: const Icon(Icons.share_outlined, color: AppColors.primary),
              label: Text(
                'Share Receipt Slip',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => _showShareSuccess(context, receiptNo),
            ),
            const SizedBox(height: AppDimens.gapSm),
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'Back to Fee Ledger',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDownloadSuccess(BuildContext context, String receiptNo) {
    Get.snackbar(
      'Receipt Downloaded',
      'Saved $receiptNo.pdf to device storage',
      backgroundColor: AppColors.headerBlue,
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle_outline, color: AppColors.successGreen),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(AppDimens.gapMd),
    );
  }

  void _showShareSuccess(BuildContext context, String receiptNo) {
    Clipboard.setData(ClipboardData(text: receiptNo));
    Get.snackbar(
      'Receipt Copied',
      'Receipt details and ID copied to clipboard',
      backgroundColor: AppColors.headerBlue,
      colorText: Colors.white,
      icon: const Icon(Icons.copy_rounded, color: Colors.white),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(AppDimens.gapMd),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final TransactionStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    final Color bgColor;
    final Color textColor;

    switch (status) {
      case TransactionStatus.approved:
        icon = Icons.check_circle_rounded;
        label = 'Verified & Approved';
        bgColor = AppColors.successGreen.withValues(alpha: 0.25);
        textColor = Colors.white;
        break;
      case TransactionStatus.pending:
        icon = Icons.hourglass_top_rounded;
        label = 'Under Operator Verification';
        bgColor = Colors.white.withValues(alpha: 0.2);
        textColor = Colors.white;
        break;
      case TransactionStatus.rejected:
        icon = Icons.cancel_rounded;
        label = 'Payment Rejected';
        bgColor = AppColors.cancelledRed.withValues(alpha: 0.3);
        textColor = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? leadingIcon;
  final bool canCopy;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.leadingIcon,
    this.canCopy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.gapSm),
        Expanded(
          flex: 6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    Get.snackbar(
                      'Copied',
                      '$label copied to clipboard',
                      duration: const Duration(seconds: 2),
                      snackPosition: SnackPosition.BOTTOM,
                      margin: const EdgeInsets.all(AppDimens.gapMd),
                    );
                  },
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dashed line
          LayoutBuilder(
            builder: (context, constraints) {
              const dashWidth = 6.0;
              const dashSpace = 4.0;
              final dashCount =
                  (constraints.maxWidth / (dashWidth + dashSpace)).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(dashCount, (_) {
                  return const SizedBox(
                    width: dashWidth,
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.border),
                    ),
                  );
                }),
              );
            },
          ),
          // Left notch cutout
          Positioned(
            left: -12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.mainBackground,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Right notch cutout
          Positioned(
            right: -12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.mainBackground,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
