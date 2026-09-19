import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import 'operator_fee_approvals_controller.dart';

class OperatorFeeApprovalsScreen
    extends GetView<OperatorFeeApprovalsController> {
  const OperatorFeeApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fee Transaction Approvals')),
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          builder: (context) {
            if (controller.transactions.isEmpty) {
              return const EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No pending transactions',
              );
            }
            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppDimens.screenPadding),
                itemCount: controller.transactions.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppDimens.gapMd),
                itemBuilder: (context, i) {
                  final t = controller.transactions[i];
                  final isDeciding = controller.decidingId.value == t.id;
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${t.amount.toStringAsFixed(0)} · ${t.type.name}',
                          style: AppTextStyles.subtitle,
                        ),
                        if (t.chequeNumber != null)
                          Text(
                            'Cheque #${t.chequeNumber}',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (t.bankName != null)
                          Text(
                            t.bankName!,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        Text(
                          DateFormatting.dateTime(t.submittedAt),
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        if (isDeciding)
                          const Center(child: CircularProgressIndicator())
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.cancelledRed,
                                  side: const BorderSide(
                                    color: AppColors.cancelledRed,
                                  ),
                                ),
                                onPressed: () =>
                                    controller.decide(t.id, approve: false),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: AppDimens.gapSm),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.successGreen,
                                ),
                                onPressed: () =>
                                    controller.decide(t.id, approve: true),
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
