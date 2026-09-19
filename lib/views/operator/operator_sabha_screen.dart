import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_strings.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/date_time_picker_field.dart';
import 'operator_sabha_controller.dart';

class OperatorSabhaScreen extends GetView<OperatorSabhaController> {
  const OperatorSabhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Sabha')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: controller.titleController,
                label: 'Title',
                validator: Validators.required,
              ),
              const SizedBox(height: AppDimens.gapMd),
              Obx(
                () => DateTimePickerField(
                  label: 'Date',
                  icon: Icons.schedule,
                  displayValue: controller.date.value == null
                      ? null
                      : '${controller.date.value!.day}/${controller.date.value!.month}/${controller.date.value!.year}',
                  placeholder: 'Select date',
                  onTap: () => controller.pickDate(context),
                ),
              ),
              const SizedBox(height: AppDimens.gapMd),
              Obx(
                () => DateTimePickerField(
                  label: 'Start Time',
                  icon: Icons.schedule,
                  displayValue: controller.startTime.value?.format(context),
                  placeholder: 'Select time',
                  onTap: () => controller.pickStartTime(context),
                ),
              ),
              const SizedBox(height: AppDimens.gapMd),
              Obx(
                () => DateTimePickerField(
                  label: 'End Time',
                  icon: Icons.schedule,
                  displayValue: controller.endTime.value?.format(context),
                  placeholder: 'Select time',
                  onTap: () => controller.pickEndTime(context),
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
                      Get.snackbar('Scheduled', 'Sabha has been scheduled.');
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
