import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/string_formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/student_picker_sheet.dart';
import '../../shared/widgets/tag_choice_chip.dart';
import '../controllers/broadcast_compose_controller.dart';

/// Admin → Broadcast → New: write the message, choose the audience, send.
class BroadcastComposeScreen extends GetView<BroadcastComposeController> {
  const BroadcastComposeScreen({super.key});

  Future<void> _confirmAndSend(BuildContext context) async {
    final preview = controller.preview.value;
    final n = preview.recipientCount;
    final titleText = controller.trimmedTitle.isNotEmpty
        ? "'${controller.trimmedTitle}'"
        : 'this broadcast';
    final channel = controller.selectedChannel.value;
    final channelDesc = channel.displayLabel;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send broadcast?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Send $titleText to $n ${n == 1 ? 'student' : 'students'} via $channelDesc?",
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
            ),
            if (channel != BroadcastChannel.whatsapp && preview.noDeviceCount > 0) ...[
              const SizedBox(height: AppDimens.gapSm),
              Text(
                "${preview.noDeviceCount} ${preview.noDeviceCount == 1 ? 'has' : 'have'} no app installed; "
                "they'll see it in their inbox upon login.",
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (channel != BroadcastChannel.app && preview.noWhatsappCount > 0) ...[
              const SizedBox(height: AppDimens.gapSm),
              Text(
                "${preview.noWhatsappCount} ${preview.noWhatsappCount == 1 ? 'has' : 'have'} no phone number recorded.",
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Send',
            icon: Icons.send_rounded,
            expand: false,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await controller.send();
    if (sent == null || !context.mounted) return;
    final count = sent.recipientCount > 0 ? sent.recipientCount : n;
    AppSnackbar.success('Broadcast Sent', 'Sent to $count ${count == 1 ? 'student' : 'students'}.');
    // Close with Navigator, not Get.back(): that would close the snackbar.
    Navigator.of(context).pop(sent);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PhonebookTheme.bg,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: PhonebookTheme.ink.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Obx(
                () => SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: (controller.canSend && !controller.isSending.value)
                        ? () => _confirmAndSend(context)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PhonebookTheme.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: controller.isSending.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 19),
                    label: const Text(
                      'Send',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: PhonebookHeaderDelegate(
                overline: 'Broadcast',
                title: 'New message',
                subtitle: 'Push, WhatsApp & inbox for the students you pick',
                topPadding: MediaQuery.of(context).padding.top,
                leadingIcon: Icons.close_rounded,
                leadingTooltip: 'Close',
                onLeadingTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              sliver: SliverList.list(
                children: [
                  const PhonebookSectionHeader(title: 'Delivery Channel'),
                  _ChannelSelector(controller: controller),
                  const SizedBox(height: 18),
                  const PhonebookSectionHeader(title: 'Message'),
                  PhonebookCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: controller.titleController,
                          maxLength: BroadcastComposeController.maxTitle,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Title (Optional)',
                            hintText: 'e.g. Water supply (leave blank for quick notice)',
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapSm),
                        TextField(
                          controller: controller.messageController,
                          maxLength: BroadcastComposeController.maxMessage,
                          minLines: 4,
                          maxLines: 10,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            hintText: 'What do students need to know?',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const PhonebookSectionHeader(title: 'Audience'),
                  _AudienceCard(controller: controller),
                  const SizedBox(height: 18),
                  _ReachBanner(controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented delivery channel picker: Both (App & WhatsApp), In-App, or WhatsApp.
class _ChannelSelector extends StatelessWidget {
  final BroadcastComposeController controller;

  const _ChannelSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = controller.selectedChannel.value;
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _buildOption(
              channel: BroadcastChannel.both,
              icon: Icons.campaign_rounded,
              label: 'Both',
              sublabel: 'App + WhatsApp',
              isSelected: current == BroadcastChannel.both,
            ),
            const SizedBox(width: 4),
            _buildOption(
              channel: BroadcastChannel.app,
              icon: Icons.notifications_active_rounded,
              label: 'In-App',
              sublabel: 'Push & Inbox',
              isSelected: current == BroadcastChannel.app,
            ),
            const SizedBox(width: 4),
            _buildOption(
              channel: BroadcastChannel.whatsapp,
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              sublabel: 'Direct Chat',
              isSelected: current == BroadcastChannel.whatsapp,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildOption({
    required BroadcastChannel channel,
    required IconData icon,
    required String label,
    required String sublabel,
    required bool isSelected,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => controller.setChannel(channel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
                Text(
                  sublabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tags and individually picked students, in one card.
class _AudienceCard extends StatelessWidget {
  final BroadcastComposeController controller;

  const _AudienceCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return PhonebookCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SubHeading(icon: Icons.sell_rounded, title: 'By tag'),
          const SizedBox(height: AppDimens.gapMd),
          _TagChips(controller: controller),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.gapLg),
            child: Divider(),
          ),
          _SubHeading(
            icon: Icons.person_rounded,
            title: 'Individual students',
            action: TextButton.icon(
              onPressed: () => StudentPickerSheet.show(context, controller),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: AppTextStyles.label,
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add'),
            ),
          ),
          const SizedBox(height: AppDimens.gapSm),
          _SelectedStudents(controller: controller),
        ],
      ),
    );
  }
}

/// Small icon + label heading inside a card, with an optional action.
class _SubHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? action;

  const _SubHeading({required this.icon, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryLight),
          const SizedBox(width: AppDimens.gapSm),
          Expanded(child: Text(title, style: AppTextStyles.subtitle)),
          ?action,
        ],
      ),
    );
  }
}

class _TagChips extends StatelessWidget {
  final BroadcastComposeController controller;

  const _TagChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isTagsLoading.value) {
        return const Padding(
          padding: EdgeInsets.all(AppDimens.gapSm),
          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
        );
      }
      if (controller.tags.isEmpty) {
        return Text(
          'No tags yet. Create them in Manage User → Student Tags, or add students individually.',
          style: AppTextStyles.bodySm,
        );
      }
      return Wrap(
        spacing: AppDimens.gapSm,
        runSpacing: AppDimens.gapSm,
        children: [
          for (final t in controller.tags)
            TagChoiceChip(
              tag: t,
              selected: controller.selectedTagIds.contains(t.id),
              onTap: () => controller.toggleTag(t.id),
            ),
        ],
      );
    });
  }
}

class _SelectedStudents extends StatelessWidget {
  final BroadcastComposeController controller;

  const _SelectedStudents({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final picked = controller.selectedStudents;
      if (picked.isEmpty) {
        return Text(
          'None picked. Students with a selected tag are included automatically.',
          style: AppTextStyles.bodySm,
        );
      }
      return Wrap(
        spacing: AppDimens.gapSm,
        runSpacing: AppDimens.gapSm,
        children: [
          for (final s in picked)
            InputChip(
              label: Text(s.room.isEmpty ? formatPersonName(s.name) : '${formatPersonName(s.name)} · ${s.room}'),
              onDeleted: () => controller.removeStudent(s),
              deleteIcon: const Icon(Icons.close_rounded, size: 16),
              deleteIconColor: AppColors.textMuted,
            ),
        ],
      );
    });
  }
}

class _ReachBanner extends StatelessWidget {
  final BroadcastComposeController controller;

