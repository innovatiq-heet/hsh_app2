import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/utils/complaint_category_style.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/status_badge.dart';

/// One complaint in a list: item + category, date, status and comment.
/// Solver lists set [showStudent] to add the student and room line, and may
/// put a status menu in [trailing].
class ComplaintCard extends StatelessWidget {
  final ComplaintResponse complaint;
  final VoidCallback? onTap;
  final bool showStudent;
  final bool staffLabels;
  final Widget? trailing;

  const ComplaintCard({
    super.key,
    required this.complaint,
    this.onTap,
    this.showStudent = false,
    this.staffLabels = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final style = ComplaintCategoryStyle.of(complaint.category);
    final status = complaint.status;
    final student = complaint.student;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Left vertical status accent indicator
          Positioned(
            top: 14,
            bottom: 14,
            left: 0,
            child: Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: status.color,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(3),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(icon: style.icon, color: style.color, size: 38),
                    const SizedBox(width: AppDimens.gapMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            complaint.item,
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${complaint.category} · '
                                  '${DateFormatting.dateOnly(complaint.createdAt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              if (complaint.hasImage) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.image_outlined,
                                  size: 13,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.gapSm),
                    StatusBadge(
                      label: staffLabels ? status.staffLabel : status.label,
                      color: status.color,
                    ),
                    if (trailing != null)
                      trailing!
                    else if (onTap != null) ...[
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textLight,
                      ),
                    ],
                  ],
                ),
                if (showStudent) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [
                            if (student != null && student.name.isNotEmpty)
                              student.name,
                            if (student != null && student.studentCode.isNotEmpty)
                              '#${student.studentCode}',
                            'Room ${complaint.roomId}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (complaint.hasComment) ...[
                  const SizedBox(height: 10),
                  Text(
                    complaint.comment!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
