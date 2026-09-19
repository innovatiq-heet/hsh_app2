import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/complaint_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/skeleton_loader.dart';
import '../shared/widgets/status_badge.dart';
import 'complain_admin_detail_controller.dart';

class ComplainAdminDetailScreen extends GetView<ComplainAdminDetailController> {
  const ComplainAdminDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint — Review')),
      body: Obx(() {
        if (controller.isLoading.value) return const SkeletonList();
        final c = controller.complaint.value;
        if (c == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${c.studentName} · Room ${c.room}',
                        style: AppTextStyles.label,
                      ),
                      StatusBadge(label: c.status.label, color: c.status.color),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapSm),
                  Text(c.title, style: AppTextStyles.title),
                  const SizedBox(height: AppDimens.gapSm),
                  Text(c.description, style: AppTextStyles.bodyMd),
                  const SizedBox(height: AppDimens.gapMd),
                  Text(
                    'Category: ${c.category}',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Submitted ${DateFormatting.dateTime(c.submittedAt)}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),
            Text('Update Status', style: AppTextStyles.subtitle),
            const SizedBox(height: AppDimens.gapSm),
            Wrap(
              spacing: AppDimens.gapSm,
              children: ComplaintStatus.values.map((s) {
                return ChoiceChip(
                  label: Text(s.label),
                  selected: c.status == s,
                  onSelected: (_) => controller.setStatus(s),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimens.gapLg),
            Text('Feedback', style: AppTextStyles.subtitle),
            const SizedBox(height: AppDimens.gapSm),
            if (c.feedback != null) ...[
              AppCard(
                color: AppColors.successGreen.withValues(alpha: 0.06),
                child: Text(c.feedback!, style: AppTextStyles.bodyMd),
              ),
              const SizedBox(height: AppDimens.gapSm),
            ],
            AppTextField(
              controller: controller.feedbackController,
              label: 'Add feedback / resolution note',
              maxLines: 3,
            ),
            const SizedBox(height: AppDimens.gapMd),
            Obx(
              () => AppButton(
                label: 'Submit Feedback',
                isLoading: controller.isSaving.value,
                onPressed: controller.submitFeedback,
              ),
            ),
          ],
        );
      }),
    );
  }
}
