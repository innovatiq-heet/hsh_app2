import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import 'operator_leave_approvals_controller.dart';

class OperatorLeaveApprovalsScreen
    extends GetView<OperatorLeaveApprovalsController> {
  const OperatorLeaveApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Approvals')),
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          builder: (context) {
            if (controller.leaves.isEmpty) {
              return const EmptyState(
                icon: Icons.event_available_outlined,
                title: 'No pending leave requests',
              );
            }
            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppDimens.screenPadding),
                itemCount: controller.leaves.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppDimens.gapMd),
                itemBuilder: (context, i) {
                  final leave = controller.leaves[i];
                  final isDeciding = controller.decidingId.value == leave.id;
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormatting.dateOnly(leave.startTime)} → ${DateFormatting.dateOnly(leave.endTime)}',
                          style: AppTextStyles.subtitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          leave.reason,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.textSecondary,
                          ),
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
                                    controller.decide(leave.id, approve: false),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: AppDimens.gapSm),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.successGreen,
                                ),
                                onPressed: () =>
                                    controller.decide(leave.id, approve: true),
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
