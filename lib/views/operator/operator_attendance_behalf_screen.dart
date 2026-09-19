import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_strings.dart';
import '../../utils/date_formatting.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/date_time_picker_field.dart';
import '../shared/widgets/dropdown_field.dart';
import 'operator_attendance_behalf_controller.dart';

/// For manual corrections — e.g. a student who couldn't scan/mark
/// themselves (spec §5.16).
class OperatorAttendanceBehalfScreen
    extends GetView<OperatorAttendanceBehalfController> {
  const OperatorAttendanceBehalfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance on Behalf')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: controller.aadharController,
                label: 'Student Aadhar',
                prefixIcon: Icons.badge_outlined,
                validator: Validators.required,
              ),
              const SizedBox(height: AppDimens.gapMd),
              Obx(
                () => DropdownField<AttendanceType>(
                  label: 'Attendance Type',
                  value: controller.selectedType.value,
                  items: AttendanceType.values,
                  itemLabel: (e) => e.label,
                  onChanged: (v) =>
                      controller.selectedType.value = v ?? AttendanceType.aarti,
                ),
              ),
              const SizedBox(height: AppDimens.gapMd),
              Obx(
                () => DateTimePickerField(
                  label: 'Date',
                  displayValue: controller.date.value == null
                      ? null
                      : DateFormatting.dateOnly(controller.date.value!.toUtc()),
                  onTap: () => controller.pickDate(context),
                ),
              ),
              const SizedBox(height: AppDimens.gapXl),
              Obx(
                () => AppButton(
                  label: AppStrings.submit,
                  isLoading: controller.isSaving.value,
                  onPressed: () async {
                    final ok = await controller.submit();
                    if (ok) {
                      Get.snackbar(
                        'Saved',
                        'Attendance logged for the student.',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
