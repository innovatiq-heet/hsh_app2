import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_dimens.dart';
import '../../shared/utils/complaint_category_style.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/add_complaint_controller.dart';

class AddComplaintScreen extends GetView<AddComplaintController> {
  const AddComplaintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      body: CustomScrollView(
        slivers: [
          Obx(
            () => SliverPersistentHeader(
              pinned: true,
              delegate: PhonebookHeaderDelegate(
                overline: 'Help Desk',
                title: 'New Complaint',
                subtitle: 'Report a room issue to the maintenance team',
                topPadding: topPadding,
                onLeadingTap: () => Get.back(),
                pills: PhonebookHeaderPill(
                  icon: Icons.meeting_room_outlined,
                  label: controller.hasRoom
                      ? 'Room ${controller.room.value}'
                      : 'Standard resolution: 24 - 48 hrs',
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
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
        const PhonebookSectionHeader(title: 'Select category'),
        const _CategoryGrid(),
        const SizedBox(height: 20),
        const PhonebookSectionHeader(title: 'What needs fixing?'),
        const _ItemPicker(),
        const SizedBox(height: 20),
        const PhonebookSectionHeader(title: 'Details'),
        PhonebookCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The API only accepts the student's own room, so it is shown
              // but never editable.
              TextFormField(
                initialValue: controller.room.value,
                enabled: false,
                style: const TextStyle(
                  color: PhonebookTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'Room',
                  filled: true,
                  fillColor: PhonebookTheme.bg,
                  prefixIcon: const Icon(
                    Icons.meeting_room_outlined,
                    size: 20,
                    color: PhonebookTheme.blue,
                  ),
                  suffixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: PhonebookTheme.muted,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PhonebookTheme.border),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PhonebookTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.commentController,
                maxLines: 4,
                maxLength: AddComplaintController.maxCommentLength,
                style: const TextStyle(
                  color: PhonebookTheme.ink,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  labelText: 'Comment (optional)',
                  hintText: 'e.g. AC not cooling since last night',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: PhonebookTheme.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PhonebookTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PhonebookTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: PhonebookTheme.blue,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const PhonebookSectionHeader(title: 'Attach a photo (optional)'),
        const _PhotoCard(),
        const SizedBox(height: 20),
        const _NoticeCard(),
        const SizedBox(height: 24),
        Obx(() {
          final enabled =
              controller.selectedItem.value != null && !controller.isSaving.value;
          return SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: enabled
                  ? () async {
                      final ok = await controller.submit();
                      // Not Get.back(): with the success snackbar open it
                      // would only close the snackbar.
                      if (ok && context.mounted) Navigator.of(context).pop(true);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: PhonebookTheme.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: PhonebookTheme.border,
                disabledForegroundColor: PhonebookTheme.muted,
                elevation: enabled ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: controller.isSaving.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 19),
              label: Text(
                controller.isSaving.value ? 'Submitting...' : 'Submit Complaint',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }),
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
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.28,
        ),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedId == category.id;
          final style = ComplaintCategoryStyle.of(category.name);

          return Material(
            color: isSelected
                ? style.color.withValues(alpha: 0.1)
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isSelected ? style.color : PhonebookTheme.border,
                width: isSelected ? 1.6 : 1.0,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => controller.selectCategory(category),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? style.color
                            : style.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        style.icon,
                        size: 18,
                        color: isSelected ? Colors.white : style.color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? PhonebookTheme.ink
                            : PhonebookTheme.slate,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 11.5,
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
    return PhonebookCard(
      padding: const EdgeInsets.all(16),
      child: Obx(() {
        final category = controller.selectedCategory.value;
        if (category == null) {
          return _hint('Choose a category above to see its items.');
        }
        if (controller.isLoadingItems.value) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppDimens.gapMd),
              child: CircularProgressIndicator(color: PhonebookTheme.blue),
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
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in controller.items)
              ChoiceChip(
                label: Text(item.name),
                selected: selectedId == item.id,
                selectedColor: style.color,
                backgroundColor: PhonebookTheme.bg,
                side: BorderSide(
                  color: selectedId == item.id
                      ? style.color
                      : PhonebookTheme.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: selectedId == item.id
                      ? Colors.white
                      : PhonebookTheme.ink,
                  fontSize: 13,
                  fontWeight: selectedId == item.id
                      ? FontWeight.w700
                      : FontWeight.w600,
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
        style: const TextStyle(
          color: PhonebookTheme.muted,
          fontSize: 13.5,
        ),
      );
}

/// One optional photo (JPEG/PNG/WebP, ≤ 5 MB) from the camera or gallery.
class _PhotoCard extends GetView<AddComplaintController> {
  const _PhotoCard();

  void _showImageSourceSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: PhonebookTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Add Photo',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: PhonebookTheme.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
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
        padding: const EdgeInsets.all(9),
        decoration: const BoxDecoration(
          color: PhonebookTheme.blueSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: PhonebookTheme.blue, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: PhonebookTheme.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        Get.back();
        controller.pickImage(source);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PhonebookCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A photo helps technicians bring the right tools. JPEG, PNG or WebP, up to 5 MB.',
            style: TextStyle(
              color: PhonebookTheme.muted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
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
          borderRadius: BorderRadius.circular(14),
          child: Image.file(file, width: 110, height: 110, fit: BoxFit.cover),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: PhonebookTheme.red,
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: PhonebookTheme.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PhonebookTheme.border, width: 1.2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 24,
              color: PhonebookTheme.blue,
            ),
            SizedBox(height: 6),
            Text(
              'Add photo',
              style: TextStyle(
                color: PhonebookTheme.slate,
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PhonebookTheme.blueSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: PhonebookTheme.blue,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Technician visit guidelines',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: PhonebookTheme.ink,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Technicians visit rooms on working days between 10:00 AM - 5:00 PM. Please ensure the affected area is accessible.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: PhonebookTheme.slate,
                    height: 1.4,
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
