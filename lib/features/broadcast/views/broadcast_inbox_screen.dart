import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/meta_text.dart';
import '../../shared/widgets/sheet_scaffold.dart';
import '../controllers/broadcast_inbox_controller.dart';

/// Student → More → Announcements.
class BroadcastInboxScreen extends StatefulWidget {
  const BroadcastInboxScreen({super.key});

  @override
  State<BroadcastInboxScreen> createState() => _BroadcastInboxScreenState();
}

class _BroadcastInboxScreenState extends State<BroadcastInboxScreen> {
  final controller = Get.find<BroadcastInboxController>();
  late final Worker _openWorker;

  @override
  void initState() {
    super.initState();
    // A push tap opens its message as soon as the list has it.
    _openWorker = ever<InboxBroadcast?>(controller.openRequest, (item) {
      if (item == null) return;
      controller.openRequest.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(item);
      });
    });
  }

  @override
  void dispose() {
    _openWorker.dispose();
    super.dispose();
  }

  void _open(InboxBroadcast item) {
    controller.markRead(item);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SheetScaffold(
        title: item.title,
        subtitle: [
          if (item.senderName.isNotEmpty) item.senderName,
          if (item.createdAt != null) DateFormatting.dateTime(item.createdAt!),
        ].join(' · '),
        children: [
          SelectableText(item.message, style: AppTextStyles.bodyLg.copyWith(height: 1.45)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: AppRefreshIndicator(
        onRefresh: () => controller.load(showLoading: false),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 300) controller.loadMore();
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverGradientHeader(
                title: 'Announcements',
                subtitle: 'Messages from the hostel office',
                leading: HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                child: Obx(() => HeaderPill(
                      icon: Icons.mark_email_unread_rounded,
                      label: '${controller.unreadCount.value} unread',
                    )),
              ),
              Obx(() {
                if (controller.isLoading.value) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (controller.hasError.value) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load announcements',
                      message: controller.errorMessage.value,
                      actionLabel: 'Retry',
                      onAction: controller.load,
                    ),
                  );
                }
                final items = controller.items;
                if (items.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No announcements yet',
                      message: 'Messages from the hostel office will appear here.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapXl,
                    AppDimens.screenPadding,
                    40,
                  ),
                  sliver: SliverList.builder(
                    itemCount: items.length + (controller.hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppDimens.gapLg),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                        child: _InboxCard(item: items[i], onTap: () => _open(items[i])),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxCard extends StatelessWidget {
  final InboxBroadcast item;
  final VoidCallback onTap;

  const _InboxCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: unread ? Icons.campaign_rounded : Icons.campaign_outlined,
            color: unread ? AppColors.primaryLight : AppColors.textMuted,
            size: 40,
          ),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: AppDimens.gapSm),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppDimens.gapXs),
                Text(
                  item.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary, height: 1.35),
                ),
                const SizedBox(height: AppDimens.gapSm),
                Row(
                  children: [
                    Expanded(
                      child: item.senderName.isEmpty
                          ? const SizedBox.shrink()
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: MetaText(icon: Icons.person_outline_rounded, text: item.senderName),
                            ),
                    ),
                    if (item.createdAt != null)
                      MetaText(icon: Icons.schedule_rounded, text: DateFormatting.relativeTime(item.createdAt!)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
