import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_text_styles.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_text_field.dart';
import 'edit_profile_controller.dart';

class EditProfileScreen extends GetView<EditProfileController> {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              color: AppColors.mainBackground,
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  Expanded(
                    child: Text(
                      'Aadhar, email, room, status and a few other fields can only be changed by hostel staff.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),
            Text('Identity', style: AppTextStyles.subtitle),
            const SizedBox(height: AppDimens.gapSm),
            AppTextField(
              controller: controller.firstNameController,
              label: 'First Name',
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.middleNameController,
              label: 'Middle Name',
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.lastNameController,
              label: 'Last Name',
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.phoneController,
              label: 'Phone',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.whatsappController,
              label: 'WhatsApp Number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.bloodGroupController,
              label: 'Blood Group',
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.vehicleNumberController,
              label: 'Vehicle Number',
              prefixIcon: Icons.two_wheeler_outlined,
            ),
            const SizedBox(height: AppDimens.gapXl),
            Text('Address', style: AppTextStyles.subtitle),
            const SizedBox(height: AppDimens.gapSm),
            AppTextField(
              controller: controller.addressController,
              label: 'Address',
              maxLines: 3,
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.pinCodeController,
              label: 'Pin Code',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppDimens.gapXl),
            Text('Family', style: AppTextStyles.subtitle),
            const SizedBox(height: AppDimens.gapSm),
            AppTextField(
              controller: controller.fatherNameController,
              label: "Father's First Name",
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.fatherPhoneController,
              label: "Father's Phone",
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.fatherProfessionController,
              label: "Father's Profession",
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.motherNameController,
              label: "Mother's First Name",
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppTextField(
              controller: controller.motherPhoneController,
              label: "Mother's Phone",
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppDimens.gapXl),
            Text('Lifestyle', style: AppTextStyles.subtitle),
            Obx(
              () => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Plays Cricket'),
                value: controller.playsCricket.value,
                onChanged: (v) => controller.playsCricket.value = v ?? false,
              ),
            ),
            Obx(
              () => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Plays Badminton'),
                value: controller.playsBadminton.value,
                onChanged: (v) => controller.playsBadminton.value = v ?? false,
              ),
            ),
            Obx(
              () => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Goes to Gym'),
                value: controller.goesToGym.value,
                onChanged: (v) => controller.goesToGym.value = v ?? false,
              ),
            ),
            const SizedBox(height: AppDimens.gapXl),
            Obx(
              () => AppButton(
                label: AppStrings.save,
                isLoading: controller.isSaving.value,
                onPressed: controller.save,
              ),
            ),
            const SizedBox(height: AppDimens.gapXl),
          ],
        ),
      ),
    );
  }
}
