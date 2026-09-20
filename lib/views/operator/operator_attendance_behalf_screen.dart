import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../../utils/validators.dart';
import '../attendance/attendance_event_style.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/date_time_picker_field.dart';
import '../shared/widgets/dropdown_field.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import 'operator_attendance_behalf_controller.dart';

/// For manual corrections — e.g. a student who couldn't scan/mark
/// themselves (spec §5.16).
class OperatorAttendanceBehalfScreen
    extends GetView<OperatorAttendanceBehalfController> {
  const OperatorAttendanceBehalfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GradientHeader(
              overline: 'Staff Operations',
              title: 'Manual Attendance',
              subtitle: 'Record attendance on behalf of students',
              leading: Navigator.canPop(context)
                  ? Material(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => Get.back(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    )
                  : null,
              actions: [
                HeaderIconButton(
                  icon: Icons.history_rounded,
                  tooltip: 'Attendance History',
                  onPressed: () => Get.toNamed(Routes.attendanceHistory),
                ),
              ],
              child: const HeaderPill(
                icon: Icons.edit_calendar_outlined,
                label: 'Warden override & manual entry',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapXl,
                AppDimens.screenPadding,
                AppDimens.gapXxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(title: 'Student & session details'),
                  AppCard(
                    padding: const EdgeInsets.all(AppDimens.cardPadding),
                    child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Manual Attendance Entry', style: AppTextStyles.title),
                const SizedBox(height: AppDimens.gapXs),
                Text(
                  'Record attendance for a student who could not scan the QR code.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimens.gapLg),
                AppTextField(
                  controller: controller.idOrAadharController,
                  label: 'Student ID or Aadhar',
                  prefixIcon: Icons.badge_outlined,
                  validator: Validators.required,
                ),
                const SizedBox(height: AppDimens.gapMd),
                Obx(
                  () => DropdownField<AttendanceType>(
                    label: 'Attendance Type',
                    value: controller.selectedType.value,
                    items: AttendanceType.values,
                    itemLabel: (e) =>
                        '${AttendanceEventStyle.of(e).emoji} ${e.label}',
                    onChanged: (v) =>
                        controller.selectedType.value = v ?? AttendanceType.aarti,
                  ),
                ),
                const SizedBox(height: AppDimens.gapMd),
                Obx(
                  () => DateTimePickerField(
                    label: 'Date',
                    icon: Icons.calendar_today_rounded,
                    displayValue: controller.date.value == null
                        ? null
                        : DateFormatting.dateOnly(controller.date.value!.toUtc()),
                    placeholder: 'Select date',
                    onTap: () => controller.pickDate(context),
                  ),
                ),
                const SizedBox(height: AppDimens.gapXl),
                Obx(
                  () => AppButton(
                    label: AppStrings.submit,
                    icon: Icons.check_circle_outline_rounded,
                    isLoading: controller.isSaving.value,
                    onPressed: () async {
                      final ok = await controller.submit();
                      if (ok) {
                        Get.snackbar(
                          'Attendance Logged',
                          'Attendance recorded successfully for student.',
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
      ],
    ),
  ),
],
),
),
);
}
}
