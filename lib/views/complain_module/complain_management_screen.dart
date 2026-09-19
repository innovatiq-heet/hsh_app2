import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/complaint_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../storage/session_store.dart';
import '../../utils/date_formatting.dart';
import '../shared/utils/complaint_category_style.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/icon_badge.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/status_badge.dart';
import 'complain_management_controller.dart';

class ComplainManagementScreen extends GetView<ComplainManagementController> {
  const ComplainManagementScreen({super.key});

  Future<void> _logout() async {
    await SessionStore.instance.clear();
    Get.offAllNamed(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Gradient Header
        GradientHeader(
          overline: 'Room Maintenance',
          title: 'Room & Student Lookup',
          subtitle: 'Inspect room complaint history and log on-site staff actions',
          actions: [
            HeaderIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              onPressed: () {
                final room = controller.queryController.text.trim();
                if (room.isNotEmpty) {
                  controller.searchRoom(room);
                } else {
                  controller.loadAll();
                }
              },
            ),
            HeaderIconButton(
              icon: Icons.logout_rounded,
              tooltip: 'Log out',
              onPressed: _logout,
            ),
          ],
          child: Obx(() {
            final count = controller.searchedComplaints.length;
            final room = controller.searchedRoom.value;
            if (room.isEmpty) {
              return const HeaderPill(
                icon: Icons.search_rounded,
                label: 'Search room to view maintenance history',
              );
            }
            return Row(
              children: [
                HeaderPill(
                  icon: Icons.meeting_room_outlined,
                  label: 'Room: $room',
                ),
                const SizedBox(width: AppDimens.gapSm),
                HeaderPill(
                  icon: Icons.history_rounded,
                  label: '$count Complaint${count == 1 ? '' : 's'} Logged',
                ),
              ],
            );
          }),
        ),

        // Main Body Form & History
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screenPadding,
            AppDimens.gapLg,
            AppDimens.screenPadding,
            100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Room Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Room Inspection Query',
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter a room number or student Aadhar to inspect pending and past repairs.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapMd),

