import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/utils/complaint_category_style.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/add_complaint_controller.dart';

class AddComplaintScreen extends GetView<AddComplaintController> {
  const AddComplaintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverGradientHeader(
            overline: 'Help Desk',
            title: 'New Complaint',
            subtitle: 'Report a room issue to the maintenance team',
            expandedHeight: 220.0,
            leading: HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Get.back(),
            ),
            child: Obx(
              () => HeaderPill(
                icon: Icons.meeting_room_outlined,
                label: controller.hasRoom
                    ? 'Room ${controller.room.value}'
                    : 'Standard resolution: 24 - 48 business hours',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapXl,
                AppDimens.screenPadding,
                40,
              ),
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const SkeletonList(count: 4, padding: EdgeInsets.zero);
                }
                if (controller.loadError.value.isNotEmpty) {
                  return EmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load the form',
                    message: controller.loadError.value,
                    actionLabel: 'Retry',
                    onAction: controller.load,
                  );
                }
                if (!controller.hasRoom) {
                  return const EmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'No room assigned',
                    message:
                        'Only students with an assigned room can submit complaints.',
                  );
                }
                return const _ComplaintForm();
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintForm extends GetView<AddComplaintController> {
  const _ComplaintForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Select category'),
        const _CategoryGrid(),
        const SizedBox(height: AppDimens.gapXl),
        const SectionHeader(title: 'What needs fixing?'),
        const _ItemPicker(),
        const SizedBox(height: AppDimens.gapXl),
        const SectionHeader(title: 'Details'),
        AppCard(
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The API only accepts the student's own room, so it is shown
              // but never editable.
              TextFormField(
                initialValue: controller.room.value,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Room',
                  prefixIcon: Icon(Icons.meeting_room_outlined, size: 20),
                  suffixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(height: AppDimens.gapMd),
              TextFormField(
                controller: controller.commentController,
                maxLines: 4,
                maxLength: AddComplaintController.maxCommentLength,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  hintText: 'e.g. AC not cooling since last night',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapXl),
        const SectionHeader(title: 'Attach a photo (optional)'),
        const _PhotoCard(),
        const SizedBox(height: AppDimens.gapXl),
        const _NoticeCard(),
        const SizedBox(height: AppDimens.gapXxl),
        Obx(
          () => AppButton(
            label: 'Submit Complaint',
            icon: Icons.send_rounded,
            isLoading: controller.isSaving.value,
            onPressed: controller.selectedItem.value == null
                ? null
                : () async {
                    final ok = await controller.submit();
                    // Not Get.back(): with the success snackbar open it
                    // would only close the snackbar.
                    if (ok && context.mounted) Navigator.of(context).pop(true);
                  },
          ),
        ),
      ],
    );
  }
}

/// Category tiles from `/complaint-categories`, with category icons/colors.
class _CategoryGrid extends GetView<AddComplaintController> {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final categories = controller.categories;
      final selectedId = controller.selectedCategory.value?.id;
      if (categories.isEmpty) {
        return const EmptyState(
          icon: Icons.category_outlined,
          title: 'No categories available',
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
          final isSelected = selectedId == category.id;
          final style = ComplaintCategoryStyle.of(category.name);

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
              onTap: () => controller.selectCategory(category),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                      category.name,
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

/// Items of the chosen category from `/complaint-items?categoryId=`.
class _ItemPicker extends GetView<AddComplaintController> {
  const _ItemPicker();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Obx(() {
        final category = controller.selectedCategory.value;
        if (category == null) {
          return _hint('Choose a category above to see its items.');
        }
        if (controller.isLoadingItems.value) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppDimens.gapMd),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (controller.itemsError.value.isNotEmpty) {
          return Row(
            children: [
              Expanded(child: _hint(controller.itemsError.value)),
              TextButton(
                onPressed: controller.loadItems,
                child: const Text('Retry'),
              ),
            ],
          );
        }
        if (controller.items.isEmpty) {
          return _hint('No items in ${category.name}.');
        }

        final style = ComplaintCategoryStyle.of(category.name);
        final selectedId = controller.selectedItem.value?.id;
        return Wrap(
          spacing: AppDimens.gapSm,
          runSpacing: AppDimens.gapSm,
          children: [
            for (final item in controller.items)
              ChoiceChip(
                label: Text(item.name),
                selected: selectedId == item.id,
                selectedColor: style.color,
                showCheckmark: false,
                labelStyle: AppTextStyles.label.copyWith(
                  color: selectedId == item.id
                      ? Colors.white
                      : AppColors.textPrimary,
                  fontWeight: selectedId == item.id
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                onSelected: (_) => controller.selectItem(item),
              ),
          ],
        );
      }),
    );
  }

  Widget _hint(String text) => Text(
        text,
        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
      );
}

/// One optional photo (JPEG/PNG/WebP, ≤ 5 MB) from the camera or gallery.
class _PhotoCard extends GetView<AddComplaintController> {
  const _PhotoCard();

  void _showImageSourceSheet() {
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
              _sourceTile(
                Icons.camera_alt_outlined,
                'Take photo with camera',
                ImageSource.camera,
              ),
              _sourceTile(
                Icons.photo_library_outlined,
                'Choose from gallery',
                ImageSource.gallery,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceTile(IconData icon, String title, ImageSource source) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      onTap: () {
        Get.back();
        controller.pickImage(source);
      },
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
            'A photo helps technicians bring the right tools. JPEG, PNG or WebP, up to 5 MB.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.gapMd),
          Obx(() {
            final image = controller.image.value;
            return image == null
                ? _AddPhotoButton(onTap: _showImageSourceSheet)
                : _ImageThumbnail(file: image, onRemove: controller.removeImage);
          }),
        ],
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _ImageThumbnail({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Image.file(file, width: 110, height: 110, fit: BoxFit.cover),
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
              child: const Icon(Icons.close, size: 14, color: Colors.white),
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
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: AppColors.border, width: 1.2),
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
  const _NoticeCard();

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
