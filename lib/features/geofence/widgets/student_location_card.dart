import 'package:flutter/material.dart';
import '../../../core/models/geofence/student_location.dart';
import '../../../core/utils/date_formatting.dart';
import '../controllers/student_locations_controller.dart';
import '../utils/location_accuracy.dart';
import '../views/student_location_detail_screen.dart';

/// Compact, scannable card showing a student's curfew status, GPS telemetry,
/// and quick call action in [StudentLocationsListBody].
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
    final statusPalette = _statusPalette(student.status);

    final metaParts = <String>[
      if (student.room.trim().isNotEmpty) 'Room ${student.room.trim()}',
      if (student.studentCode.trim().isNotEmpty) student.studentCode.trim(),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOutside ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: isOutside ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isOutside
                ? const Color(0xFFEF4444).withValues(alpha: 0.06)
                : const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => StudentLocationDetailScreen(
                student: student,
                controller: controller,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusPalette.text,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.only(left: 15),
                        child: Text(
                          metaParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(palette: statusPalette),
              if (student.phone.trim().isNotEmpty) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Call ${student.name}',
                  child: Material(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => controller.callStudent(student),
                      borderRadius: BorderRadius.circular(10),
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          Icons.phone_rounded,
                          size: 17,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          _buildTelemetryRow(loc),
          if (loc != null && loc.mocked) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gpp_bad_rounded, size: 14, color: Color(0xFFDC2626)),
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
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryRow(LocationFix? loc) {
    if (loc == null) {
      return const Row(
        children: [
          Icon(Icons.satellite_alt_outlined, size: 14, color: Color(0xFF94A3B8)),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'No GPS fix reported yet',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      );
    }

    final accuracyPct = LocationAccuracy.percentage(loc.accuracyMeters);
    final (accColor, accBg, accBorder) = LocationAccuracy.palette(loc.accuracyMeters);
    final isOutside = student.status == LocationStatus.outside;

    final String? distanceText = loc.distanceMeters != null
        ? '${loc.distanceMeters!.round()} m away'
        : (student.status == LocationStatus.inside ? 'On campus' : null);

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (distanceText != null)
                _MetricChip(
                  icon: isOutside ? Icons.near_me_rounded : Icons.check_circle_rounded,
                  label: distanceText,
                  color: isOutside ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  background: isOutside ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  border: isOutside ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                ),
              _MetricChip(
                icon: Icons.gps_fixed_rounded,
                label: loc.accuracyMeters > 0
                    ? '$accuracyPct% · ±${loc.accuracyMeters.round()}m'
                    : '$accuracyPct% accuracy',
                color: accColor,
                background: accBg,
                border: accBorder,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 12.5, color: Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(
              DateFormatting.relativeTime(loc.fixTime),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static _StatusStyle _statusPalette(LocationStatus status) => switch (status) {
        LocationStatus.outside => const _StatusStyle(
            label: 'Outside',
            text: Color(0xFFDC2626),
            background: Color(0xFFFEF2F2),
            border: Color(0xFFFCA5A5),
            icon: Icons.wrong_location_rounded,
          ),
        LocationStatus.inside => const _StatusStyle(
            label: 'Inside',
            text: Color(0xFF16A34A),
            background: Color(0xFFF0FDF4),
            border: Color(0xFF86EFAC),
            icon: Icons.where_to_vote_rounded,
          ),
        LocationStatus.unknownArea => const _StatusStyle(
            label: 'Located',
            text: Color(0xFF0284C7),
            background: Color(0xFFE0F2FE),
            border: Color(0xFFBAE6FD),
            icon: Icons.location_on_rounded,
          ),
        LocationStatus.noData => const _StatusStyle(
            label: 'No GPS',
            text: Color(0xFF64748B),
            background: Color(0xFFF8FAFC),
            border: Color(0xFFE2E8F0),
            icon: Icons.location_off_rounded,
          ),
      };
}

class _StatusStyle {
  final String label;
  final Color text;
  final Color background;
  final Color border;
  final IconData icon;

  const _StatusStyle({
    required this.label,
    required this.text,
    required this.background,
    required this.border,
    required this.icon,
  });
}

class _StatusPill extends StatelessWidget {
  final _StatusStyle palette;

  const _StatusPill({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(palette.icon, size: 12, color: palette.text),
          const SizedBox(width: 4),
          Text(
            palette.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final Color border;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
