import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/geofence/student_location.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/status_badge.dart';
import '../controllers/student_locations_controller.dart';

/// Every student with the location their phone last reported.
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
              subtitle: 'Last location reported by each student\'s phone',
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: controller.load,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: AppTextField(
                  controller: controller.searchController,
                  label: 'Search students',
                  hint: 'Name, room, ID or phone',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (v) => controller.query.value = v,
                ),
              ),
            ),
            SliverToBoxAdapter(child: Obx(_buildFilters)),
            Obx(() {
              if (controller.isLoading.value) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (controller.loadError.value.isNotEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Locations unavailable',
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
                    title: 'No students found',
                    message: 'Try a different search or filter.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _StudentLocationCard(student: items[i], controller: controller),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    Widget chip(String label, LocationStatus? status, int count) {
      final selected = controller.filter.value == status;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text('$label ($count)'),
          selected: selected,
          onSelected: (_) => controller.setFilter(status),
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          chip('All', null, controller.students.length),
          chip('Outside', LocationStatus.outside, controller.countOf(LocationStatus.outside)),
          chip('Inside', LocationStatus.inside, controller.countOf(LocationStatus.inside)),
          chip('No location', LocationStatus.noData, controller.countOf(LocationStatus.noData)),
        ],
      ),
    );
  }
}

class _StudentLocationCard extends StatelessWidget {
  final StudentLocation student;
  final StudentLocationsController controller;

  const _StudentLocationCard({required this.student, required this.controller});

  @override
  Widget build(BuildContext context) {
    final loc = student.location;
    final (label, color, icon) = switch (student.status) {
      LocationStatus.outside => ('Outside campus', AppColors.cancelledRed, Icons.wrong_location_rounded),
      LocationStatus.inside => ('Inside campus', const Color(0xFF16A34A), Icons.where_to_vote_rounded),
      LocationStatus.unknownArea => ('Location known', AppColors.primary, Icons.location_on_rounded),
      LocationStatus.noData => ('No location yet', Colors.grey, Icons.location_off_rounded),
    };

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(
                  student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      'Room ${student.room}${student.studentCode.isNotEmpty ? ' • ${student.studentCode}' : ''}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: label, color: color, icon: icon),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: loc == null
                ? const Text(
                    'The phone hasn\'t reported a location yet (location off or app not set up).',
                    style: TextStyle(fontSize: 11),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          'Updated ${DateFormatting.relativeTime(loc.fixTime)}',
                          if (loc.accuracyMeters > 0) '±${loc.accuracyMeters.round()} m',
                          if (student.status == LocationStatus.outside && loc.distanceMeters != null)
                            _distance(loc.distanceMeters!),
                        ].join(' • '),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                      if (loc.mocked) ...[
                        const SizedBox(height: 4),
                        const Text(
                          '⚠ Fake GPS app detected — this location may not be real',
                          style: TextStyle(fontSize: 11, color: AppColors.cancelledRed, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (loc != null)
                ElevatedButton.icon(
                  onPressed: () => controller.openInMaps(student),
                  icon: const Icon(Icons.map_rounded, size: 14),
                  label: const Text('Open in Maps', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              if (student.phone.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => controller.callStudent(student),
                  icon: const Icon(Icons.phone_rounded, size: 14, color: AppColors.primary),
                  label: const Text('Call Student', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _distance(double m) =>
      m < 1000 ? '${m.round()} m from campus' : '${(m / 1000).toStringAsFixed(1)} km from campus';
}
