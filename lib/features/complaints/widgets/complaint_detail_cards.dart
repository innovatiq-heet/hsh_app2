import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/models/attachments/attachment_model.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';
import '../../../core/storage/session_store.dart';
import '../../shared/screens/image_gallery_viewer_screen.dart';
import '../../shared/utils/complaint_category_style.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
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
    return PhonebookCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Current Status',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: PhonebookTheme.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: 16),
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
    return PhonebookCard(
      padding: const EdgeInsets.all(16),
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
                      style: TextStyle(
                        fontSize: 12,
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PhonebookTheme.muted,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            complaint.item,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: PhonebookTheme.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PhonebookTheme.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PhonebookTheme.border),
            ),
            child: Text(
              complaint.hasComment ? complaint.comment! : 'No comment added.',
              style: TextStyle(
                fontSize: 13.5,
                color: complaint.hasComment
                    ? PhonebookTheme.slate
                    : PhonebookTheme.muted,
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

    return PhonebookCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Photo',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: PhonebookTheme.ink,
                ),
              ),
              Spacer(),
              Text(
                'Tap to zoom',
                style: TextStyle(
                  fontSize: 12,
                  color: PhonebookTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => Get.to(
              () => ImageGalleryViewerScreen(attachments: [attachment]),
            ),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  attachment.url!,
                  headers: attachment.headers,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const ColoredBox(
                          color: PhonebookTheme.bg,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: PhonebookTheme.blue,
                            ),
                          ),
                        ),
                  errorBuilder: (context, _, _) => const ColoredBox(
                    color: PhonebookTheme.bg,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: PhonebookTheme.muted,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Photo could not be loaded',
                            style: TextStyle(
                              fontSize: 12,
                              color: PhonebookTheme.muted,
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
