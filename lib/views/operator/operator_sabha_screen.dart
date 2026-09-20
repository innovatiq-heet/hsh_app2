import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/date_time_picker_field.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/status_badge.dart';
import 'operator_sabha_controller.dart';

class OperatorSabhaScreen extends GetView<OperatorSabhaController> {
  const OperatorSabhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverGradientHeader(
            overline: 'Event Scheduling',
            title: 'Sabha Sessions',
            subtitle: 'Schedule and manage congregation assemblies',
            expandedHeight: 220.0,
            leading: Navigator.canPop(context)
                ? HeaderIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Get.back(),
                  )
                : null,
            child: Obx(
              () => HeaderPill(
                icon: Icons.event_outlined,
                label: '${controller.sabhas.length} Scheduled Sessions',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapXl,
                AppDimens.screenPadding,
                AppDimens.gapXxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(title: 'Schedule new sabha'),
                  AppCard(
                    padding: const EdgeInsets.all(AppDimens.cardPadding),
                    child: Form(
                      key: controller.formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                    AppTextField(
                      controller: controller.titleController,
                      label: 'Sabha Description / Title',
                      prefixIcon: Icons.event_note_rounded,
                      validator: Validators.required,
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    Obx(
                      () => DateTimePickerField(
                        label: 'Date',
                        icon: Icons.calendar_today_rounded,
                        displayValue: controller.date.value == null
                            ? null
                            : DateFormatting.dateOnly(controller.date.value!),
                        placeholder: 'Select date',
                        onTap: () => controller.pickDate(context),
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    Row(
                      children: [
                        Expanded(
                          child: Obx(
                            () => DateTimePickerField(
                              label: 'Start Time',
                              icon: Icons.schedule_rounded,
                              displayValue:
                                  controller.startTime.value?.format(context),
                              placeholder: 'Start',
                              onTap: () => controller.pickStartTime(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.gapMd),
                        Expanded(
                          child: Obx(
                            () => DateTimePickerField(
                              label: 'End Time',
                              icon: Icons.schedule_rounded,
                              displayValue:
                                  controller.endTime.value?.format(context),
                              placeholder: 'End',
                              onTap: () => controller.pickEndTime(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.gapLg),
                    Obx(
                      () => AppButton(
                        label: 'Schedule Sabha',
                        icon: Icons.add_rounded,
                        isLoading: controller.isSaving.value,
                        onPressed: () async {
                          final ok = await controller.submit();
                          if (ok) {
                            Get.snackbar(
                              'Scheduled',
                              'Sabha has been successfully scheduled.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: AppColors.headerBlue,
                              colorText: Colors.white,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppDimens.gapXl),

            // 2. Scheduled Sabhas List
            const SectionHeader(title: 'Scheduled Sabhas'),
            const SizedBox(height: AppDimens.gapSm),

            Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimens.gapXl),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (controller.sabhas.isEmpty) {
                return const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'No upcoming Sabhas',
                  message: 'Schedule a Sabha using the form above.',
                );
              }
              return Column(
                children: controller.sabhas.map((sabha) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppDimens.cardPadding),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.cancelledRed.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusMd),
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              color: AppColors.cancelledRed,
                              size: 22,
                            ),
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
                                        sabha.description,
                                        style: AppTextStyles.subtitle,
                                      ),
                                    ),
                                    if (sabha.current)
                                      const StatusBadge(
                                        label: 'Active',
                                        color: AppColors.successGreen,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppDimens.gapXs),
                                Text(
                                  '${DateFormatting.dateOnly(sabha.date)} • ${DateFormatting.time(sabha.startTime)} – ${DateFormatting.time(sabha.endTime)}',
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.cancelledRed,
                              size: 20,
                            ),
                            tooltip: 'Delete Sabha',
                            onPressed: () => _confirmDelete(context, sabha.id),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            }),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }

  void _confirmDelete(BuildContext context, String id) {
    Get.defaultDialog(
      title: 'Delete Sabha',
      titleStyle: AppTextStyles.title,
      middleText: 'Are you sure you want to remove this scheduled Sabha?',
      middleTextStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
      radius: AppDimens.radiusXl,
      textConfirm: 'Delete',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      cancelTextColor: AppColors.textSecondary,
      buttonColor: AppColors.cancelledRed,
      onConfirm: () {
        Get.back();
        controller.deleteSabha(id);
      },
    );
  }
}
