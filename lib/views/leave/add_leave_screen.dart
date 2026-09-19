import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_strings.dart';
import '../../utils/date_formatting.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/date_time_picker_field.dart';
import 'add_leave_controller.dart';

class AddLeaveScreen extends GetView<AddLeaveController> {
  const AddLeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply Leave')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(
                () => DateTimePickerField(
                  label: 'Start',
                  displayValue: controller.startTime.value == null
                      ? null
                      : DateFormatting.dateTime(
                          controller.startTime.value!.toUtc(),
                        ),
                  placeholder: 'Select date & time',
                  onTap: () => controller.pickStart(context),
                ),
              ),
              const SizedBox(height: AppDimens.gapMd),
              Obx(
                () => DateTimePickerField(
                  label: 'End',
                  displayValue: controller.endTime.value == null
                      ? null
                      : DateFormatting.dateTime(
                          controller.endTime.value!.toUtc(),
                        ),
                  placeholder: 'Select date & time',
                  onTap: () => controller.pickEnd(context),
                ),
              ),
              const SizedBox(height: AppDimens.gapMd),
              AppTextField(
                controller: controller.reasonController,
                label: 'Reason',
                maxLines: 4,
                validator: Validators.required,
              ),
              const SizedBox(height: AppDimens.gapXl),
              Obx(
                () => AppButton(
                  label: AppStrings.submit,
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
    );
  }
}
