import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/complaint_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/screens/image_gallery_viewer_screen.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/skeleton_loader.dart';
import '../shared/widgets/status_badge.dart';
import 'complaint_detail_controller.dart';

class ComplaintDetailScreen extends GetView<ComplaintDetailController> {
  const ComplaintDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint Details')),
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
                      Text(c.category, style: AppTextStyles.label),
                      StatusBadge(label: c.status.label, color: c.status.color),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapSm),
                  Text(c.title, style: AppTextStyles.title),
                  const SizedBox(height: AppDimens.gapSm),
                  Text(c.description, style: AppTextStyles.bodyMd),
                  const SizedBox(height: AppDimens.gapMd),
                  Text(
                    'Submitted ${DateFormatting.dateTime(c.submittedAt)}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            if (c.attachments.isNotEmpty) ...[
              const SizedBox(height: AppDimens.gapLg),
              Text('Photos', style: AppTextStyles.subtitle),
              const SizedBox(height: AppDimens.gapSm),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: c.attachments.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppDimens.gapSm),
                  itemBuilder: (context, i) {
                    final a = c.attachments[i];
                    return InkWell(
                      onTap: () => Get.to(
                        () => ImageGalleryViewerScreen(
                          attachments: c.attachments,
                          initialIndex: i,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        child: a.isLocal
                            ? Image.file(
                                a.file!,
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                a.url!,
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (c.feedback != null) ...[
              const SizedBox(height: AppDimens.gapLg),
              AppCard(
                color: AppColors.successGreen.withValues(alpha: 0.06),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resolution Feedback', style: AppTextStyles.subtitle),
                    const SizedBox(height: AppDimens.gapSm),
                    Text(c.feedback!, style: AppTextStyles.bodyMd),
                  ],
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}
