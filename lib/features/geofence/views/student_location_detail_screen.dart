import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/models/geofence/student_location.dart';
import '../../../core/services/geofence_service.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../controllers/student_locations_controller.dart';
import '../utils/location_accuracy.dart';

/// Detailed geolocation view for one student: curfew boundary status, live GPS
/// fix metrics, campus fence mini-map with movement trail, contact actions, and
/// recent ping timeline.
class StudentLocationDetailScreen extends StatefulWidget {
  final StudentLocation student;
  final StudentLocationsController controller;

  /// Optional tile provider override (used in widget tests to avoid network calls).
  final TileProvider? tileProvider;

  /// Optional class-level override for widget tests when pushed via navigation.
  @visibleForTesting
  static TileProvider? defaultTileProvider;

  const StudentLocationDetailScreen({
    super.key,
    required this.student,
    required this.controller,
    this.tileProvider,
  });

  @override
  State<StudentLocationDetailScreen> createState() =>
      _StudentLocationDetailScreenState();
}

class _StudentLocationDetailScreenState
    extends State<StudentLocationDetailScreen> {
  final MapController _mapController = MapController();
  ll.LatLng? _focusedPoint;

  StudentLocation get _liveStudent =>
      widget.controller.students.firstWhereOrNull(
        (s) => s.studentId == widget.student.studentId,
      ) ??
      widget.student;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.selectStudent(_liveStudent);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await widget.controller.load(silent: true);
    if (!mounted) return;
    await widget.controller.selectStudent(_liveStudent);
  }

  void _focusMapOn(double lat, double lng) {
    if (lat == 0 && lng == 0) return;
    final point = ll.LatLng(lat, lng);
    setState(() => _focusedPoint = point);
    try {
      _mapController.move(point, 17.5);
    } catch (_) {}
  }

  void _copyCoords(double lat, double lng) {
    final text = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.success('Copied', 'Coordinates copied: $text');
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF0284C7),
          backgroundColor: Colors.white,
          child: Obx(() {
            final student = _liveStudent;
            final loc = student.location;
            final trail = widget.controller.selectedStudentTrail.toList();
            final isLoadingTrail = widget.controller.isLoadingTrail.value;
            final subtitleParts = <String>[
              if (student.room.trim().isNotEmpty) 'Room ${student.room.trim()}',
              if (student.studentCode.trim().isNotEmpty)
                student.studentCode.trim(),
            ];

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: PhonebookHeaderDelegate(
                    overline: 'GEOLOCATION DETAILS',
                    title: student.name,
                    subtitle:
                        subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
                    topPadding: topPad,
                    onLeadingTap: () => Navigator.of(context).pop(),
                    trailing: PhonebookHeaderCircleButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh location',
                      onTap: isLoadingTrail ? null : _refresh,
                    ),
                    pills: _buildHeaderPills(student, loc),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + bottomPad),
                  sliver: SliverList.list(
                    children: [
                      if (loc != null && loc.mocked) ...[
                        _buildFakeGpsBanner(),
                        const SizedBox(height: 12),
                      ],
                      _buildStatusSummaryCard(student, loc),
                      const SizedBox(height: 12),
                      if (loc != null &&
                          (loc.latitude != 0 || loc.longitude != 0)) ...[
                        _buildMapCard(student, loc, trail),
                        const SizedBox(height: 12),
                      ],
                      if (loc != null) ...[
                        _buildTelemetryCard(student, loc),
                        const SizedBox(height: 12),
                      ],
                      if (student.phone.trim().isNotEmpty ||
                          student.parentPhone.trim().isNotEmpty) ...[
                        _buildContactsCard(student),
                        const SizedBox(height: 12),
                      ],
                      _buildTrailCard(student, trail, isLoadingTrail),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHeaderPills(StudentLocation student, LocationFix? loc) {
    final statusLabel = switch (student.status) {
      LocationStatus.outside => 'Outside campus',
      LocationStatus.inside => 'Inside campus',
      LocationStatus.unknownArea => 'Location reported',
      LocationStatus.noData => 'No GPS fix',
    };
    final statusIcon = switch (student.status) {
      LocationStatus.outside => Icons.wrong_location_rounded,
      LocationStatus.inside => Icons.where_to_vote_rounded,
      LocationStatus.unknownArea => Icons.location_on_rounded,
      LocationStatus.noData => Icons.location_off_rounded,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        PhonebookHeaderPill(icon: statusIcon, label: statusLabel),
        if (loc != null)
          PhonebookHeaderPill(
            icon: Icons.schedule_rounded,
            label: 'Updated ${DateFormatting.relativeTime(loc.fixTime)}',
          ),
      ],
    );
  }

  Widget _buildFakeGpsBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.4),
      ),
      child: const Row(
        children: [
          Icon(Icons.gpp_bad_rounded, color: Color(0xFFDC2626), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fake GPS Detected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF991B1B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'The device reported a mocked/spoofed GPS location.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummaryCard(StudentLocation student, LocationFix? loc) {
    final (title, subtitle, color, bg, border, icon) = switch (student.status) {
      LocationStatus.outside => (
          'Outside Campus Perimeter',
          loc?.distanceMeters != null
              ? '${loc!.distanceMeters!.round()} m beyond hostel boundary'
              : 'Reported outside the campus geofence',
          const Color(0xFFDC2626),
          const Color(0xFFFEF2F2),
          const Color(0xFFFCA5A5),
          Icons.wrong_location_rounded,
        ),
      LocationStatus.inside => (
          'Inside Campus Perimeter',
          loc?.distanceMeters != null && loc!.distanceMeters! > 0
              ? 'Inside campus · ${loc.distanceMeters!.round()} m from fence'
              : 'Device is within the hostel boundary',
          const Color(0xFF16A34A),
          const Color(0xFFF0FDF4),
          const Color(0xFF86EFAC),
          Icons.where_to_vote_rounded,
        ),
      LocationStatus.unknownArea => (
          'Location Reported',
          'Coordinates available without fence classification',
          const Color(0xFF0284C7),
          const Color(0xFFE0F2FE),
          const Color(0xFFBAE6FD),
          Icons.location_on_rounded,
        ),
      LocationStatus.noData => (
          'No GPS Fix Yet',
          'Phone is offline, location is off, or setup has not completed yet',
          const Color(0xFF64748B),
          const Color(0xFFF1F5F9),
          const Color(0xFFCBD5E1),
          Icons.satellite_alt_outlined,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(
    StudentLocation student,
    LocationFix loc,
    List<Map<String, dynamic>> trail,
  ) {
    final studentPoint = ll.LatLng(loc.latitude, loc.longitude);
    final activeFocus = _focusedPoint ?? studentPoint;
    final campusPoints = CampusGeofenceService.campusPolygon
        .map((p) => ll.LatLng(p.latitude, p.longitude))
        .toList();

    final trailPoints = <ll.LatLng>[];
    for (final point in trail) {
      final lat = _num(point['latitude'] ?? point['lat']);
      final lng = _num(point['longitude'] ?? point['lng']);
      if (lat != null && lng != null && (lat != 0 || lng != 0)) {
        trailPoints.add(ll.LatLng(lat, lng));
      }
    }

    final isOutside = student.status == LocationStatus.outside;
    final pinColor = loc.mocked
        ? const Color(0xFFD97706)
        : (isOutside ? const Color(0xFFDC2626) : const Color(0xFF16A34A));

    return _SectionCard(
      title: 'Campus Fence & Pin',
      trailing: TextButton.icon(
        onPressed: () => widget.controller.openInMaps(student),
        icon: const Icon(Icons.open_in_new_rounded, size: 15),
        label: const Text(
          'Google Maps',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF0284C7),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 220,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: activeFocus,
                  initialZoom: 16.8,
                  minZoom: 13.0,
                  maxZoom: 18.8,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.hsh_app2',
                    tileProvider: widget.tileProvider ??
                        StudentLocationDetailScreen.defaultTileProvider,
                  ),
                  if (campusPoints.isNotEmpty)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: campusPoints,
                          color:
                              const Color(0xFF0284C7).withValues(alpha: 0.14),
                          borderColor: const Color(0xFF0284C7),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  if (trailPoints.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: trailPoints,
                          color: const Color(0xFF0284C7),
                          strokeWidth: 3,
                        ),
                      ],
                    ),
                  if (loc.accuracyMeters > 0)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: studentPoint,
                          radius: loc.accuracyMeters,
                          useRadiusInMeter: true,
                          color: LocationAccuracy.color(loc.accuracyMeters)
                              .withValues(alpha: 0.16),
                          borderColor: LocationAccuracy.color(loc.accuracyMeters)
                              .withValues(alpha: 0.6),
                          borderStrokeWidth: 1.4,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_focusedPoint != null &&
                          _focusedPoint != studentPoint)
                        Marker(
                          point: _focusedPoint!,
                          width: 18,
                          height: 18,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
                            ),
                          ),
                        ),
                      Marker(
                        point: studentPoint,
                        width: 34,
                        height: 34,
                        child: Container(
                          decoration: BoxDecoration(
                            color: pinColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: pinColor.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_pin_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    onTap: () => _focusMapOn(loc.latitude, loc.longitude),
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(StudentLocation student, LocationFix loc) {
    final accPct = LocationAccuracy.percentage(loc.accuracyMeters);
    final (accColor, _, _) = LocationAccuracy.palette(loc.accuracyMeters);
    final coordsLabel =
        '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}';
    final distanceValue = loc.distanceMeters != null
        ? '${loc.distanceMeters!.round()} m'
        : (student.status == LocationStatus.inside ? 'On campus' : '--');

    return _SectionCard(
      title: 'GPS Telemetry',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.near_me_rounded,
                  label: 'Distance',
                  value: distanceValue,
                  accent: student.status == LocationStatus.outside
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.gps_fixed_rounded,
                  label: 'Accuracy',
                  value: loc.accuracyMeters > 0
                      ? '$accPct% (±${loc.accuracyMeters.round()} m)'
                      : '$accPct%',
                  accent: accColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.schedule_rounded,
                  label: 'Captured (IST)',
                  value: DateFormatting.dateTime(loc.fixTime),
                ),
              ),
              if (loc.receivedAt != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.cloud_done_outlined,
                    label: 'Synced (IST)',
                    value: DateFormatting.dateTime(loc.receivedAt!),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _copyCoords(loc.latitude, loc.longitude),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pin_drop_outlined,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coordinates',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            coordsLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsCard(StudentLocation student) {
    final hasStudent = student.phone.trim().isNotEmpty;
    final hasParent = student.parentPhone.trim().isNotEmpty;

    return _SectionCard(
      title: 'Quick Contact',
      child: Row(
        children: [
          if (hasStudent)
            Expanded(
              child: _ContactButton(
                icon: Icons.phone_rounded,
                label: 'Call Student',
                subtitle: student.phone.trim(),
                color: const Color(0xFF0284C7),
                background: const Color(0xFFE0F2FE),
                onTap: () => widget.controller.callStudent(student),
              ),
            ),
          if (hasStudent && hasParent) const SizedBox(width: 10),
          if (hasParent)
            Expanded(
              child: _ContactButton(
                icon: Icons.family_restroom_rounded,
                label: 'Call Parent',
                subtitle: student.parentPhone.trim(),
                color: const Color(0xFF059669),
                background: const Color(0xFFD1FAE5),
                onTap: () => widget.controller.callParent(student),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailCard(
    StudentLocation student,
    List<Map<String, dynamic>> trail,
    bool isLoadingTrail,
  ) {
    return _SectionCard(
      title: 'Recent Movement History',
      trailing: trail.isNotEmpty
          ? Text(
              '${trail.length} ${trail.length == 1 ? 'ping' : 'pings'}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            )
          : null,
      child: isLoadingTrail
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            )
          : trail.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No movement history recorded yet for this student.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < trail.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 12,
                          thickness: 0.7,
                          color: Color(0xFFF1F5F9),
                        ),
                      _buildTrailItem(trail[i]),
                    ],
                  ],
                ),
    );
  }

  Widget _buildTrailItem(Map<String, dynamic> entry) {
    final lat = _num(entry['latitude'] ?? entry['lat']) ?? 0;
    final lng = _num(entry['longitude'] ?? entry['lng']) ?? 0;
    final inside = entry['insideCampus'] == true;
    final mocked = entry['mocked'] == true;
    final dist = _num(entry['distanceMeters']);
    final acc = _num(entry['accuracyMeters']) ?? 0;
    final fixMs = _num(entry['fixTime'])?.toInt() ?? 0;
    final fixTime = fixMs > 0 ? DateTime.fromMillisecondsSinceEpoch(fixMs) : null;

    final Color dotColor = mocked
        ? const Color(0xFFD97706)
        : (inside ? const Color(0xFF16A34A) : const Color(0xFFDC2626));
    final String statusText = mocked
        ? 'Fake GPS'
        : (inside
            ? 'Inside campus'
            : (dist != null && dist > 0
                ? '${dist.round()} m outside'
                : 'Outside campus'));

    return InkWell(
      onTap: (lat != 0 || lng != 0) ? () => _focusMapOn(lat, lng) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: dotColor,
                    ),
                  ),
                  if (fixTime != null)
                    Text(
                      DateFormatting.dateTime(fixTime),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
            if (acc > 0)
              Text(
                '±${acc.round()} m',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = const Color(0xFF0F172A),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13.5, color: const Color(0xFF64748B)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
