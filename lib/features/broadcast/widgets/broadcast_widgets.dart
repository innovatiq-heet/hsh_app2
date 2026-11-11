import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/meta_text.dart';
import '../../shared/widgets/status_badge.dart';

/// Sending… / Sent / Failed.
class BroadcastStatusBadge extends StatelessWidget {
  final BroadcastStatus status;

  const BroadcastStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      BroadcastStatus.sending => const StatusBadge(
          label: 'Sending…',
          color: AppColors.pendingBlue,
          icon: Icons.schedule_send_rounded,
        ),
      BroadcastStatus.sent => const StatusBadge(
          label: 'Sent',
          color: AppColors.successGreen,
          icon: Icons.check_circle_rounded,
        ),
      BroadcastStatus.failed => const StatusBadge(
          label: 'Failed',
          color: AppColors.errorRed,
          icon: Icons.error_outline_rounded,
        ),
      BroadcastStatus.unknown => const SizedBox.shrink(),
    };
  }
}

/// Tag pills plus "N individual", describing who a broadcast went to.
class BroadcastAudience extends StatelessWidget {
  final Broadcast broadcast;

  const BroadcastAudience({super.key, required this.broadcast});

  @override
  Widget build(BuildContext context) {
    final individual = broadcast.studentIds.length;
    return Wrap(
      spacing: AppDimens.gapSm,
      runSpacing: AppDimens.gapSm,
      children: [
        for (final t in broadcast.tags) StatusBadge(label: t.name, color: t.color, icon: Icons.sell_rounded),
        if (individual > 0)
          StatusBadge(
            label: '$individual individual',
            color: AppColors.primaryLight,
            icon: Icons.person_rounded,
          ),
      ],
    );
  }
}

/// A number with a caption, for recipient / delivered / read counts.
class BroadcastCount extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  const BroadcastCount({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text('$value', style: AppTextStyles.label.copyWith(color: AppColors.textPrimary)),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}

/// One sent broadcast in the history list.
class BroadcastCard extends StatelessWidget {
  final Broadcast broadcast;
  final VoidCallback onTap;

  const BroadcastCard({super.key, required this.broadcast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = broadcast;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  b.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title,
                ),
              ),
              const SizedBox(width: AppDimens.gapSm),
              BroadcastStatusBadge(status: b.status),
            ],
          ),
          const SizedBox(height: AppDimens.gapXs),
          Text(
            b.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.gapMd),
          BroadcastAudience(broadcast: b),
          const SizedBox(height: AppDimens.gapMd),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppDimens.gapMd,
                  runSpacing: 4,
                  children: [
                    BroadcastCount(icon: Icons.groups_rounded, value: b.recipientCount, label: 'to'),
                    BroadcastCount(
                      icon: Icons.notifications_active_rounded,
                      value: b.pushSent,
                      label: 'pushed',
                      color: AppColors.pendingBlue,
                    ),
                    BroadcastCount(
                      icon: Icons.done_all_rounded,
                      value: b.readCount,
                      label: 'read',
                      color: AppColors.successGreen,
                    ),
                  ],
                ),
              ),
              if (b.createdAt != null)
                MetaText(icon: Icons.schedule_rounded, text: DateFormatting.relativeTime(b.createdAt!)),
            ],
          ),
        ],
      ),
    );
  }
}
