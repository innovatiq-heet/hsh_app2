import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/geofence/student_location.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../controllers/student_locations_controller.dart';

/// Modern, executive view of every student's last reported phone location.
class StudentLocationsScreen extends GetView<StudentLocationsController> {
  const StudentLocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverGradientHeader(
              title: 'Student Locations',
              subtitle: 'Real-time phone GPS & campus geofence',
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: controller.load,
                  tooltip: 'Refresh locations',
                ),
              ],
            ),

            // Executive overview summary strip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Obx(_buildOverviewStats),
              ),
            ),

            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildSearchBar(),
              ),
            ),

            // Filter chips
            SliverToBoxAdapter(
              child: Obx(_buildFilterChips),
            ),

            // List of students
            Obx(() {
              if (controller.isLoading.value) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (controller.loadError.value.isNotEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Locations Unavailable',
                    message: controller.loadError.value,
                    actionLabel: 'Retry',
                    onAction: controller.load,
                  ),
                );
              }

              final items = controller.visible;
              if (items.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.location_searching_rounded,
                    title: 'No Students Found',
                    message: 'Try adjusting your search query or filter selection.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _StudentLocationCard(
                    student: items[i],
                    controller: controller,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Executive summary metrics cards (All, Outside, Inside, No Fix).
  Widget _buildOverviewStats() {
    final total = controller.students.length;
    final outsideCount = controller.countOf(LocationStatus.outside);
    final insideCount = controller.countOf(LocationStatus.inside);
    final noDataCount = controller.countOf(LocationStatus.noData);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total',
                count: total,
                icon: Icons.people_alt_rounded,
                accentColor: AppColors.primary,
                isSelected: controller.filter.value == null,
                onTap: () => controller.setFilter(null),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                title: 'Outside',
                count: outsideCount,
                icon: Icons.warning_amber_rounded,
                accentColor: const Color(0xFFEF4444),
                highlightAlert: outsideCount > 0,
                isSelected: controller.filter.value == LocationStatus.outside,
                onTap: () => controller.setFilter(LocationStatus.outside),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                title: 'Inside',
                count: insideCount,
                icon: Icons.check_circle_rounded,
                accentColor: const Color(0xFF10B981),
                isSelected: controller.filter.value == LocationStatus.inside,
                onTap: () => controller.setFilter(LocationStatus.inside),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                title: 'No Fix',
                count: noDataCount,
                icon: Icons.location_off_rounded,
                accentColor: const Color(0xFF94A3B8),
                isSelected: controller.filter.value == LocationStatus.noData,
                onTap: () => controller.setFilter(LocationStatus.noData),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Modern capsule search bar with clear button and live match counter.
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller.searchController,
        onChanged: (v) => controller.query.value = v,
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: 'Search by student name, room, ID or phone...',
          hintStyle: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          suffixIcon: Obx(() {
            final q = controller.query.value;
            if (q.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
              onPressed: () {
                controller.searchController.clear();
                controller.query.value = '';
              },
            );
          }),
        ),
      ),
    );
  }

  /// Modern filter chips.
  Widget _buildFilterChips() {
    final activeFilter = controller.filter.value;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _ModernFilterChip(
            label: 'All Students',
            count: controller.students.length,
            icon: Icons.grid_view_rounded,
            isSelected: activeFilter == null,
            color: AppColors.primary,
            onTap: () => controller.setFilter(null),
          ),
          const SizedBox(width: 8),
          _ModernFilterChip(
            label: 'Outside Campus',
            count: controller.countOf(LocationStatus.outside),
            icon: Icons.wrong_location_rounded,
            isSelected: activeFilter == LocationStatus.outside,
            color: const Color(0xFFEF4444),
            onTap: () => controller.setFilter(LocationStatus.outside),
          ),
          const SizedBox(width: 8),
          _ModernFilterChip(
            label: 'Inside Campus',
            count: controller.countOf(LocationStatus.inside),
            icon: Icons.where_to_vote_rounded,
            isSelected: activeFilter == LocationStatus.inside,
            color: const Color(0xFF10B981),
            onTap: () => controller.setFilter(LocationStatus.inside),
          ),
          const SizedBox(width: 8),
          _ModernFilterChip(
            label: 'No GPS Fix',
            count: controller.countOf(LocationStatus.noData),
            icon: Icons.location_off_rounded,
            isSelected: activeFilter == LocationStatus.noData,
            color: const Color(0xFF64748B),
            onTap: () => controller.setFilter(LocationStatus.noData),
          ),
        ],
      ),
    );
  }
}

/// Tappable metric overview card for fast warden inspection.
class _MetricCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final bool highlightAlert;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    this.highlightAlert = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (highlightAlert
                      ? const Color(0xFFFCA5A5)
                      : AppColors.border.withValues(alpha: 0.7)),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? accentColor : (highlightAlert ? const Color(0xFFEF4444) : accentColor),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: highlightAlert ? const Color(0xFFEF4444) : AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? accentColor : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive filter chip pill.
