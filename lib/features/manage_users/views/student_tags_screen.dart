import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../../../core/utils/app_snackbar.dart';
import '../controllers/student_tags_controller.dart';
import 'assign_tag_screen.dart';

/// Admin → Student Tags: the roles and labels that can be put on students
/// (system tags are automatic; custom ones like Karyakarta are made here).
class StudentTagsScreen extends GetView<StudentTagsController> {
  const StudentTagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Obx(
        () => Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: AsyncStateView(
            isLoading: controller.isLoading.value,
            hasError: controller.hasError.value,
            errorMessage: controller.errorMessage.value,
            onRetry: controller.load,
            loadingWidget: _StudentTagsShimmer(topPadding: topPadding),
            builder: (context) => Obx(() {
              final tags = controller.tags;
              final custom = tags.where((t) => !t.isSystem).length;
              return AppRefreshIndicator(
                onRefresh: () => controller.load(showLoading: false),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StudentTagsHeaderDelegate(
                        topPadding: topPadding,
                        tagCount: tags.length,
                        customCount: custom,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.gapXl,
                        AppDimens.screenPadding,
                        100,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(title: 'Student tags & roles'),
                            Container(
                              margin: const EdgeInsets.only(bottom: AppDimens.gapMd),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFC7D2FE)),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF4F46E5)),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'System tags (Regular, Late, Irregular, iPhone) are calculated automatically by attendance & device rules. Custom tags (e.g. Karyakarta, Wing Leader) can be assigned to students in their profile or directory.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF3730A3),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (tags.isNotEmpty) ...[
                              _TagSearchField(controller: controller),
                              const SizedBox(height: AppDimens.gapMd),
                            ],
                            if (tags.isNotEmpty && controller.visibleTags.isEmpty)
                              AppCard(
                                child: EmptyState(
                                  icon: Icons.search_off_rounded,
                                  title: 'No matching tags',
                                  message: 'No tag matches "${controller.query.value.trim()}".',
                                  actionLabel: 'Clear search',
                                  actionIcon: Icons.close_rounded,
                                  onAction: controller.clearSearch,
                                ),
                              )
                            else if (tags.isEmpty)
                              AppCard(
                                child: EmptyState(
                                  icon: Icons.label_off_outlined,
                                  title: 'No tags available',
                                  message: 'Tap "+ Add tag" to create custom student tags and roles.',
                                  actionLabel: 'Add tag',
                                  actionIcon: Icons.add_rounded,
                                  onAction: () => _showCreateTagDialog(context, controller),
                                ),
                              )
                            else
                              for (final (i, tag) in controller.visibleTags.indexed)
                                StaggeredSlideFade(
                                  index: i,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                                    child: _StudentTagCard(tag: tag),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          floatingActionButton: controller.isLoading.value || controller.hasError.value
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'add_tag_fab',
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  onPressed: () => _showCreateTagDialog(context, controller),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Add tag',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Search box for the tag list (name or description).
class _TagSearchField extends StatelessWidget {
  final StudentTagsController controller;

  const _TagSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasText = controller.query.value.isNotEmpty;
      return TextField(
        controller: controller.searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search tags by name or description',
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 21),
          suffixIcon: hasText
              ? IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: controller.clearSearch,
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
          ),
        ),
      );
    });
  }
}

