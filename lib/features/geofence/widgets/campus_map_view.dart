import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../core/models/geofence/location_trail.dart';
import '../../../core/models/geofence/student_location.dart';
import '../../../core/services/geofence_service.dart';
import '../../../core/utils/date_formatting.dart';
import '../controllers/student_locations_controller.dart';

/// Interactive radar & map visualization of Hari Saurabh Hostel perimeter
/// and live student locations.
class CampusMapView extends StatefulWidget {
  final StudentLocationsController controller;

  const CampusMapView({
    super.key,
    required this.controller,
  });

  @override
  State<CampusMapView> createState() => _CampusMapViewState();
}

class _CampusMapViewState extends State<CampusMapView> {
  final MapController _mapController = MapController();
  static final ll.LatLng _campusCenter = const ll.LatLng(22.5565, 72.9185);

  Worker? _trailWorker;
  int? _activeDot;

  @override
  void initState() {
    super.initState();
    // Frame the whole trail once it has loaded.
    _trailWorker = ever(widget.controller.selectedStudentTrail, (_) {
      final trail = _parse(widget.controller.selectedStudentTrail);
      _activeDot = null;
      if (!trail.hasPath) return;
      try {
        _mapController.fitCamera(CameraFit.coordinates(
          coordinates: trail.latLngs,
          padding: const EdgeInsets.fromLTRB(48, 150, 48, 260),
          maxZoom: 18,
        ));
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _trailWorker?.dispose();
    super.dispose();
  }

  LocationTrail _parse(List<Map<String, dynamic>> rows) => LocationTrail.parse(rows.toList());

  /// Start and latest pins plus a tappable dot for every fix in between.
  List<Marker> _trailMarkers(LocationTrail trail) {
    final pts = trail.points;
    final markers = <Marker>[];
    for (var i = 1; i < pts.length - 1; i++) {
      final p = pts[i];
      markers.add(Marker(
        point: p.point,
        width: 22,
        height: 22,
        child: GestureDetector(
          onTap: () => setState(() => _activeDot = _activeDot == i ? null : i),
          child: Center(
            child: Container(
              width: _activeDot == i ? 13 : 9,
              height: _activeDot == i ? 13 : 9,
              decoration: BoxDecoration(
                color: p.mocked ? const Color(0xFFD97706) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDC2626), width: 2),
              ),
            ),
          ),
        ),
      ));
    }
    markers.add(_endpointMarker(pts.first, 'Start', const Color(0xFF16A34A), Icons.trip_origin_rounded));
    markers.add(_endpointMarker(pts.last, 'Latest', const Color(0xFFDC2626), Icons.flag_rounded));

    final dot = _activeDot;
    if (dot != null && dot < pts.length) {
      markers.add(Marker(
        point: pts[dot].point,
        width: 120,
        height: 56,
        alignment: Alignment.topCenter,
        child: _pointBubble(pts[dot]),
      ));
    }
    return markers;
  }

  Marker _endpointMarker(TrailPoint p, String label, Color color, IconData icon) {
    return Marker(
      point: p.point,
      width: 76,
      height: 44,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 11, color: Colors.white),
                const SizedBox(width: 3),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Icon(Icons.arrow_drop_down, color: color, size: 16),
        ],
      ),
    );
  }

  Widget _pointBubble(TrailPoint p) {
    final t = p.time;
    final time = t == null
        ? 'Time unknown'
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} · ${DateFormatting.relativeTime(t)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        p.accuracyMeters > 0 ? '$time\n±${p.accuracyMeters.round()} m' : time,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// "Trail: 14 fixes · 1.2 km · over 2h 10m" — or the loading / empty state.
  Widget _trailSummary(StudentLocationsController controller) {
    return Obx(() {
      if (controller.isLoadingTrail.value) {
        return _summaryChip(
          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
          'Loading movement trail…',
        );
      }
      final trail = _parse(controller.selectedStudentTrail);
      if (!trail.hasPath) {
        return _summaryChip(
          const Icon(Icons.timeline_rounded, size: 14, color: Color(0xFF94A3B8)),
          'No movement recorded yet',
        );
      }
      final d = trail.distanceMeters;
      final dist = d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.round()} m';
      final span = trail.span;
      final over = span == null
          ? ''
          : span.inMinutes < 60
              ? ' · over ${span.inMinutes}m'
              : ' · over ${span.inHours}h ${span.inMinutes % 60}m';
      return _summaryChip(
        const Icon(Icons.timeline_rounded, size: 14, color: Color(0xFFDC2626)),
        'Trail: ${trail.points.length} stops · $dist$over',
      );
    });
  }

  Widget _summaryChip(Widget leading, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Stack(
      children: [
        // 1. The Interactive OpenStreetMap
        Obx(() {
          final students = controller.visible;
          final selected = controller.selectedStudent.value;
          final trail = controller.selectedStudentTrail;

          // Prepare Polygon points for Hari Saurabh Hostel
          final campusPoints = CampusGeofenceService.campusPolygon
              .map((p) => ll.LatLng(p.latitude, p.longitude))
              .toList();

          // Prepare Markers
          final markers = <Marker>[];
          for (final student in students) {
            final loc = student.location;
            if (loc == null || loc.latitude == 0 || loc.longitude == 0) continue;

            final isSelected = selected?.studentId == student.studentId;
            final isOutside = student.status == LocationStatus.outside;
            final isMocked = loc.mocked;

            final point = ll.LatLng(loc.latitude, loc.longitude);

            markers.add(
              Marker(
                point: point,
                width: isOutside ? 80 : 32,
                height: isOutside ? 54 : 32,
                child: GestureDetector(
                  onTap: () {
                    controller.selectStudent(student);
                    try {
                      _mapController.move(point, 17.5);
                    } catch (_) {}
                  },
                  child: isOutside
                      ? _buildOutsideMarker(student, isSelected, isMocked)
                      : _buildInsideMarker(student, isSelected),
                ),
              ),
            );
          }

          // Movement trail of the selected student: faint (old) to strong (latest).
          final parsedTrail = _parse(trail);
          final polylines = <Polyline>[];
          final trailMarkers = <Marker>[];
          if (parsedTrail.hasPath) {
            polylines.add(
              Polyline(
                points: parsedTrail.latLngs,
                strokeWidth: 4.5,
                borderStrokeWidth: 2,
                borderColor: Colors.white,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
                gradientColors: const [Color(0xFFFCA5A5), Color(0xFFDC2626)],
              ),
            );
            trailMarkers.addAll(_trailMarkers(parsedTrail));
          }

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _campusCenter,
              initialZoom: 16.5,
              minZoom: 14.0,
              maxZoom: 18.8,
              onTap: (_, _) {
                if (controller.selectedStudent.value != null) {
                  controller.selectStudent(null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.hsh_app2',
              ),
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: campusPoints,
                    color: const Color(0xFF0284C7).withValues(alpha: 0.16),
                    borderColor: const Color(0xFF0284C7),
                    borderStrokeWidth: 2.5,
                    
                  ),
                ],
              ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              MarkerLayer(markers: trailMarkers),
              MarkerLayer(markers: markers),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          );
        }),

        // 2. Top Floating Navigation & Stats Header
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          child: _buildTopHeader(context, controller),
        ),

        // 3. Right-side Floating Map Controls (Center, Zoom)
        Positioned(
          right: 16,
          bottom: 150,
          child: Column(
            children: [
              _buildFloatingMapButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Center on Campus',
                onTap: () {
                  try {
                    _mapController.move(_campusCenter, 16.5);
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 8),
              _buildFloatingMapButton(
                icon: Icons.add_rounded,
                tooltip: 'Zoom In',
                onTap: () {
                  try {
                    final zoom = (_mapController.camera.zoom + 1.0).clamp(14.0, 18.8);
                    _mapController.move(_mapController.camera.center, zoom);
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 8),
              _buildFloatingMapButton(
                icon: Icons.remove_rounded,
                tooltip: 'Zoom Out',
                onTap: () {
                  try {
                    final zoom = (_mapController.camera.zoom - 1.0).clamp(14.0, 18.8);
                    _mapController.move(_mapController.camera.center, zoom);
                  } catch (_) {}
                },
              ),
            ],
          ),
        ),

        // 4. Bottom Selected Student Drawer
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Obx(() {
            final student = controller.selectedStudent.value;
            if (student == null) return const SizedBox.shrink();
            return _buildSelectedStudentCard(context, controller, student);
          }),
        ),
      ],
    );
  }

  Widget _buildTopHeader(BuildContext context, StudentLocationsController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (controller.isMapView.value) {
                  controller.toggleViewMode();
                } else {
                  Get.back();
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Switch back to list view
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: controller.toggleViewMode,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.view_list_rounded, color: Colors.white, size: 17),
                    SizedBox(width: 5),
                    Text(
                      'List',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Counts pill
          Expanded(
            child: Obx(() {
              final outside = controller.countOf(LocationStatus.outside);
              final inside = controller.countOf(LocationStatus.inside);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCountTag('🟢 Inside: $inside', const Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  _buildCountTag('🔴 Outside: $outside', const Color(0xFFEF4444)),
                ],
              );
            }),
          ),
          const SizedBox(width: 8),

          // Broadcast alert button
          Obx(() {
            final isAlerting = controller.isAlerting.value;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isAlerting ? null : controller.alertAllOutside,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isAlerting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCountTag(String text, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInsideMarker(StudentLocation student, bool isSelected) {
    final roomNum = student.room.replaceAll(RegExp(r'[^0-9]'), '');
    final label = roomNum.isNotEmpty ? roomNum.take(3) : student.room.take(3);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isSelected ? 36 : 28,
      height: isSelected ? 36 : 28,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF16A34A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: isSelected ? 2.5 : 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label.isEmpty ? 'H' : label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildOutsideMarker(StudentLocation student, bool isSelected, bool isMocked) {
    final dist = student.location?.distanceLabel ?? 'Outside';
    final firstName = student.name.trim().isNotEmpty
        ? student.name.trim().split(RegExp(r'\s+')).first
        : 'Student';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: isMocked ? const Color(0xFFD97706) : const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white,
              width: isSelected ? 2.2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isMocked ? const Color(0xFFD97706) : const Color(0xFFDC2626))
                    .withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMocked ? Icons.warning_amber_rounded : Icons.person_pin_circle_rounded,
                color: Colors.white,
                size: 13,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  '$firstName ($dist)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_drop_down,
          color: isMocked ? const Color(0xFFD97706) : const Color(0xFFDC2626),
          size: 16,
        ),
      ],
    );
  }

  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Icon(icon, color: const Color(0xFF0F172A), size: 20),
        ),
      ),
    );
  }

  Widget _buildSelectedStudentCard(
    BuildContext context,
    StudentLocationsController controller,
    StudentLocation student,
  ) {
    final loc = student.location;
    final isOutside = student.status == LocationStatus.outside;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOutside ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: isOutside ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isOutside
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isOutside ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name and Room
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Room ${student.room} • ${student.studentCode}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Dismiss button
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                onPressed: () => controller.selectStudent(null),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status & Telemetry details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isOutside
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOutside ? const Color(0xFFFEE2E2) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOutside ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                  size: 16,
                  color: isOutside ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isOutside
                        ? '${loc?.distanceLabel ?? "Outside perimeter"} • Reported ${loc?.freshnessLabel ?? "recently"}'
                        : 'Inside hostel • Reported ${loc?.freshnessLabel ?? "recently"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOutside ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
                if (loc?.accuracyMeters != null && (loc?.accuracyMeters ?? 0) > 0)
                  Text(
                    '±${loc!.accuracyMeters.toInt()}m',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _trailSummary(controller),
          const SizedBox(height: 14),

          // Actions: Call, Google Maps
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: const Text('Call Student', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => controller.callStudent(student),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.map_rounded, size: 16),
                  label: const Text('Google Maps', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => controller.openInMaps(student),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}

extension LocationFixMapX on LocationFix {
  String get distanceLabel {
    final d = distanceMeters;
    if (d == null) return insideCampus == true ? 'On Campus' : 'Outside';
    return d >= 1000 ? '${(d / 1000).toStringAsFixed(1)}km' : '${d.toInt()}m';
  }

  String get freshnessLabel {
    final diff = DateTime.now().difference(fixTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