                    // Quick Block Selector Chips
                    Obx(
                      () => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ComplainManagementController.blocks.map(
                            (block) {
                              final isSelected =
                                  controller.selectedBlock.value == block;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(right: AppDimens.gapSm),
                                child: ChoiceChip(
                                  label: Text(block),
                                  selected: isSelected,
                                  onSelected: (_) =>
                                      controller.selectBlock(block),
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapMd),

                    // Room Input Field & Search Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: controller.queryController,
                            label: 'Room Number / Aadhar',
                            hint: 'e.g. A-204, B-105...',
                            prefixIcon: Icons.search_rounded,
                          ),
                        ),
                        const SizedBox(width: AppDimens.gapSm),
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Obx(
                            () => AppButton(
                              label: 'Search',
                              icon: Icons.arrow_forward_rounded,
                              isLoading: controller.isSearching.value,
                              onPressed: () => controller.searchRoom(
                                controller.queryController.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.gapLg),

              // Room Summary Metric Card
              Obx(() {
                if (controller.searchedRoom.value.isEmpty) {
                  return const SizedBox.shrink();
                }

                final active = controller.roomActiveCount;
                final resolved = controller.roomResolvedCount;
                final first = controller.searchedComplaints.isNotEmpty
                    ? controller.searchedComplaints.first
                    : null;

                return Column(
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius:
                                      BorderRadius.circular(AppDimens.radiusMd),
                                ),
                                child: const Icon(
                                  Icons.domain_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: AppDimens.gapMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Room ${controller.searchedRoom.value}',
                                      style: AppTextStyles.subtitle.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      first != null
                                          ? 'Occupant: ${first.studentName}'
                                          : 'Hostel Resident Room',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (first != null && first.phone != null) ...[
                                IconButton(
                                  tooltip: 'Call Student',
                                  icon: const Icon(
                                    Icons.phone_outlined,
                                    color: AppColors.primary,
                                  ),
                                  onPressed: () {
                                    Get.snackbar(
                                      'Contact Student',
                                      'Phone: ${first.phone}',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                          const Divider(height: AppDimens.gapLg),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricTile(
                                  label: 'Active Issues',
                                  value: '$active',
                                  color: active > 0
                                      ? AppColors.warningOrange
                                      : AppColors.successGreen,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: AppColors.border,
                              ),
                              Expanded(
                                child: _MetricTile(
                                  label: 'Resolved Issues',
                                  value: '$resolved',
                                  color: AppColors.successGreen,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: AppColors.border,
                              ),
                              Expanded(
                                child: _MetricTile(
                                  label: 'Total Reports',
                                  value:
                                      '${controller.searchedComplaints.length}',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapLg),

                    // Direct Quick Resolution Log Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.handyman_outlined,
                                color: AppColors.secondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Log On-Site Inspection & Fix',
                                style: AppTextStyles.subtitle.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Quickly log an on-site resolution for this room without entering each ticket.',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapMd),
                          AppTextField(
                            controller: controller.quickSolverController,
                            label: 'Technician / Staff Name',
                            hint: 'e.g. Ramesh (Electrician), Raju (Plumber)',
                          ),
                          const SizedBox(height: AppDimens.gapSm),
                          AppTextField(
                            controller: controller.quickResolveNoteController,
                            label: 'Resolution Note & Work Summary',
                            hint: 'e.g. Replaced capacitor, checked fan speed. Working normally.',
                            maxLines: 2,
                          ),
                          const SizedBox(height: AppDimens.gapMd),
                          Obx(() {
                            final target = controller.selectedComplaint.value ??
                                (controller.searchedComplaints.isNotEmpty
                                    ? controller.searchedComplaints.first
                                    : null);
                            final canSubmit = target != null &&
                                target.status != ComplaintStatus.resolved;

                            return AppButton(
                              label: target != null
                                  ? 'Resolve Ticket #${target.id.toUpperCase()}'
                                  : 'No Open Complaints in Room',
                              icon: Icons.check_circle_outline_rounded,
                              isLoading: controller.isSubmitting.value,
                              onPressed: canSubmit
                                  ? () => controller.logOnSiteResolution(target.id)
                                  : null,
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapLg),
                  ],
                );
              }),

              // Room Complaints History Section
              Obx(() {
                final list = controller.searchedComplaints;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title:
                          'Maintenance History (${list.length})',
                    ),
                    const SizedBox(height: AppDimens.gapSm),
                    if (list.isEmpty)
                      const EmptyState(
                        icon: Icons.check_circle_outline_rounded,
                        title: 'No maintenance records found',
                        message:
                            'No complaints are recorded for this room or query.',
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppDimens.gapMd),
                        itemBuilder: (context, index) {
                          final c = list[index];
                          final isSelected =
                              controller.selectedComplaint.value?.id == c.id;
                          final catStyle =
                              ComplaintCategoryStyle.of(c.category);

                          return AppCard(
                            onTap: () {
                              controller.selectedComplaint.value = c;
                            },
                            color: isSelected
                                ? AppColors.primarySoft.withValues(alpha: 0.3)
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconBadge(
                                      icon: catStyle.icon,
                                      color: catStyle.color,
                                    ),
                                    const SizedBox(width: AppDimens.gapMd),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.title,
                                            style: AppTextStyles.subtitle
                                                .copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '#${c.id.toUpperCase()} · ${c.category} · ${DateFormatting.dateOnly(c.submittedAt)}',
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusBadge(
                                      label: c.status.label,
                                      color: c.status.color,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppDimens.gapSm),
                                Text(
                                  c.description,
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (c.feedback != null &&
                                    c.feedback!.isNotEmpty) ...[
                                  const SizedBox(height: AppDimens.gapSm),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.successGreen
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusSm,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: AppColors.successGreen,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Fix: ${c.feedback}',
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: AppColors.successGreen,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.title.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
