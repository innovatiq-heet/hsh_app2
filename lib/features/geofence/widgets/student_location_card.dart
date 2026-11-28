import 'package:flutter/material.dart';
import '../../../core/models/geofence/student_location.dart';
import '../../../core/utils/date_formatting.dart';
import '../controllers/student_locations_controller.dart';
import '../utils/location_accuracy.dart';

/// Modern student location card matching the Phonebook card design, used by
/// [StudentLocationsListBody].
class StudentLocationCard extends StatelessWidget {
  final StudentLocation student;
  final StudentLocationsController controller;

  const StudentLocationCard({
    super.key,
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

          // Action buttons: Campus Map, Google Maps & Call Student
          Row(
            children: [
              if (loc != null) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      controller.selectStudent(student);
                      controller.isMapView.value = true;
                    },
                    icon: const Icon(Icons.radar_rounded, size: 16),
                    label: const Text(
                      'Campus Map',
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
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  onPressed: () => controller.openInMaps(student),
                  icon: const Icon(Icons.map_rounded, size: 18),
                  tooltip: 'Open in Google Maps',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE0F2FE),
                    foregroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
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

    final accuracyPct = LocationAccuracy.percentage(loc.accuracyMeters);
    final (accuracyColor, accuracyBg, accuracyBorder) = LocationAccuracy.palette(loc.accuracyMeters);

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
          // Top Row: Student Accuracy Percentage + Distance in meters
          Row(
            children: [
              // Accuracy Percentage Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                decoration: BoxDecoration(
                  color: accuracyBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accuracyBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gps_fixed_rounded,
                      size: 13,
                      color: accuracyColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$accuracyPct% Accuracy',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accuracyColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Distance in meters badge
              if (loc.distanceMeters != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: student.status == LocationStatus.outside
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: student.status == LocationStatus.outside
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF86EFAC),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.near_me_rounded,
                        size: 13,
                        color: student.status == LocationStatus.outside
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _distance(loc.distanceMeters!),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: student.status == LocationStatus.outside
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (student.status == LocationStatus.inside) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: Color(0xFF16A34A),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '0 m (Inside)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.8, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Metadata Row: Updated time and Precision
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
                  '±${loc.accuracyMeters.round()} m precision',
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

  static String _distance(double m) => '${m.round()} m away';
}
