import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../../../core/models/geofence/student_location.dart';
import '../../phonebook/widgets/alpha_scroll_rail.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../controllers/student_locations_controller.dart';
import 'location_filter_chip.dart';
import 'student_location_card.dart';
import 'student_locations_header.dart';

/// List-mode body of [StudentLocationsScreen]: the collapsible header,
/// search bar, filter chips, section title and the student card list, plus
/// the alpha scroll rail overlay.
class StudentLocationsListBody extends StatelessWidget {
  final StudentLocationsController controller;

  const StudentLocationsListBody({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: controller.load,
          color: const Color(0xFF0284C7),
          backgroundColor: Colors.white,
          child: CustomScrollView(
            controller: controller.scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: StudentLocationsHeader(
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
                      Expanded(
                        child: Obx(() {
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
                      ),
                      Obx(() => InkWell(
                        onTap: controller.toggleSortByName,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: controller.sortByName.value ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: controller.sortByName.value ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sort_by_alpha_rounded,
                                size: 16,
                                color: controller.sortByName.value ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                controller.sortByName.value ? 'A-Z' : 'Status',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: controller.sortByName.value ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
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
                  sliver: SuperSliverList(
                    listController: controller.listController,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final card = StudentLocationCard(
                          student: items[index],
                          controller: controller,
                        );
                        final child = Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: card,
                        );
                        if (index < 8) {
                          return StaggeredSlideFade(
                            index: index,
                            duration: const Duration(milliseconds: 280),
                            slideOffset: 12.0,
                            child: child,
                          );
                        }
                        return child;
                      },
                      childCount: items.length,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (!controller.isMapView.value &&
            controller.query.value.isEmpty &&
            controller.railEntries.length > 1)
          Positioned(
            right: 4,
            top: MediaQuery.of(context).padding.top + 68.0,
            bottom: MediaQuery.of(context).padding.bottom + 80.0,
            child: Align(
              alignment: Alignment.centerRight,
              child: AlphaScrollRail(
                entries: controller.railEntries,
                onSelected: controller.scrollToRailEntry,
              ),
            ),
          ),
      ],
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
          LocationFilterChip(
            label: 'All Students',
            count: controller.students.length,
            icon: Icons.grid_view_rounded,
            isSelected: activeFilter == null,
            color: const Color(0xFF0284C7),
            onTap: () => controller.setFilter(null),
          ),
          const SizedBox(width: 8),
          LocationFilterChip(
            label: 'Outside Campus',
            count: controller.countOf(LocationStatus.outside),
            icon: Icons.wrong_location_rounded,
            isSelected: activeFilter == LocationStatus.outside,
            color: const Color(0xFFDC2626),
            onTap: () => controller.setFilter(LocationStatus.outside),
          ),
          const SizedBox(width: 8),
          LocationFilterChip(
            label: 'Inside Campus',
            count: controller.countOf(LocationStatus.inside),
            icon: Icons.where_to_vote_rounded,
            isSelected: activeFilter == LocationStatus.inside,
            color: const Color(0xFF10B981),
            onTap: () => controller.setFilter(LocationStatus.inside),
          ),
          const SizedBox(width: 8),
          LocationFilterChip(
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
