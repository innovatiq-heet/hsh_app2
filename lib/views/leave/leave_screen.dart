import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/leave_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/status_badge.dart';
import 'leave_controller.dart';

class LeaveScreen extends GetView<LeaveController> {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave')),
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          builder: (context) {
            if (controller.leaves.isEmpty) {
              return const EmptyState(
                icon: Icons.beach_access_outlined,
                title: 'No leave requests yet',
                message: 'Apply for a leave using the button below.',
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
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            StatusBadge(
                              label: leave.status.label,
                              color: leave.status.color,
                            ),
                            Text(
                              DateFormatting.dateOnly(leave.appliedAt),
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.gapSm),
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
                        if (controller.canCancel(leave)) ...[
                          const SizedBox(height: AppDimens.gapSm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => controller.cancel(leave.id),
                              icon: const Icon(
                                Icons.close,
                                size: 16,
                                color: AppColors.cancelledRed,
                              ),
                              label: const Text(
                                'Cancel',
                                style: TextStyle(color: AppColors.cancelledRed),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Get.toNamed(Routes.leaveAdd)?.then((_) => controller.load()),
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave'),
      ),
    );
  }
}
