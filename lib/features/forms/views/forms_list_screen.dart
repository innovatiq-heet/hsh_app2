import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../controllers/forms_list_controller.dart';
import '../widgets/forms_widgets.dart';

/// Operator → Forms & Polls.
class FormsListScreen extends GetView<FormsListController> {
  const FormsListScreen({super.key});

  Future<void> _edit([HostelForm? form]) async {
    final saved = await Get.toNamed(Routes.operatorFormEditor, arguments: form);
    if (saved == true) controller.load(showLoading: false);
  }

  Future<void> _confirmDelete(BuildContext context, HostelForm form) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete?'),
        content: Text(
          'Delete "${form.title}" with its ${form.totalResponded} '
          '${form.totalResponded == 1 ? 'response' : 'responses'}? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.delete(form);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New poll or form'),
      ),
      body: AppRefreshIndicator(
        onRefresh: () => controller.load(showLoading: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverGradientHeader(
              overline: 'Hostel office',
              title: 'Forms & Polls',
              subtitle: 'Ask students and see their answers',
              leading: HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              child: Obx(() => HeaderPill(
                    icon: Icons.play_circle_rounded,
                    label: '${controller.countOf(FormStatus.active)} active',
                  )),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapLg, AppDimens.screenPadding, 0),
                child: Obx(() {
                  final f = controller.filter.value;
                  Widget chip(String label, FormStatus? s) => Padding(
                        padding: const EdgeInsets.only(right: AppDimens.gapSm),
                        child: ChoiceChip(
                          label: Text(s == null ? '$label (${controller.forms.length})' : '$label (${controller.countOf(s)})'),
                          selected: f == s,
                          onSelected: (_) => controller.filter.value = s,
                        ),
                      );
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      chip('All', null),
                      chip('Active', FormStatus.active),
                      chip('Upcoming', FormStatus.upcoming),
                      chip('Paused', FormStatus.disabled),
                      chip('Ended', FormStatus.expired),
                    ]),
                  );
                }),
              ),
            ),
            Obx(() {
              if (controller.isLoading.value) {
                return const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()));
              }
              if (controller.hasError.value) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load forms',
                    message: controller.errorMessage.value,
                    actionLabel: 'Retry',
                    onAction: controller.load,
                  ),
                );
              }
              final items = controller.visible;
              if (items.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.how_to_vote_outlined,
                    title: controller.forms.isEmpty ? 'No polls or forms yet' : 'Nothing here',
                    message: controller.forms.isEmpty
                        ? 'Create a quick poll (e.g. dinner choice) or a form with several questions.'
                        : 'Try another filter.',
                    actionLabel: controller.forms.isEmpty ? 'New poll or form' : null,
                    onAction: controller.forms.isEmpty ? _edit : null,
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapLg, AppDimens.screenPadding, 110),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final card = Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                      child: _FormCard(
                        form: items[i],
                        busy: controller.busyIds.contains(items[i].id),
                        onOpen: () => Get.toNamed(Routes.operatorFormAnalytics, arguments: items[i]),
                        onEdit: () => _edit(items[i]),
                        onToggle: () => controller.toggle(items[i]),
                        onDelete: () => _confirmDelete(context, items[i]),
                      ),
                    );
                    return i < 8 ? StaggeredSlideFade(index: i, child: card) : card;
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final HostelForm form;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _FormCard({
    required this.form,
    required this.busy,
    required this.onOpen,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final f = form;
    final rate = f.totalTargeted == 0 ? 0 : (f.totalResponded * 100 / f.totalTargeted).round();
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FormKindChip(kind: f.kind),
              const SizedBox(width: AppDimens.gapSm),
              FormStatusBadge(status: f.status),
              if (f.isMandatory) ...[
                const SizedBox(width: AppDimens.gapSm),
                const Icon(Icons.priority_high_rounded, size: 16, color: AppColors.errorRed),
                Text('Required', style: AppTextStyles.caption.copyWith(color: AppColors.errorRed)),
              ],
              const Spacer(),
              if (busy)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) => switch (v) {
                    'results' => onOpen(),
                    'edit' => onEdit(),
                    'toggle' => onToggle(),
                    _ => onDelete(),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'results', child: Text('Results')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'toggle', child: Text(f.isActive ? 'Pause' : 'Activate')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.errorRed))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          Text(f.title, style: AppTextStyles.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (f.description != null) ...[
            const SizedBox(height: 4),
            Text(f.description!, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppDimens.gapMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 6,
              backgroundColor: AppColors.primarySoft,
              valueColor: const AlwaysStoppedAnimation(AppColors.successGreen),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${f.totalResponded} of ${f.totalTargeted} answered · ${f.totalViewed} viewed · ${f.seenNotAnswered} seen, not answered',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          if (f.startTime != null && f.endTime != null) ...[
            const SizedBox(height: 4),
            Text(
              '${DateFormatting.dateTime(f.startTime!)} → ${DateFormatting.dateTime(f.endTime!)} · ${f.audience.label}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
