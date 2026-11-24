import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/utils/string_formatting.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/status_badge.dart';
import '../controllers/broadcast_detail_controller.dart';
import '../widgets/broadcast_widgets.dart';

/// Admin → Broadcast → one broadcast: full message, counts, recipients,
/// styled to match the Hostel Phonebook executive navy-and-slate theme.
class BroadcastDetailScreen extends GetView<BroadcastDetailController> {
  const BroadcastDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PhonebookTheme.bg,
        body: RefreshIndicator(
          onRefresh: () => controller.load(showLoading: false),
          color: PhonebookTheme.blue,
          backgroundColor: Colors.white,
          child: Obx(() {
            final b = controller.broadcast.value;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: PhonebookHeaderDelegate(
                    overline: 'Broadcast',
                    title: b?.displayTitle ?? 'Broadcast',
                    subtitle: b?.createdAt == null ? null : DateFormatting.dateTime(b!.createdAt!),
                    topPadding: MediaQuery.of(context).padding.top,
                    onLeadingTap: () => Navigator.of(context).maybePop(),
                    pills: b == null
                        ? null
                        : Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              PhonebookHeaderPill(
                                icon: Icons.groups_rounded,
                                label: '${b.recipientCount} recipients',
                              ),
                              PhonebookHeaderPill(
                                icon: Icons.campaign_rounded,
                                label: b.channels.displayLabel,
                              ),
                            ],
                          ),
                  ),
                ),
                if (b == null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: controller.hasError.value
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: EmptyState(
                              icon: Icons.cloud_off_rounded,
                              title: 'Could not load broadcast',
                              message: controller.errorMessage.value,
                              actionLabel: 'Retry',
                              onAction: controller.load,
                            ),
                          )
                        : const Center(child: CircularProgressIndicator(color: PhonebookTheme.blue)),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverList.list(
                      children: [
                        // Message content card
                        PhonebookCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      b.senderName.isEmpty ? 'Sent' : 'Sent by ${b.senderName}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: PhonebookTheme.slate,
                                      ),
                                    ),
                                  ),
                                  BroadcastChannelBadge(channel: b.channels),
                                  const SizedBox(width: 6),
                                  BroadcastStatusBadge(status: b.status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SelectableText(
                                b.message,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: PhonebookTheme.ink,
                                  height: 1.5,
                                ),
                              ),
                              BroadcastImage(url: b.imageUrl),
                              if (b.tags.isNotEmpty || b.studentIds.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                BroadcastAudience(broadcast: b),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Count cards grid
                        _BroadcastCountCards(broadcast: b),

                        if (b.pushFailed > 0) ...[
                          const SizedBox(height: 12),
                          NoticeBanner(
                            icon: Icons.error_outline_rounded,
                            color: AppColors.errorRed,
                            message:
                                '${b.pushFailed} ${b.pushFailed == 1 ? 'push' : 'pushes'} failed. '
                                'They can still read it in their inbox.',
                          ),
                        ],
                        if (b.whatsappFailed > 0) ...[
                          const SizedBox(height: 12),
                          NoticeBanner(
                            icon: Icons.error_outline_rounded,
                            color: AppColors.errorRed,
                            message:
                                '${b.whatsappFailed} ${b.whatsappFailed == 1 ? 'WhatsApp message' : 'WhatsApp messages'} failed to send.',
                          ),
                        ],
                        const SizedBox(height: 18),
                        const PhonebookSectionHeader(title: 'Recipients'),
                        _FilterChips(controller: controller),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  _RecipientList(controller: controller),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _BroadcastCountCards extends StatelessWidget {
  final Broadcast broadcast;

  const _BroadcastCountCards({required this.broadcast});

  @override
  Widget build(BuildContext context) {
    final b = broadcast;
    final cards = <Widget>[
      PhonebookCountCard(
        value: '${b.recipientCount}',
        label: 'Recipients',
        icon: Icons.groups_outlined,
        color: PhonebookTheme.ink,
        bgColor: const Color(0xFFF1F5F9),
      ),
      if (b.channels != BroadcastChannel.whatsapp)
        PhonebookCountCard(
          value: '${b.pushSent}',
          label: 'Pushed',
          icon: Icons.notifications_active_outlined,
          color: PhonebookTheme.blue,
          bgColor: PhonebookTheme.blueSoft,
        ),
      if (b.channels != BroadcastChannel.app)
        PhonebookCountCard(
          value: '${b.whatsappSent}',
          label: 'WhatsApp',
          icon: Icons.chat_outlined,
          color: PhonebookTheme.green,
          bgColor: PhonebookTheme.greenSoft,
        ),
      if (b.channels != BroadcastChannel.whatsapp)
        PhonebookCountCard(
          value: '${b.readCount}',
          label: 'Read',
          icon: Icons.done_all_rounded,
          color: PhonebookTheme.purple,
          bgColor: PhonebookTheme.purpleSoft,
        ),
      if (b.channels == BroadcastChannel.whatsapp)
        PhonebookCountCard(
          value: '${b.noWhatsapp}',
          label: 'No Phone',
          icon: Icons.phone_disabled_outlined,
          color: PhonebookTheme.muted,
          bgColor: const Color(0xFFF1F5F9),
        )
      else
        PhonebookCountCard(
          value: '${b.noDevice}',
          label: 'No device',
          icon: Icons.phonelink_erase_outlined,
          color: PhonebookTheme.muted,
          bgColor: const Color(0xFFF1F5F9),
        ),
    ];

    if (cards.length <= 3) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    // Two clean rows when 4-5 metrics are shown (never cramped on 360px phones).
    final split = (cards.length + 1) ~/ 2;
    final top = cards.sublist(0, split);
    final bottom = cards.sublist(split);
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < top.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: top[i]),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < bottom.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: bottom[i]),
            ],
          ],
        ),
      ],
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

  static const _colors = {
    RecipientFilter.all: PhonebookTheme.blue,
    RecipientFilter.read: PhonebookTheme.green,
    RecipientFilter.unread: PhonebookTheme.amber,
    RecipientFilter.noDevice: PhonebookTheme.muted,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Obx(
        () => Row(
          children: [
            for (final f in RecipientFilter.values)
              PhonebookPillTab(
                label: _labels[f]!,
                selected: controller.filter.value == f,
                color: _colors[f]!,
                onTap: () => controller.filter.value = f,
              ),
          ],
        ),
      ),
    );
  }
}

