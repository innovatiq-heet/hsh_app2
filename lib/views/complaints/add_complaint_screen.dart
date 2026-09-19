import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/validators.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/dropdown_field.dart';
import 'add_complaint_controller.dart';

class AddComplaintScreen extends GetView<AddComplaintController> {
  const AddComplaintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Complaint')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(
                () => DropdownField<String>(
                  label: 'Category',
                  value: controller.selectedCategory.value,
                  items: controller.categories,
                  itemLabel: (e) => e,
                  onChanged: (v) => controller.selectedCategory.value = v,
                ),
              ),
              const SizedBox(height: AppDimens.gapMd),
              AppTextField(
                controller: controller.titleController,
                label: 'Title',
                validator: Validators.required,
              ),
              const SizedBox(height: AppDimens.gapMd),
              AppTextField(
                controller: controller.descriptionController,
                label: 'Description',
                maxLines: 5,
                validator: Validators.required,
              ),
              const SizedBox(height: AppDimens.gapLg),
              Text('Photos', style: AppTextStyles.label),
              const SizedBox(height: AppDimens.gapSm),
              Obx(
                () => Wrap(
                  spacing: AppDimens.gapSm,
                  runSpacing: AppDimens.gapSm,
                  children: [
                    ...controller.images.asMap().entries.map(
                      (entry) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                            child: Image.file(
                              entry.value,
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: AppColors.cancelledRed,
                                size: 20,
                              ),
                              onPressed: () =>
                                  controller.removeImage(entry.key),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: controller.pickImage,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                        ),
                        child: const Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
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
