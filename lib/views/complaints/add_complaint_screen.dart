import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/validators.dart';
import '../shared/utils/complaint_category_style.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import 'add_complaint_controller.dart';

class AddComplaintScreen extends GetView<AddComplaintController> {
  const AddComplaintScreen({super.key});

  static const Map<String, List<String>> _quickTitles = {
    'Electrical': [
      'Fan not working',
      'Light not working',
      'Switchboard loose',
      'Socket damaged',
    ],
    'Plumbing': [
      'Tap leaking',
      'Flush not working',
      'Drainage blocked',
      'Geyser not heating',
    ],
    'Furniture': [
      'Study chair broken',
      'Wardrobe door stuck',
      'Bed frame loose',
      'Table drawer broken',
    ],
    'Housekeeping': [
      'Room cleaning needed',
      'Washroom cleaning',
      'Dustbin replacement',
    ],
    'Internet/Wifi': [
      'No internet connection',
      'Very slow Wifi speed',
      'Cannot connect to router',
    ],
    'Other': [
      'Door lock jammed',
      'Window glass damaged',
      'Pest control needed',
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Header
            GradientHeader(
              overline: 'Help Desk',
              title: 'New Complaint',
              subtitle: 'Report a room issue to the maintenance team',
              leading: Material(
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
              ),
              child: const HeaderPill(
                icon: Icons.timer_outlined,
                label: 'Standard resolution: 24 - 48 business hours',
              ),
            ),

            // Form Body
            Padding(
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
                    // Section 1: Category Selection
                    const SectionHeader(title: 'Select category'),
                    _CategoryGrid(controller: controller),

                    const SizedBox(height: AppDimens.gapXl),

                    // Section 2: Issue Details
                    const SectionHeader(title: 'Issue details'),
                    _IssueDetailsCard(
                      controller: controller,
                      quickTitles: _quickTitles,
                    ),

                    const SizedBox(height: AppDimens.gapXl),

                    // Section 3: Photos / Attachments
                    const SectionHeader(title: 'Attach photos (Optional)'),
                    _PhotosCard(controller: controller),

                    const SizedBox(height: AppDimens.gapXl),

                    // Section 4: Notice & Guidance
                    _NoticeCard(),

                    const SizedBox(height: AppDimens.gapXxl),

                    // Submit Button
                    Obx(
                      () => AppButton(
                        label: 'Submit Complaint',
                        icon: Icons.send_rounded,
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
          ],
        ),
      ),
    );
  }
}

/// Visual grid of categories featuring category-specific icons and colors.
class _CategoryGrid extends StatelessWidget {
  final AddComplaintController controller;

  const _CategoryGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final categories = controller.categories;
      final selected = controller.selectedCategory.value;

      if (categories.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimens.gapLg),
            child: CircularProgressIndicator(),
          ),
        );
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppDimens.gapSm,
          crossAxisSpacing: AppDimens.gapSm,
          childAspectRatio: 1.35,
        ),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selected == category;
          final style = ComplaintCategoryStyle.of(category);

          return Material(
            color: isSelected
                ? style.color.withValues(alpha: 0.12)
                : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm + 2),
              side: BorderSide(
                color: isSelected ? style.color : AppColors.border,
                width: isSelected ? 1.6 : 1.0,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm + 2),
              onTap: () => controller.selectedCategory.value = category,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? style.color
                            : style.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        style.icon,
                        size: 17,
                        color: isSelected ? Colors.white : style.color,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

/// Card containing title, description, and dynamic quick-suggestion chips.
class _IssueDetailsCard extends StatelessWidget {
  final AddComplaintController controller;
  final Map<String, List<String>> quickTitles;

  const _IssueDetailsCard({
    required this.controller,
    required this.quickTitles,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic suggestions based on selected category
          Obx(() {
            final category = controller.selectedCategory.value ?? '';
            final suggestions = quickTitles[category] ?? [];

            if (suggestions.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Common $category issues:',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.gapSm),
                Wrap(
                  spacing: AppDimens.gapSm,
                  runSpacing: AppDimens.gapSm,
                  children: suggestions.map((title) {
                    return Material(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusPill,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusPill,
                        ),
                        onTap: () => controller.setQuickTitle(title),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Text(
                            title,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppDimens.gapMd),
                  child: Divider(height: 1),
                ),
              ],
            );
          }),

          // Title field
          Text('Title', style: AppTextStyles.label),
          const SizedBox(height: AppDimens.gapXs),
          TextFormField(
            controller: controller.titleController,
            validator: Validators.required,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Washroom tap is leaking continuously',
              hintStyle: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.title_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.gapMd,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                borderSide: const BorderSide(
                  color: AppColors.primaryLight,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimens.gapMd),

          // Description field
          Text('Description', style: AppTextStyles.label),
          const SizedBox(height: AppDimens.gapXs),
          TextFormField(
            controller: controller.descriptionController,
            maxLines: 4,
            validator: Validators.required,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText:
                  'Provide details such as exact room location, when the issue started, and any urgency...',
              hintStyle: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textMuted,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 52),
                child: Icon(
                  Icons.notes_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
              filled: true,
              fillColor: AppColors.surfaceMuted,
              contentPadding: const EdgeInsets.all(AppDimens.gapMd),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                borderSide: const BorderSide(
                  color: AppColors.primaryLight,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Attach photos card with gallery/camera picker and rounded image preview tiles.
class _PhotosCard extends StatelessWidget {
  final AddComplaintController controller;

  const _PhotosCard({required this.controller});

  void _showImageSourceSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(AppDimens.gapLg),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusXl),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Photo',
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.gapMd),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('Take photo with camera'),
                onTap: () {
                  Get.back();
                  controller.pickImageFromSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Get.back();
                  controller.pickImageFromSource(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visual evidence helps technicians bring the right tools and spare parts.',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.gapMd),
          Obx(() {
            final images = controller.images;
            return Wrap(
              spacing: AppDimens.gapMd,
              runSpacing: AppDimens.gapMd,
              children: [
                for (int i = 0; i < images.length; i++)
                  _ImageThumbnail(
                    file: images[i],
                    onRemove: () => controller.removeImage(i),
                  ),
                if (images.length < 4)
                  _AddPhotoButton(onTap: () => _showImageSourceSheet(context)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _ImageThumbnail({
    required this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Image.file(
            file,
            width: 86,
            height: 86,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.cancelledRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: AppColors.border,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_a_photo_outlined,
              size: 24,
              color: AppColors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              'Add photo',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guidance card regarding technician visits and hostel rules.
class _NoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.gapMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimens.gapSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Technician visit guidelines',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Technicians visit rooms on working days between 10:00 AM - 5:00 PM. Please ensure the affected area is accessible.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
