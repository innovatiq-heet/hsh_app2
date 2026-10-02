import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/status_badge.dart';
import '../controllers/phonebook_controller.dart';
import '../models/phonebook_models.dart';

class PhonebookScreen extends GetView<PhonebookController> {
  const PhonebookScreen({super.key});

  Color _groupColor(String? group) {
    switch (group?.toLowerCase().trim()) {
      case 'param':
        return AppColors.primary;
      case 'pavitra':
        return AppColors.secondary;
      case 'pulkit':
        return AppColors.warningOrange;
      case 'paramanand':
        return AppColors.successGreen;
      default:
        return AppColors.primaryLight;
    }
  }

  void _showStudentContactDetails(BuildContext context, PhonebookStudent student) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          _groupColor(student.groupName).withValues(alpha: 0.15),
                      child: Text(
                        student.name.isNotEmpty
                            ? student.name[0].toUpperCase()
                            : 'S',
                        style: TextStyle(
                          color: _groupColor(student.groupName),
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: AppTextStyles.title.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (student.groupName != null)
                                StatusBadge(
                                  label: student.groupName!,
                                  color: _groupColor(student.groupName),
                                ),
                              if (student.room != null && student.room!.isNotEmpty)
                                StatusBadge(
                                  label: 'Room ${student.room}',
                                  color: AppColors.textSecondary,
                                ),
                              if (student.enrollmentNumber.isNotEmpty)
                                StatusBadge(
                                  label: 'ID: ${student.enrollmentNumber}',
                                  color: AppColors.primaryLight,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),
                Text(
                  'PHONE CONTACTS',
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                if (student.phones.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No phone numbers registered for this student.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                else
                  ...student.phones.map((p) {
                    final isWhatsApp =
                        p.label.toLowerCase().contains('whatsapp');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isWhatsApp
                                ? Icons.chat_bubble_outline_rounded
                                : Icons.phone_rounded,
                            size: 20,
                            color: isWhatsApp
                                ? AppColors.successGreen
                                : (p.isPrimary
                                    ? AppColors.primary
                                    : AppColors.secondary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.phone,
                                  style: AppTextStyles.bodyMd.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.label,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            tooltip: 'Copy Number',
                            onPressed: () => controller.copyToClipboard(
                              p.phone,
                              p.label,
                            ),
                          ),
                          if (isWhatsApp)
                            IconButton(
                              icon: const Icon(
                                Icons.chat_rounded,
                                color: AppColors.successGreen,
                              ),
                              tooltip: 'Open WhatsApp',
                              onPressed: () {
                                Navigator.pop(ctx);
                                controller.openWhatsApp(p.phone);
                              },
                            )
                          else ...[
                            IconButton(
                              icon: const Icon(
                                Icons.chat_outlined,
                                size: 18,
                                color: AppColors.successGreen,
                              ),
                              tooltip: 'WhatsApp',
                              onPressed: () {
                                Navigator.pop(ctx);
                                controller.openWhatsApp(p.phone);
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.call_rounded,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Call Phone',
                              onPressed: () {
                                Navigator.pop(ctx);
                                controller.makeCall(p.phone);
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                if (student.email != null && student.email!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'EMAIL ADDRESS',
                    style: AppTextStyles.overline.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 20,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            student.email!,
                            style: AppTextStyles.bodyMd,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => controller.copyToClipboard(
                            student.email!,
                            'Email',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Get.toNamed(
                        Routes.studentScreenTime,
                        arguments: {
                          'studentId': student.studentId,
                          'aadhar': student.studentId.replaceFirst('HSH-', ''),
                          'name': student.name,
                          'room': student.room ?? '',
                        },
                      );
                    },
                    icon: const Icon(Icons.phone_android_rounded, size: 18),
                    label: const Text('View Individual Screen Time'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: CustomScrollView(
        slivers: [
          // Header
          Obx(() {
            final count = controller.totalCachedCount.value;
            final syncDate = controller.lastSync.value;

            return SliverGradientHeader(
              overline: 'ADMIN CONSOLE',
              title: 'Student Phonebook',
              subtitle: 'Campus directory & parent caller database',
              expandedHeight: 250.0,
              leading: Navigator.canPop(context)
                  ? HeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Get.back(),
                    )
                  : null,
              actions: [
                Obx(
                  () => HeaderIconButton(
                    icon: controller.isSyncing.value
                        ? Icons.sync_rounded
                        : Icons.cloud_sync_outlined,
                    tooltip: 'Sync Directory',
                    onPressed: controller.isSyncing.value
                        ? () {}
                        : () => controller.syncNow(),
                  ),
                ),
              ],
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    HeaderPill(
                      icon: Icons.contacts_rounded,
                      label: '$count Students Cached',
                    ),
                    const SizedBox(width: AppDimens.gapSm),
                    HeaderPill(
                      icon: Icons.update_rounded,
                      label: syncDate != null
                          ? 'Synced ${dateFormat.format(syncDate)}'
                          : 'Not synced yet',
                    ),
                  ],
                ),
              ),
            );
          }),

          // Search and Filters Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapMd,
                AppDimens.screenPadding,
                AppDimens.gapSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Box
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: controller.searchController,
                      onChanged: controller.onSearchChanged,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name, room, ID, or phone...',
                        hintStyle: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                        ),
                        suffixIcon: Obx(() {
                          if (controller.searchText.value.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: controller.clearSearch,
                          );
                        }),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapSm),

                  // Group Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Obx(() {
                      return Row(
                        children: PhonebookController.hshGroups.map((g) {
                          final isSelected =
                              controller.selectedGroup.value == g;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(g),
                              selected: isSelected,
                              onSelected: (_) => controller.selectGroup(g),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surface,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                              checkmarkColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusPill,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          // Students List
          Obx(() {
            if (controller.isLoading.value) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final list = controller.students;
            if (list.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'No student contacts found',
                  message: controller.searchText.value.isNotEmpty ||
                          controller.selectedGroup.value != 'All'
                      ? 'Try clearing filters or search query.'
                      : 'Tap Sync to download contacts from the live campus directory.',
                  actionLabel: 'Sync Now',
                  onAction: () => controller.syncNow(),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapXs,
                AppDimens.screenPadding,
                80,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final student = list[index];
                    return _StudentPhonebookCard(
                      student: student,
                      onTap: () =>
                          _showStudentContactDetails(context, student),
                      onCall: (phone) => controller.makeCall(phone),
                      onWhatsApp: (phone) => controller.openWhatsApp(phone),
                    );
                  },
                  childCount: list.length,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StudentPhonebookCard extends StatelessWidget {
  final PhonebookStudent student;
  final VoidCallback onTap;
  final ValueChanged<String> onCall;
  final ValueChanged<String> onWhatsApp;

  const _StudentPhonebookCard({
    required this.student,
    required this.onTap,
    required this.onCall,
    required this.onWhatsApp,
  });

  Color _groupColor(String? group) {
    switch (group?.toLowerCase().trim()) {
      case 'param':
        return AppColors.primary;
      case 'pavitra':
        return AppColors.secondary;
      case 'pulkit':
        return AppColors.warningOrange;
      case 'paramanand':
        return AppColors.successGreen;
      default:
        return AppColors.primaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = student.primaryPhone;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    _groupColor(student.groupName).withValues(alpha: 0.14),
                child: Text(
                  student.name.isNotEmpty
                      ? student.name[0].toUpperCase()
                      : 'S',
                  style: TextStyle(
                    color: _groupColor(student.groupName),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (student.room != null && student.room!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              'Room ${student.room}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (student.enrollmentNumber.isNotEmpty)
                          Text(
                            '#${student.enrollmentNumber}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (student.groupName != null)
                StatusBadge(
                  label: student.groupName!,
                  color: _groupColor(student.groupName),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Primary phone quick action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.phone_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    primary,
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (student.phones.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '+${student.phones.length - 1} more',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (primary != 'No Phone') ...[
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.successGreen.withValues(alpha: 0.12),
                        foregroundColor: AppColors.successGreen,
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      tooltip: 'WhatsApp',
                      onPressed: () => onWhatsApp(primary),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      tooltip: 'Call Phone',
                      onPressed: () => onCall(primary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}
