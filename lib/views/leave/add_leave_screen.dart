import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import 'add_leave_controller.dart';

class AddLeaveScreen extends GetView<AddLeaveController> {
  const AddLeaveScreen({super.key});

  static const List<String> _quickReasons = [
    'Going Home',
    'Family Function',
    'Medical Checkup',
    'Personal Work',
    'College Event',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverGradientHeader(
            overline: 'Hostel Outing',
            title: 'Apply Leave',
            subtitle: 'Submit an outing request for warden approval',
            expandedHeight: 220.0,
            leading: HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Get.back(),
            ),
            child: const HeaderPill(
              icon: Icons.shield_outlined,
              label: 'Warden approval required prior to departure',
            ),
          ),

          // Form Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapXl,
                AppDimens.screenPadding,
                40,
              ),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Schedule
                    const SectionHeader(title: 'Outing schedule'),
                    _ScheduleCard(controller: controller),

                    const SizedBox(height: AppDimens.gapXl),

                    // Section 2: Reason
                    const SectionHeader(title: 'Reason for leave'),
                    AppCard(
                      padding: const EdgeInsets.all(AppDimens.cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: controller.reasonController,
                            maxLines: 4,
                            validator: Validators.required,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Describe the purpose of your leave (e.g. Attending cousin\'s wedding in Ahmedabad)...',
                              hintStyle: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.textMuted,
                              ),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(bottom: 50),
                                child: Icon(
                                  Icons.edit_note_rounded,
                                  size: 22,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceMuted,
                              contentPadding: const EdgeInsets.all(
                                AppDimens.gapMd,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusMd,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusMd,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.primaryLight,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapMd),
                          Text(
                            'Quick suggestions',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapSm),
                          Wrap(
                            spacing: AppDimens.gapSm,
                            runSpacing: AppDimens.gapSm,
                            children: _quickReasons.map((reason) {
                              return Material(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusPill,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusPill,
                                  ),
                                  onTap: () => controller.setQuickReason(reason),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.add,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          reason,
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDimens.gapXl),

                    // Section 3: Important Guidelines
                    _GuidelinesCard(),

                    const SizedBox(height: AppDimens.gapXxl),

                    // Submit Action
                    Obx(
                      () => AppButton(
                        label: 'Submit Leave Request',
                        icon: Icons.check_circle_outline_rounded,
                        isLoading: controller.isSaving.value,
                        onPressed: () async {
                          final ok = await controller.submit();
                          if (ok) Get.back();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Combined card with Start & End date pickers and live duration banner.
class _ScheduleCard extends StatelessWidget {
  final AddLeaveController controller;

  const _ScheduleCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        children: [
          // Departure picker
          Obx(
            () => _DateTimePickerRow(
              icon: Icons.flight_takeoff_rounded,
              iconColor: AppColors.primary,
              label: 'DEPARTURE',
              placeholder: 'Select departure date & time',
              value: controller.startTime.value == null
                  ? null
                  : DateFormatting.dateTime(
                      controller.startTime.value!.toUtc(),
                    ),
              onTap: () => controller.pickStart(context),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.gapMd),
            child: Divider(height: 1),
          ),

          // Return picker
          Obx(
            () => _DateTimePickerRow(
              icon: Icons.flight_land_rounded,
              iconColor: AppColors.secondary,
              label: 'RETURN',
              placeholder: 'Select return date & time',
              value: controller.endTime.value == null
                  ? null
                  : DateFormatting.dateTime(
                      controller.endTime.value!.toUtc(),
                    ),
              onTap: () => controller.pickEnd(context),
            ),
          ),

          // Live Duration Preview / Validation status
          Obx(() {
            final start = controller.startTime.value;
            final end = controller.endTime.value;

            if (start == null || end == null) {
              return const SizedBox.shrink();
            }

            final isInvalid = end.isBefore(start);
            final durationText = controller.durationText;

            return Padding(
              padding: const EdgeInsets.only(top: AppDimens.gapMd),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.gapMd,
                  vertical: AppDimens.gapSm + 2,
                ),
                decoration: BoxDecoration(
                  color: isInvalid
                      ? AppColors.cancelledRed.withValues(alpha: 0.10)
                      : AppColors.successGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(
                    color: isInvalid
                        ? AppColors.cancelledRed.withValues(alpha: 0.3)
                        : AppColors.successGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isInvalid
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: isInvalid
                          ? AppColors.cancelledRed
                          : AppColors.successGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isInvalid
                            ? 'Return time must be after departure time'
                            : 'Estimated outing duration: $durationText',
                        style: AppTextStyles.caption.copyWith(
                          color: isInvalid
                              ? AppColors.cancelledRed
                              : AppColors.successGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DateTimePickerRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  const _DateTimePickerRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value?.isNotEmpty == true;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value! : placeholder,
                  style: hasValue
                      ? AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )
                      : AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textMuted,
                        ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

/// Information card outlining hostel outing policies.
class _GuidelinesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.gapMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Important reminders',
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          _bulletPoint('Submit requests in advance to avoid last-minute delays.'),
          const SizedBox(height: 4),
          _bulletPoint('Check the status badge in Leave history for warden response.'),
          const SizedBox(height: 4),
          _bulletPoint('Remember to sign the security register upon exit & entry.'),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
