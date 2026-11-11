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
import '../../shared/widgets/meta_text.dart';
import '../../shared/widgets/status_badge.dart';
import '../controllers/student_forms_controller.dart';
import '../widgets/forms_widgets.dart';

/// Student → Dashboard → Polls & Forms.
class StudentFormsScreen extends GetView<StudentFormsController> {
  const StudentFormsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: AppRefreshIndicator(
        onRefresh: () => controller.load(showLoading: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverGradientHeader(
              title: 'Polls & Forms',
              subtitle: 'Your say in hostel decisions',
              leading: HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              child: Obx(() => HeaderPill(
                    icon: Icons.pending_actions_rounded,
                    label: '${controller.pendingCount} to answer',
                  )),
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
                    title: 'Could not load polls',
                    message: controller.errorMessage.value,
                    actionLabel: 'Retry',
                    onAction: controller.load,
                  ),
                );
              }
              final items = controller.forms;
              if (items.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.how_to_vote_outlined,
                    title: 'Nothing open right now',
                    message: 'Polls and forms from the hostel office will appear here.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapXl, AppDimens.screenPadding, 40),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                    child: _StudentFormCard(
                      form: items[i],
                      onTap: () => Get.toNamed(Routes.studentFormFill, arguments: items[i].id),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StudentFormCard extends StatelessWidget {
  final StudentForm form;
  final VoidCallback onTap;

  const _StudentFormCard({required this.form, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final f = form;
    final needsAnswer = !f.hasSubmitted && f.isMandatory;
    return AppCard(
      onTap: onTap,
      color: needsAnswer ? AppColors.secondarySoft : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Wrap(
                spacing: AppDimens.gapSm,
                runSpacing: AppDimens.gapSm,
                children: [
                  FormKindChip(kind: f.kind),
                  if (f.hasSubmitted)
                    const StatusBadge(label: 'Answered', color: AppColors.successGreen, icon: Icons.check_circle_rounded)
                  else if (f.isMandatory)
                    const StatusBadge(label: 'Required', color: AppColors.errorRed, icon: Icons.priority_high_rounded),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
          ]),
          const SizedBox(height: AppDimens.gapMd),
          Text(f.title, style: AppTextStyles.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (f.description != null) ...[
            const SizedBox(height: AppDimens.gapXs),
            Text(f.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm),
          ],
          if (f.endTime != null) ...[
            const SizedBox(height: AppDimens.gapMd),
            MetaText(icon: Icons.event_outlined, text: 'Closes ${DateFormatting.dateTime(f.endTime!)}'),
          ],
        ],
      ),
    );
  }
}
