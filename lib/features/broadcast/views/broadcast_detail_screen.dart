import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/utils/string_formatting.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/stat_strip.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../controllers/broadcast_detail_controller.dart';
import '../widgets/broadcast_widgets.dart';

/// Admin → Broadcast → one broadcast: full message, counts, recipients.
class BroadcastDetailScreen extends GetView<BroadcastDetailController> {
  const BroadcastDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: AppRefreshIndicator(
        onRefresh: () => controller.load(showLoading: false),
        child: Obx(() {
          final b = controller.broadcast.value;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverGradientHeader(
                overline: 'Broadcast',
                title: b?.title ?? 'Broadcast',
                titleMaxLines: 2,
                subtitle: b?.createdAt == null ? null : DateFormatting.dateTime(b!.createdAt!),
                leading: HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              if (b == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: controller.hasError.value
                      ? EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Could not load broadcast',
                          message: controller.errorMessage.value,
                          actionLabel: 'Retry',
                          onAction: controller.load,
                        )
                      : const Center(child: CircularProgressIndicator()),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapXl,
                    AppDimens.screenPadding,
                    0,
                  ),
                  sliver: SliverList.list(children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  b.senderName.isEmpty ? 'Sent' : 'Sent by ${b.senderName}',
                                  style: AppTextStyles.label,
                                ),
                              ),
                              BroadcastStatusBadge(status: b.status),
                            ],
                          ),
                          const SizedBox(height: AppDimens.gapMd),
                          SelectableText(b.message, style: AppTextStyles.bodyLg),
                          const SizedBox(height: AppDimens.gapLg),
                          BroadcastAudience(broadcast: b),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    StatStrip(items: [
                      StatStripItem(value: '${b.recipientCount}', label: 'Recipients'),
                      StatStripItem(value: '${b.pushSent}', label: 'Pushed', color: AppColors.pendingBlue),
                      StatStripItem(value: '${b.readCount}', label: 'Read', color: AppColors.successGreen),
                      StatStripItem(value: '${b.noDevice}', label: 'No device', color: AppColors.textMuted),
                    ]),
                    if (b.pushFailed > 0) ...[
                      const SizedBox(height: AppDimens.gapMd),
                      NoticeBanner(
                        icon: Icons.error_outline_rounded,
                        color: AppColors.errorRed,
                        message: '${b.pushFailed} ${b.pushFailed == 1 ? 'push' : 'pushes'} failed. '
                            'They can still read it in their inbox.',
                      ),
                    ],
                    const SizedBox(height: AppDimens.gapXl),
                    const SectionHeader(title: 'Recipients'),
                    _FilterChips(controller: controller),
                    const SizedBox(height: AppDimens.gapMd),
                  ]),
                ),
                _RecipientList(controller: controller),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final BroadcastDetailController controller;

  const _FilterChips({required this.controller});

  static const _labels = {
    RecipientFilter.all: 'All',
    RecipientFilter.read: 'Read',
    RecipientFilter.unread: 'Unread',
    RecipientFilter.noDevice: 'No device',
  };

  @override
  Widget build(BuildContext context) {
    return Obx(() => Wrap(
          spacing: AppDimens.gapSm,
          children: [
            for (final f in RecipientFilter.values)
              ChoiceChip(
                label: Text(_labels[f]!),
                selected: controller.filter.value == f,
                onSelected: (_) => controller.filter.value = f,
              ),
          ],
        ));
  }
}

class _RecipientList extends StatelessWidget {
  final BroadcastDetailController controller;

  const _RecipientList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final b = controller.broadcast.value;
      // The summary from history has no recipients yet; wait for the detail.
      if (b != null && b.recipients.isEmpty && controller.isLoading.value) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppDimens.gapXl),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      final list = controller.visibleRecipients;
      if (list.isEmpty) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppDimens.gapXl),
            child: EmptyState(icon: Icons.people_outline_rounded, title: 'No recipients here'),
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, 0, AppDimens.screenPadding, 40),
        sliver: SliverToBoxAdapter(
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardPadding, vertical: AppDimens.gapXs),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const Divider(color: AppColors.borderLight),
                  _RecipientRow(recipient: list[i]),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _RecipientRow extends StatelessWidget {
  final BroadcastRecipient recipient;

  const _RecipientRow({required this.recipient});

  @override
  Widget build(BuildContext context) {
    final r = recipient;
    final (IconData icon, Color color, String tip) = switch (r.pushStatus) {
      PushStatus.sent => (Icons.notifications_active_rounded, AppColors.pendingBlue, 'Push sent'),
      PushStatus.failed => (Icons.error_outline_rounded, AppColors.errorRed, 'Push failed'),
      PushStatus.noDevice => (Icons.phonelink_erase_rounded, AppColors.textMuted, 'No device'),
      _ => (Icons.schedule_rounded, AppColors.textMuted, 'Pending'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.gapMd),
      child: Row(
        children: [
          Tooltip(message: tip, child: IconBadge(icon: icon, color: color, size: 38)),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPersonName(r.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    r.room.isEmpty ? 'No room' : 'Room ${r.room}',
                    if (r.isRead) 'read ${DateFormatting.relativeTime(r.readAt!)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.gapSm),
          r.isRead
              ? const StatusBadge(label: 'Read', color: AppColors.successGreen, icon: Icons.done_all_rounded)
              : const StatusBadge(label: 'Unread', color: AppColors.textMuted),
        ],
      ),
    );
  }
}
