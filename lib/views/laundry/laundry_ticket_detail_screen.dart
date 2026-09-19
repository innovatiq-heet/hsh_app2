import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/laundry_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/skeleton_loader.dart';
import '../shared/widgets/status_badge.dart';
import '../shared/widgets/stepper_timeline.dart';
import 'laundry_ticket_detail_controller.dart';

class LaundryTicketDetailScreen extends GetView<LaundryTicketDetailController> {
  const LaundryTicketDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Details')),
      body: Obx(() {
        if (controller.isLoading.value) return const SkeletonList();
        final t = controller.ticket.value;
        if (t == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          children: [
            AppCard(
              child: Column(
                children: [
                  StepperTimeline(
                    stages: [
                      TimelineStage(
                        label: 'Submitted',
                        timestamp: t.submittedAt,
                        isDone: true,
                      ),
                      TimelineStage(
                        label: 'Accepted',
                        timestamp: t.acceptedAt,
                        isDone: t.acceptedAt != null,
                      ),
                      TimelineStage(
                        label: 'Washed',
                        timestamp: t.washedAt,
                        isDone: t.washedAt != null,
                      ),
                      TimelineStage(
                        label: 'Received',
                        timestamp: t.receivedAt,
                        isDone: t.receivedAt != null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ticket #${t.id}', style: AppTextStyles.title),
                      StatusBadge(label: t.status.label, color: t.status.color),
                    ],
                  ),
                  const Divider(height: AppDimens.gapXl),
                  _row('Student', t.studentName),
                  _row('Room', t.room),
                  _row('Items', '${t.itemCount}'),
                  _row('Total Amount', '₹${t.totalAmount.toStringAsFixed(0)}'),
                  _row('Submitted', DateFormatting.dateTime(t.submittedAt)),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTextStyles.bodyMd,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