/// Collapsible deep-navy header matching the Screen Time / Geofence /
/// Complaints Desk screens.
class _StudentTagsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final int tagCount;
  final int customCount;

  const _StudentTagsHeaderDelegate({
    required this.topPadding,
    required this.tagCount,
    required this.customCount,
  });

  @override
  double get minExtent => topPadding + 62.0;

  @override
  double get maxExtent => topPadding + 185.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius =
        Radius.circular((34.0 * (1.0 - progress)).clamp(0.0, 34.0));

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF03192E),
            Color(0xFF032B4F),
            Color(0xFF025A8D),
            Color(0xFF0369A1),
          ],
          stops: [0.0, 0.38, 0.75, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        boxShadow: progress > 0.25
            ? [
                BoxShadow(
                  color: const Color(0xFF03192E)
                      .withValues(alpha: 0.22 * progress),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Decorative ambient orbs
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Top pinned nav bar
            Positioned(
              top: topPadding + 6,
              left: 16,
              right: 16,
              height: 46,
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Get.back(),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: const Text(
                        'Student Tags',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Expanded content
            if (expandedOpacity > 0.05)
              Positioned(
                top: topPadding + 54,
                left: 20,
                right: 20,
                bottom: 12,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: ClipRect(
                  child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  reverse: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAAB78),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Color(0xB8FFFFFF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Student Tags',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Roles and labels you can put on students',
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _headerPill(
                            icon: Icons.label_rounded,
                            iconColor: const Color(0xFFA78BFA),
                            label: '$tagCount tags',
                          ),
                          const SizedBox(width: 8),
                          _headerPill(
                            icon: Icons.edit_note_rounded,
                            iconColor: const Color(0xFF38BDF8),
                            label: '$customCount custom',
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _headerPill({
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StudentTagsHeaderDelegate oldDelegate) => true;
}

class _StudentTagsShimmer extends StatelessWidget {
  final double topPadding;
  const _StudentTagsShimmer({required this.topPadding});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: topPadding + 185,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF03192E),
                    Color(0xFF032B4F),
                    Color(0xFF025A8D),
                    Color(0xFF0369A1),
                  ],
                  stops: [0.0, 0.38, 0.75, 1.0],
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(34)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SkeletonLoader(
                        height: 10,
                        width: 60,
                        borderRadius: BorderRadius.circular(4),
                        baseColor: Colors.white.withValues(alpha: 0.14),
                        highlightColor: Colors.white.withValues(alpha: 0.28),
                      ),
                      const SizedBox(height: 8),
                      SkeletonLoader(
                        height: 28,
                        width: 180,
                        borderRadius: BorderRadius.circular(6),
                        baseColor: Colors.white.withValues(alpha: 0.18),
                        highlightColor: Colors.white.withValues(alpha: 0.32),
                      ),
                      const SizedBox(height: 8),
                      SkeletonLoader(
                        height: 14,
                        width: 260,
                        borderRadius: BorderRadius.circular(4),
                        baseColor: Colors.white.withValues(alpha: 0.10),
                        highlightColor: Colors.white.withValues(alpha: 0.22),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (int i = 0; i < 2; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            SkeletonLoader(
                              height: 28,
                              width: 80,
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusPill),
                              baseColor: Colors.white.withValues(alpha: 0.14),
                              highlightColor:
                                  Colors.white.withValues(alpha: 0.28),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.gapXl,
              AppDimens.screenPadding,
              100,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SkeletonLoader(
                    height: 16,
                    width: 100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  for (int i = 0; i < 4; i++)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppDimens.gapMd),
                      child: AppCard(
                        child: Row(
                          children: [
                            SkeletonLoader(
                              height: 48,
                              width: 48,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            const SizedBox(width: AppDimens.gapMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonLoader(
                                    height: 16,
                                    width: 140,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  const SizedBox(height: 6),
                                  SkeletonLoader(
                                    height: 12,
                                    width: 100,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  const SizedBox(height: 8),
                                  SkeletonLoader(
                                    height: 22,
                                    width: 80,
                                    borderRadius: BorderRadius.circular(
                                        AppDimens.radiusPill),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppDimens.gapMd),
                            SkeletonLoader(
                              height: 32,
                              width: 50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
  }
}

class _StudentTagCard extends StatelessWidget {
  final StudentTag tag;

  const _StudentTagCard({required this.tag});

  StudentTagsController get controller => Get.find<StudentTagsController>();

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete tag?'),
        content: Text(
          'Tag "${tag.name}" will be permanently removed and unassigned from all students.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteTag(tag);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AssignTagScreen(
            tag: tag,
            onAssigned: tag.isSystem ? null : () => controller.load(showLoading: false),
          ),
        ),
      ),
      child: Row(
        children: [
          // Tag color badge circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tag.backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: tag.borderColor,
                width: 1.5,
              ),
            ),
            child: Icon(
              tag.isSystem ? Icons.lock_outline_rounded : Icons.label_rounded,
              size: 20,
              color: tag.displayColor,
            ),
          ),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tag.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (tag.isSystem)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Text(
                          'SYSTEM',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                if (tag.description != null && tag.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tag.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: tag.displayColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${tag.studentCount} ${tag.studentCount == 1 ? 'student' : 'students'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tag.displayColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!tag.isSystem)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 20),
              tooltip: 'Edit / Rename tag',
              onPressed: () => _showEditTagDialog(context, controller, tag),
            ),
          if (!tag.isSystem)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 20),
              tooltip: 'Assign to student',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AssignTagScreen(
                    tag: tag,
                    onAssigned: () => controller.load(showLoading: false),
                  ),
                ),
              ),
            ),
          if (!tag.isSystem)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed, size: 20),
              tooltip: 'Delete tag',
              onPressed: () => _confirmDelete(context),
            )
          else
            const Padding(
              padding: EdgeInsets.only(left: 8, right: 4),
              child: Tooltip(
                message: 'View students (system tags cannot be edited)',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 17, color: Color(0xFF94A3B8)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _showCreateTagDialog(BuildContext context, StudentTagsController controller) {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String selectedHex = '#6366f1';

  const colorOptions = [
    '#6366f1', // Indigo
    '#0284c7', // Sky Blue
    '#059669', // Emerald
    '#d97706', // Amber
    '#dc2626', // Red
    '#9333ea', // Purple
    '#ec4899', // Pink
    '#0d9488', // Teal
  ];

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create New Tag', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tag Name (e.g. Karyakarta, Wing Leader)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Enter tag name',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Description (Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    hintText: 'Brief description of this role',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tag Color',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: colorOptions.map((hex) {
                    final c = StudentTag.parseHexColor(hex);
                    final isSel = selectedHex == hex;
                    return GestureDetector(
                      onTap: () => setDlgState(() => selectedHex = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSel
                              ? Border.all(color: Colors.black87, width: 2.5)
                              : Border.all(color: Colors.transparent, width: 2),
                        ),
                        child: isSel
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  return;
                }
                final ok = await controller.createTag(
                  name: name,
                  color: selectedHex,
                  description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                );
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create Tag', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    ),
  );
}

void _showEditTagDialog(BuildContext context, StudentTagsController controller, StudentTag tag) {
  final nameCtrl = TextEditingController(text: tag.name);
  final descCtrl = TextEditingController(text: tag.description ?? '');
  String selectedHex = tag.colorHex.isNotEmpty ? tag.colorHex : '#6366f1';
  bool isSaving = false;

  const colorOptions = [
    '#6366f1', // Indigo
    '#0284c7', // Sky Blue
    '#059669', // Emerald
    '#d97706', // Amber
    '#dc2626', // Red
    '#9333ea', // Purple
    '#ec4899', // Pink
    '#0d9488', // Teal
  ];

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) {
        final currentColor = StudentTag.parseHexColor(selectedHex);
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: currentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit_rounded, size: 16, color: currentColor),
              ),
              const SizedBox(width: 10),
              const Text('Edit Tag', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tag Name',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Enter tag name',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description (Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add an optional note about this tag',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tag Color',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: colorOptions.map((hex) {
                    final c = StudentTag.parseHexColor(hex);
                    final isSel = selectedHex.toLowerCase() == hex.toLowerCase();
                    return GestureDetector(
                      onTap: () => setDlgState(() => selectedHex = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSel
                              ? Border.all(color: Colors.black87, width: 2.5)
                              : Border.all(color: Colors.transparent, width: 2),
                        ),
                        child: isSel
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        AppSnackbar.warning('Validation', 'Tag name is required.');
                        return;
                      }
                      setDlgState(() => isSaving = true);
                      final ok = await controller.updateTag(
                        id: tag.id,
                        name: name,
                        color: selectedHex,
                        description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                      );
                      if (ok && ctx.mounted) {
                        Navigator.pop(ctx);
                      } else if (ctx.mounted) {
                        setDlgState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    ),
  );
}
