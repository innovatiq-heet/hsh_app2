import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/laundry_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/status_badge.dart';
import 'laundry_orders_controller.dart';

class LaundryOrdersScreen extends GetView<LaundryOrdersController> {
  const LaundryOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          child: Obx(
            () => Wrap(
              spacing: AppDimens.gapSm,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: controller.statusFilter.value == null,
                  onSelected: (_) => controller.statusFilter.value = null,
                ),
                ...LaundryStatus.values.map(
                  (s) => ChoiceChip(
                    label: Text(s.label),
                    selected: controller.statusFilter.value == s,
                    onSelected: (_) => controller.statusFilter.value = s,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Obx(
            () => AsyncStateView(
              isLoading: controller.isLoading.value,
              hasError: controller.hasError.value,
              errorMessage: controller.errorMessage.value,
              onRetry: controller.load,
              builder: (context) {
                final list = controller.filtered;
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.checkroom_outlined,
                    title: 'No tickets found',
                  );
                }
                return RefreshIndicator(
                  onRefresh: controller.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.screenPadding),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDimens.gapMd),
                    itemBuilder: (context, i) {
                      final t = list[i];
                      final isLast = t.status == LaundryStatus.received;
                      final isAdvancing =
                          controller.advancingTicketId.value == t.id;
                      return AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${t.studentName} · ${t.room}',
                                        style: AppTextStyles.subtitle,
                                      ),
                                      StatusBadge(
                                        label: t.status.label,
                                        color: t.status.color,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${t.itemCount} items · ₹${t.totalAmount.toStringAsFixed(0)}',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    DateFormatting.dateTime(t.submittedAt),
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              isAdvancing
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: 'Advance to next stage',
                                      icon: const Icon(
                                        Icons.arrow_circle_right_outlined,
                                        color: AppColors.primary,
                                      ),
                                      onPressed: () => controller.advance(t.id),
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
        ),
      ],
    );
  }
}
