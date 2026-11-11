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
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/student_picker_sheet.dart';
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
            Text("Send '${controller.trimmedTitle}' to $n ${n == 1 ? 'student' : 'students'}?"),
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
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send'),
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
                const SectionHeader(title: 'Audience by tag'),
                _TagChips(controller: controller),
                const SizedBox(height: AppDimens.gapXl),
                SectionHeader(
                  title: 'Individual students',
                  actionLabel: 'Add students',
                  onAction: () => StudentPickerSheet.show(context, controller),
                ),
                _SelectedStudents(controller: controller),
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

class _TagChips extends StatelessWidget {
  final BroadcastComposeController controller;

  const _TagChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isTagsLoading.value) {
        return const Padding(
          padding: EdgeInsets.all(AppDimens.gapMd),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (controller.tags.isEmpty) {
        return Text(
          'No tags yet. Create them in Manage User → Student Tags, or add students individually.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
        );
      }
      return Wrap(
        spacing: AppDimens.gapSm,
        runSpacing: AppDimens.gapSm,
        children: [
          for (final t in controller.tags)
            FilterChip(
              selected: controller.selectedTagIds.contains(t.id),
              onSelected: (_) => controller.toggleTag(t.id),
              avatar: Icon(Icons.label_rounded, size: 16, color: t.color),
              label: Text('${t.name} · ${t.studentCount}'),
              selectedColor: t.backgroundColor,
              side: BorderSide(color: t.borderColor),
              showCheckmark: true,
              checkmarkColor: t.color,
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
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
        );
      }
      return Wrap(
        spacing: AppDimens.gapSm,
        runSpacing: AppDimens.gapSm,
        children: [
          for (final s in picked)
            InputChip(
              label: Text('${formatPersonName(s.name)} · ${s.room}'),
              onDeleted: () => controller.removeStudent(s),
              deleteIcon: const Icon(Icons.close_rounded, size: 16),
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
        return _banner(
          icon: Icons.info_outline_rounded,
          color: AppColors.textSecondary,
          child: const Text('Pick at least one tag or student.'),
        );
      }
      if (controller.isPreviewLoading.value) {
        return _banner(
          icon: Icons.groups_rounded,
          color: AppColors.primaryLight,
          child: const Row(
            children: [
              Text('Counting recipients…'),
              SizedBox(width: AppDimens.gapSm),
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        );
      }
      if (controller.previewError.value != null) {
        return _banner(
          icon: Icons.error_outline_rounded,
          color: AppColors.errorRed,
          child: Row(
            children: [
              const Expanded(child: Text("Couldn't count recipients")),
              TextButton(onPressed: controller.refreshPreview, child: const Text('Retry')),
            ],
          ),
        );
      }
      final p = controller.preview.value;
      final names = p.sample.map((s) => formatPersonName(s.name)).join(', ');
      return _banner(
        icon: p.recipientCount > 0 ? Icons.groups_rounded : Icons.person_off_rounded,
        color: p.recipientCount > 0 ? AppColors.successGreen : AppColors.warningOrange,
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
            if (p.noDeviceCount > 0)
              Text(
                '${p.noDeviceCount} without the app (inbox only)',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            if (names.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                p.recipientCount > p.sample.length ? '$names…' : names,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
            if (p.recipientCount == 0)
              Text(
                'No active students match this audience.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
      );
    });
  }

  Widget _banner({required IconData icon, required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.gapLg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: DefaultTextStyle.merge(
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.textPrimary),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