class _ModernFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ModernFilterChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color : AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern, sleek Student Location card.
class _StudentLocationCard extends StatelessWidget {
  final StudentLocation student;
  final StudentLocationsController controller;

  const _StudentLocationCard({
    required this.student,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final loc = student.location;
    final isOutside = student.status == LocationStatus.outside;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOutside
              ? const Color(0xFFFCA5A5)
              : AppColors.border.withValues(alpha: 0.8),
          width: isOutside ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isOutside
                ? const Color(0xFFEF4444).withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Room & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _buildTag(
                          icon: Icons.meeting_room_outlined,
                          text: 'Room ${student.room}',
                        ),
                        if (student.studentCode.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _buildTag(
                            icon: Icons.badge_outlined,
                            text: student.studentCode,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(),
            ],
          ),

          const SizedBox(height: 12),

          // Location details panel
          _buildLocationPanel(context, loc),

          const SizedBox(height: 12),

          // Action buttons: Open in Maps & Call Student
          Row(
            children: [
              if (loc != null) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => controller.openInMaps(student),
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: const Text(
                      'Open in Maps',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (student.phone.trim().isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.callStudent(student),
                    icon: const Icon(Icons.phone_rounded, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Call Student',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Modern squircle avatar with monogram and status indicator.
  Widget _buildAvatar() {
    final (bgGradient, textColor, dotColor) = switch (student.status) {
      LocationStatus.outside => (
        const LinearGradient(colors: [Color(0xFFFFE4E6), Color(0xFFFECDD3)]),
        const Color(0xFFBE123C),
        const Color(0xFFEF4444),
      ),
      LocationStatus.inside => (
        const LinearGradient(colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)]),
        const Color(0xFF15803D),
        const Color(0xFF10B981),
      ),
      LocationStatus.unknownArea => (
        const LinearGradient(colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)]),
        const Color(0xFF0369A1),
        const Color(0xFF0EA5E9),
      ),
      LocationStatus.noData => (
        const LinearGradient(colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)]),
        const Color(0xFF64748B),
        const Color(0xFF94A3B8),
      ),
    };

    final letter = student.name.trim().isNotEmpty
        ? student.name.trim()[0].toUpperCase()
        : 'S';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: bgGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  /// Small metadata tag for Room and Student ID.
  Widget _buildTag({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF64748B)),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  /// Refined status badge.
  Widget _buildStatusBadge() {
    final (label, textColor, bgColor, borderColor, icon) = switch (student.status) {
      LocationStatus.outside => (
        'Outside campus',
        const Color(0xFFDC2626),
        const Color(0xFFFEF2F2),
        const Color(0xFFFCA5A5),
        Icons.wrong_location_rounded,
      ),
      LocationStatus.inside => (
        'Inside campus',
        const Color(0xFF16A34A),
        const Color(0xFFF0FDF4),
        const Color(0xFF86EFAC),
        Icons.where_to_vote_rounded,
      ),
      LocationStatus.unknownArea => (
        'Location known',
        AppColors.primary,
        AppColors.primary.withValues(alpha: 0.1),
        AppColors.primary.withValues(alpha: 0.3),
        Icons.location_on_rounded,
      ),
      LocationStatus.noData => (
        'No GPS fix',
        const Color(0xFF64748B),
        const Color(0xFFF8FAFC),
        const Color(0xFFCBD5E1),
        Icons.location_off_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Modern location details panel replacing the raw grey box.
  Widget _buildLocationPanel(BuildContext context, LocationFix? loc) {
    if (loc == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: const [
            Icon(Icons.satellite_alt_outlined, size: 16, color: Color(0xFF94A3B8)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Phone hasn\'t reported GPS fix yet (offline or setup pending)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final coordsText = '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Coordinates + Copy button + Distance badge (if outside)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.near_me_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      coordsText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: coordsText));
                        AppSnackbar.info('Copied', 'Coordinates copied to clipboard');
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (student.status == LocationStatus.outside && loc.distanceMeters != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _distance(loc.distanceMeters!),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFBE123C),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 0.8, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),

          // Metadata Row: Updated time and Accuracy
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Updated ${DateFormatting.relativeTime(loc.fixTime)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569),
                ),
              ),
              if (loc.accuracyMeters > 0) ...[
                const SizedBox(width: 10),
                const Icon(Icons.my_location_rounded, size: 12, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  '±${loc.accuracyMeters.round()} m accuracy',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ],
          ),

          // Mocked / Fake GPS warning
          if (loc.mocked) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.gpp_bad_rounded, size: 14, color: Color(0xFFDC2626)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Fake GPS detected — location spoofing alert',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _distance(double m) =>
      m < 1000 ? '${m.round()}m away' : '${(m / 1000).toStringAsFixed(1)}km away';
}