class _RecipientList extends StatelessWidget {
  final BroadcastDetailController controller;

  const _RecipientList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final b = controller.broadcast.value;
      if (b != null && b.recipients.isEmpty && controller.isLoading.value) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppDimens.gapXl),
            child: Center(child: CircularProgressIndicator(color: PhonebookTheme.blue)),
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        sliver: SliverToBoxAdapter(
          child: PhonebookCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: PhonebookTheme.border),
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
      PushStatus.sent => (Icons.notifications_active_rounded, PhonebookTheme.blue, 'Push sent'),
      PushStatus.failed => (Icons.error_outline_rounded, PhonebookTheme.red, 'Push failed'),
      PushStatus.noDevice => (Icons.phonelink_erase_rounded, PhonebookTheme.muted, 'No device'),
      _ => (Icons.schedule_rounded, PhonebookTheme.muted, 'Pending'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Tooltip(message: tip, child: IconBadge(icon: icon, color: color, size: 38)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPersonName(r.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: PhonebookTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    r.room.isEmpty ? 'No room' : 'Room ${r.room}',
                    if (r.whatsAppStatus != WhatsAppStatus.skipped &&
                        r.whatsAppStatus != WhatsAppStatus.unknown)
                      r.whatsAppStatus == WhatsAppStatus.sent
                          ? 'WA sent'
                          : (r.whatsAppStatus == WhatsAppStatus.noPhone ? 'no WA' : 'WA ${r.whatsAppStatus.name}'),
                    if (r.isRead) 'read ${DateFormatting.relativeTime(r.readAt!)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          r.isRead
              ? const StatusBadge(label: 'Read', color: PhonebookTheme.green, icon: Icons.done_all_rounded)
              : const StatusBadge(label: 'Unread', color: PhonebookTheme.muted),
        ],
      ),
    );
  }
}