  const _ReachBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.hasAudience) {
        return const NoticeBanner(
          icon: Icons.info_outline_rounded,
          color: AppColors.textSecondary,
          message: 'Pick at least one tag or student.',
        );
      }
      if (controller.isPreviewLoading.value) {
        return const NoticeBanner(
          icon: Icons.groups_rounded,
          action: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          child: Text('Counting recipients…'),
        );
      }
      if (controller.previewError.value != null) {
        return NoticeBanner(
          icon: Icons.error_outline_rounded,
          color: AppColors.errorRed,
          message: "Couldn't count recipients",
          action: TextButton(
            onPressed: controller.refreshPreview,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Retry'),
          ),
        );
      }
      final p = controller.preview.value;
      final names = p.sample.map((s) => formatPersonName(s.name)).join(', ');
      final reach = p.recipientCount > 0;
      final channel = controller.selectedChannel.value;
      return NoticeBanner(
        icon: reach ? Icons.groups_rounded : Icons.person_off_rounded,
        color: reach ? AppColors.successGreen : AppColors.warningOrange,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'Will reach '),
              TextSpan(
                text: '${p.recipientCount} ${p.recipientCount == 1 ? 'student' : 'students'}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: ' via ${channel.displayLabel}'),
            ])),
            if (channel != BroadcastChannel.whatsapp && p.noDeviceCount > 0) ...[
              const SizedBox(height: 2),
              Text('${p.noDeviceCount} without the app (inbox only)', style: AppTextStyles.bodySm),
            ],
            if (channel != BroadcastChannel.app && p.noWhatsappCount > 0) ...[
              const SizedBox(height: 2),
              Text('${p.noWhatsappCount} without phone number recorded', style: AppTextStyles.bodySm),
            ],
            if (names.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                p.recipientCount > p.sample.length ? '$names…' : names,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
              ),
            ],
            if (!reach) ...[
              const SizedBox(height: 2),
              Text('No active students match this audience.', style: AppTextStyles.bodySm),
            ],
          ],
        ),
      );
    });
  }
}
