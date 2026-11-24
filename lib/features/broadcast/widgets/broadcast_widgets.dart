import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/meta_text.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/status_badge.dart';

/// The picture of a broadcast (inbox message, admin detail). Draws nothing
/// when [url] is null, so it can sit under every message. Tap to zoom.
class BroadcastImage extends StatelessWidget {
  final String? url;
  final double maxHeight;

  const BroadcastImage({super.key, required this.url, this.maxHeight = 240});

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _BroadcastImageViewer(url: u)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Image.network(
              u,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (c, child, progress) => progress == null
                  ? child
                  : SizedBox(
                      height: maxHeight / 2,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
              errorBuilder: (c, e, s) => const SizedBox(
                height: 56,
                child: Center(child: Text('Picture unavailable')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BroadcastImageViewer extends StatelessWidget {
  final String url;

  const _BroadcastImageViewer({required this.url});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(child: InteractiveViewer(child: Image.network(url))),
      );
}

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

/// Channel badge: Both / In-App / WhatsApp.
class BroadcastChannelBadge extends StatelessWidget {
  final BroadcastChannel channel;

  const BroadcastChannelBadge({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return switch (channel) {
      BroadcastChannel.both => const StatusBadge(
          label: 'App + WA',
          color: AppColors.primaryDark,
          icon: Icons.campaign_rounded,
        ),
      BroadcastChannel.app => const StatusBadge(
          label: 'In-App',
          color: AppColors.primaryLight,
          icon: Icons.notifications_active_rounded,
        ),
      BroadcastChannel.whatsapp => const StatusBadge(
          label: 'WhatsApp',
          color: AppColors.successGreen,
          icon: Icons.chat_rounded,
        ),
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
    return PhonebookCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  b.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: PhonebookTheme.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.gapSm),
              BroadcastChannelBadge(channel: b.channels),
              const SizedBox(width: 6),
              BroadcastStatusBadge(status: b.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            b.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              color: PhonebookTheme.slate,
              height: 1.4,
            ),
          ),
          if (b.tags.isNotEmpty || b.studentIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            BroadcastAudience(broadcast: b),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: PhonebookTheme.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppDimens.gapMd,
                  runSpacing: 4,
                  children: [
                    BroadcastCount(icon: Icons.groups_rounded, value: b.recipientCount, label: 'to'),
                    if (b.channels != BroadcastChannel.whatsapp)
                      BroadcastCount(
                        icon: Icons.notifications_active_rounded,
                        value: b.pushSent,
                        label: 'pushed',
                        color: PhonebookTheme.blue,
                      ),
                    if (b.channels != BroadcastChannel.app)
                      BroadcastCount(
                        icon: Icons.chat_rounded,
                        value: b.whatsappSent,
                        label: 'WA',
                        color: PhonebookTheme.green,
                      ),
                    if (b.channels != BroadcastChannel.whatsapp)
                      BroadcastCount(
                        icon: Icons.done_all_rounded,
                        value: b.readCount,
                        label: 'read',
                        color: PhonebookTheme.blue,
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
