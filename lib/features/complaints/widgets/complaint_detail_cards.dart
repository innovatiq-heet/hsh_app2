import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/models/attachments/attachment_model.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';
import '../../../core/storage/session_store.dart';
import '../../shared/screens/image_gallery_viewer_screen.dart';
import '../../shared/utils/complaint_category_style.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/stepper_timeline.dart';

/// Submitted → In progress → Resolved → Closed, with the current stage
/// stamped with the last status change.
class ComplaintTimelineCard extends StatelessWidget {
  final ComplaintResponse complaint;

  const ComplaintTimelineCard({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    final status = complaint.status;
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current Status',
                  style: AppTextStyles.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: AppDimens.gapLg),
          StepperTimeline(
            stages: [
              for (final stage in ComplaintStatus.values)
                TimelineStage(
                  label: stage.label,
                  timestamp: stage == ComplaintStatus.open
                      ? complaint.createdAt
                      : (stage == status ? complaint.updatedAt : null),
                  isDone: stage.index <= status.index,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Category, item and the student's comment.
class ComplaintIssueCard extends StatelessWidget {
  final ComplaintResponse complaint;

  const ComplaintIssueCard({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    final style = ComplaintCategoryStyle.of(complaint.category);
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 14, color: style.color),
                    const SizedBox(width: 5),
                    Text(
                      complaint.category,
                      style: AppTextStyles.caption.copyWith(
                        color: style.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'ID: #${complaint.id}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          Text(complaint.item, style: AppTextStyles.headline),
          const SizedBox(height: AppDimens.gapSm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.gapMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Text(
              complaint.hasComment ? complaint.comment! : 'No comment added.',
              style: AppTextStyles.bodyMd.copyWith(
                color: complaint.hasComment
                    ? AppColors.textSecondary
                    : AppColors.textMuted,
                fontStyle:
                    complaint.hasComment ? FontStyle.normal : FontStyle.italic,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The complaint photo. The image endpoint needs the bearer token, so a
/// plain network image would get a 401; tap opens it full screen.
/// Callers show this only when [ComplaintResponse.hasImage].
class ComplaintPhotoCard extends StatelessWidget {
  final ComplaintResponse complaint;

  const ComplaintPhotoCard({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    final token = Get.find<SessionStore>().currentToken ?? '';
    final attachment = AttachmentModel(
      url: complaint.absoluteImageUrl,
      headers: {'Authorization': 'Bearer $token'},
    );

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Photo', style: AppTextStyles.subtitle),
              const Spacer(),
              Text(
                'Tap to zoom',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          InkWell(
            onTap: () => Get.to(
              () => ImageGalleryViewerScreen(attachments: [attachment]),
            ),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  attachment.url!,
                  headers: attachment.headers,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const ColoredBox(
                          color: AppColors.surfaceMuted,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                  errorBuilder: (context, _, _) => ColoredBox(
                    color: AppColors.surfaceMuted,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Photo could not be loaded',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
