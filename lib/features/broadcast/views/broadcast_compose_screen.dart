import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/string_formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/student_picker_sheet.dart';
import '../../shared/widgets/tag_choice_chip.dart';
import '../controllers/broadcast_compose_controller.dart';

/// Admin → Broadcast → New: write the message, choose the audience, send.
class BroadcastComposeScreen extends GetView<BroadcastComposeController> {
  const BroadcastComposeScreen({super.key});

  Future<void> _confirmAndSend(BuildContext context) async {
    final preview = controller.preview.value;
    final n = preview.recipientCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send broadcast?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Send '${controller.trimmedTitle}' to $n ${n == 1 ? 'student' : 'students'}?",
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
            ),
            if (preview.noDeviceCount > 0) ...[
              const SizedBox(height: AppDimens.gapSm),
              Text(
                "${preview.noDeviceCount} ${preview.noDeviceCount == 1 ? 'has' : 'have'} no device; "
                "they'll see it in the inbox.",
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
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screenPadding,
            AppDimens.gapSm,
            AppDimens.screenPadding,
            AppDimens.gapMd,
          ),
          child: Obx(() => AppButton(
                label: 'Send',
                icon: Icons.send_rounded,
                isLoading: controller.isSending.value,
                onPressed: controller.canSend ? () => _confirmAndSend(context) : null,
              )),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverGradientHeader(
            overline: 'Broadcast',
            title: 'New message',
            subtitle: 'Push + inbox for the students you pick',
            leading: HeaderIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.gapXl,
              AppDimens.screenPadding,
              AppDimens.gapXl,
            ),
            sliver: SliverList.list(
              children: [
                const SectionHeader(title: 'Message'),
                AppCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: controller.titleController,
                        maxLength: BroadcastComposeController.maxTitle,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'e.g. Water supply',
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
                const SizedBox(height: AppDimens.gapXl),
                const SectionHeader(title: 'Audience'),
                _AudienceCard(controller: controller),
                const SizedBox(height: AppDimens.gapXl),
                _ReachBanner(controller: controller),
              ],
            ),
          ),
        ],
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
    return AppCard(
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
            ])),
            if (p.noDeviceCount > 0) ...[
              const SizedBox(height: 2),
              Text('${p.noDeviceCount} without the app (inbox only)', style: AppTextStyles.bodySm),
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
