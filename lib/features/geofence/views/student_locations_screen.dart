import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/models/geofence/student_location.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../controllers/student_locations_controller.dart';

/// Modern, executive view of every student's last reported phone location,
/// styled with the signature deep navy header, sky-blue accents, and slate card styling
/// from the Phonebook screen.
class StudentLocationsScreen extends GetView<StudentLocationsController> {
  const StudentLocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          onRefresh: controller.load,
          color: const Color(0xFF0284C7),
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _StudentLocationsHeaderDelegate(
                  controller: controller,
                  topPadding: MediaQuery.of(context).padding.top,
                ),
              ),

              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _buildSearchBar(),
                ),
              ),

              // Filter chips
              SliverToBoxAdapter(
                child: Obx(_buildFilterChips),
              ),

              // Section header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Obx(() {
                        final filter = controller.filter.value;
                        final String sectionTitle;
                        switch (filter) {
                          case LocationStatus.outside:
                            sectionTitle = 'Outside Campus (${controller.countOf(LocationStatus.outside)})';
                            break;
                          case LocationStatus.inside:
                            sectionTitle = 'Inside Campus (${controller.countOf(LocationStatus.inside)})';
                            break;
                          case LocationStatus.noData:
                            sectionTitle = 'No GPS Fix (${controller.countOf(LocationStatus.noData)})';
                            break;
                          default:
                            sectionTitle = 'All Students (${controller.students.length})';
                        }

                        return Text(
                          sectionTitle,
                          style: const TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // List of students
              Obx(() {
                if (controller.isLoading.value) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0284C7),
                      ),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final card = _StudentLocationCard(
                        student: items[i],
                        controller: controller,
                      );
                      if (i < 8) {
                        return StaggeredSlideFade(
                          index: i,
                          duration: const Duration(milliseconds: 280),
                          slideOffset: 12.0,
                          child: card,
                        );
                      }
                      return card;
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Modern capsule search bar matching the Phonebook screen search input.
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller.searchController,
        onChanged: (v) => controller.query.value = v,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          hintText: 'Search by student name, room, ID or phone...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF0284C7),
            size: 22,
          ),
          suffixIcon: Obx(() {
            final q = controller.query.value;
            if (q.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
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

  /// Horizontal modern filter chip pills matching the Phonebook chips.
  Widget _buildFilterChips() {
    final activeFilter = controller.filter.value;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          _ModernFilterChip(
            label: 'All Students',
            count: controller.students.length,
            icon: Icons.grid_view_rounded,
            isSelected: activeFilter == null,
            color: const Color(0xFF0284C7),
            onTap: () => controller.setFilter(null),
          ),
          const SizedBox(width: 8),
          _ModernFilterChip(
            label: 'Outside Campus',
            count: controller.countOf(LocationStatus.outside),
            icon: Icons.wrong_location_rounded,
            isSelected: activeFilter == LocationStatus.outside,
            color: const Color(0xFFDC2626),
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

/// Collapsible shrinking deep navy header with luminous arcs, matching Phonebook header.
class _StudentLocationsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final StudentLocationsController controller;
  final double topPadding;

  _StudentLocationsHeaderDelegate({
    required this.controller,
    required this.topPadding,
  });

  @override
  double get minExtent => topPadding + 62.0;

  @override
  double get maxExtent => topPadding + 230.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius = Radius.circular(
      (34.0 * (1.0 - progress)).clamp(0.0, 34.0),
    );

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
                  color: const Color(0xFF03192E).withValues(alpha: 0.22 * progress),
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
            // Luminous ambient orbs & arcs
            CustomPaint(painter: _HeaderOrbPainter()),

            // Top pinned navigation bar (Back button, Collapsed title, Refresh button)
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
                            width: 1,
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

                  // Collapsed title that fades in on shrink
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: const Text(
                        'Student Locations',
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

                  // Refresh button with loading spinner
                  Obx(() {
                    final isLoading = controller.isLoading.value;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isLoading ? null : controller.load,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Expanded content (Amber dash, Overline, Large Title, Subtitle, Metric cards)
            if (expandedOpacity > 0.02)
              Positioned(
                top: topPadding + 54,
                left: 20,
                right: 20,
                bottom: 12,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: Transform.translate(
                    offset: Offset(0, -progress * 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
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
                        Text(
                          'CAMPUS GEOFENCE & GPS TRACKING',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Student Locations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Real-time phone GPS & campus geofence',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Frosted summary metric cards
                        Obx(_buildOverviewStats),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Executive summary metrics cards inside the hero navy gradient header.
  Widget _buildOverviewStats() {
    final total = controller.students.length;
    final outsideCount = controller.countOf(LocationStatus.outside);
    final insideCount = controller.countOf(LocationStatus.inside);
    final noDataCount = controller.countOf(LocationStatus.noData);

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Total',
            count: total,
            icon: Icons.people_alt_rounded,
            accentColor: const Color(0xFF38BDF8),
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
            accentColor: const Color(0xFFFF8A8A),
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
            accentColor: const Color(0xFF86EFAC),
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
            accentColor: const Color(0xFFCBD5E1),
            isSelected: controller.filter.value == LocationStatus.noData,
            onTap: () => controller.setFilter(LocationStatus.noData),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _StudentLocationsHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.controller != controller;
  }
}

/// Custom painter for luminous concentric arcs and ambient light orbs in the header background.
class _HeaderOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top-right luminous ambient glow
    final glowPaintRight = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.16),
          const Color(0xFF0284C7).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.90, size.height * 0.15),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.90, size.height * 0.15),
      size.width * 0.55,
      glowPaintRight,
    );

    // Bottom-left subtle ambient glow
    final glowPaintLeft = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0284C7).withValues(alpha: 0.12),
          const Color(0xFF032B4F).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.10, size.height * 0.85),
          radius: size.width * 0.45,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.85),
      size.width * 0.45,
      glowPaintLeft,
    );

    // Elegant concentric arcs with smooth stroke
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.065)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.08),
      size.width * 0.38,
      strokePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.08),
      size.width * 0.62,
      strokePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.08),
      size.width * 0.86,
      strokePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.92),
      size.width * 0.46,
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Frosted metric card embedded inside the hero navy gradient header.
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
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.28)
                : (highlightAlert
                    ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.14)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : (highlightAlert
                      ? const Color(0xFFFCA5A5)
                      : Colors.white.withValues(alpha: 0.22)),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: highlightAlert
                    ? const Color(0xFFFF8A8A)
                    : (isSelected ? Colors.white : accentColor),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive filter chip pill matching PhonebookScreen chips.
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
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
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
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
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
                    fontSize: 11,
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

/// Modern student location card matching the Phonebook card design.
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOutside
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFE2E8F0),
          width: isOutside ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isOutside
                ? const Color(0xFFEF4444).withValues(alpha: 0.05)
                : const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildTag(
                          icon: Icons.meeting_room_rounded,
                          text: 'Room ${student.room}',
                        ),
                        if (student.studentCode.isNotEmpty)
                          _buildTag(
                            icon: Icons.badge_rounded,
                            text: student.studentCode,
                          ),
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
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (student.phone.trim().isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.callStudent(student),
                    icon: const Icon(
                      Icons.phone_rounded,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                    label: const Text(
                      'Call Student',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFE0F2FE).withValues(alpha: 0.4),
                      side: const BorderSide(
                        color: Color(0xFFBAE6FD),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  /// Modern squircle avatar with status indicator dot.
  Widget _buildAvatar() {
    final (bg, textColor, borderColor, dotColor) = switch (student.status) {
      LocationStatus.outside => (
        const Color(0xFFFEF2F2),
        const Color(0xFFDC2626),
        const Color(0xFFFCA5A5),
        const Color(0xFFDC2626),
      ),
      LocationStatus.inside => (
        const Color(0xFFF0FDF4),
        const Color(0xFF16A34A),
        const Color(0xFF86EFAC),
        const Color(0xFF16A34A),
      ),
      LocationStatus.unknownArea => (
        const Color(0xFFE0F2FE),
        const Color(0xFF0284C7),
        const Color(0xFFBAE6FD),
        const Color(0xFF0284C7),
      ),
      LocationStatus.noData => (
        const Color(0xFFF1F5F9),
        const Color(0xFF64748B),
        const Color(0xFFCBD5E1),
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
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 19,
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

  /// Small metadata tag for Room and Student ID matching Phonebook tags.
  Widget _buildTag({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
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
        const Color(0xFF0284C7),
        const Color(0xFFE0F2FE),
        const Color(0xFFBAE6FD),
        Icons.location_on_rounded,
      ),
      LocationStatus.noData => (
        'No GPS fix',
        const Color(0xFF64748B),
        const Color(0xFFF8FAFC),
        const Color(0xFFE2E8F0),
        Icons.location_off_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  /// Modern location details panel with clean slate styling.
  Widget _buildLocationPanel(BuildContext context, LocationFix? loc) {
    if (loc == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.satellite_alt_outlined, size: 16, color: Color(0xFF94A3B8)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Phone hasn\'t reported GPS fix yet (offline or setup pending)',
                style: TextStyle(
                  fontSize: 12,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Coordinates + Copy button + Distance badge (if outside)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.near_me_rounded,
                  size: 14,
                  color: Color(0xFF0284C7),
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
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: coordsText));
                        AppSnackbar.info('Copied', 'Coordinates copied to clipboard');
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (student.status == LocationStatus.outside && loc.distanceMeters != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    _distance(loc.distanceMeters!),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.8, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Metadata Row: Updated time and Accuracy
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 5),
              Text(
                'Updated ${DateFormatting.relativeTime(loc.fixTime)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569),
                ),
              ),
              if (loc.accuracyMeters > 0) ...[
                const SizedBox(width: 12),
                const Icon(Icons.my_location_rounded, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(
                  '±${loc.accuracyMeters.round()} m accuracy',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ],
          ),

          // Mocked / Fake GPS warning
          if (loc.mocked) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gpp_bad_rounded, size: 15, color: Color(0xFFDC2626)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Fake GPS detected — location spoofing alert',
                      style: TextStyle(
                        fontSize: 11.5,
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
