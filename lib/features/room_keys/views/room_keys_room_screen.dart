import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/room_keys/room_key_models.dart';
import '../controllers/room_keys_controller.dart';
import '../widgets/room_key_widgets.dart';

/// One room: its door keys, each student with their cupboard key, and any
/// other cupboard keys (office, lost, or with someone who moved out).
/// Styled to match the Hostel Phonebook navy-and-slate theme.
class RoomKeysRoomScreen extends GetView<RoomKeysController> {
  final String room;

  const RoomKeysRoomScreen({super.key, required this.room});

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _blue = Color(0xFF0284C7);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _slate = Color(0xFF475569);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _amber = Color(0xFFD97706);

  String get _number => normalizeRoom(room);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => RoomKeysSetupSheet.show(controller, _number),
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add keys', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: RefreshIndicator(
          onRefresh: () => controller.load(showLoading: false),
          color: _blue,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _SingleRoomHeaderDelegate(
                  controller: controller,
                  roomNumber: _number,
                  topPadding: MediaQuery.of(context).padding.top,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                sliver: SliverToBoxAdapter(child: Obx(() => _content(controller.room(_number)))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(KeyRoom r) {
    if (controller.isLoading.value && controller.keys.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }
    final busy = controller.busyIds;
    Widget tile(RoomKey k) =>
        RoomKeyTile(roomKey: k, busy: busy.contains(k.id), onTap: () => KeyActionsSheet.show(controller, k));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Door lock'),
        _sectionCard(
          child: r.doorKeys.isEmpty
              ? _missing('No door key yet', () => RoomKeysSetupSheet.show(controller, _number))
              : Column(children: _divided([for (final k in r.doorKeys) tile(k)])),
        ),
        _heading('Students and cupboards'),
        _sectionCard(
          child: r.students.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    controller.studentsUnavailable.value
                        ? 'The student list could not be loaded. Pull down to try again.'
                        : 'No student lives in this room.',
                    style: AppTextStyles.bodySm,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _divided([
                    for (final s in r.students)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            if (r.cupboardOf(s) case final k?)
                              tile(k)
                            else
                              _missing('No cupboard key', () => RoomKeysSetupSheet.show(controller, _number)),
                          ],
                        ),
                      ),
                  ]),
                ),
        ),
        if (r.otherCupboardKeys.isNotEmpty) ...[
          _heading('Other cupboard keys'),
          _sectionCard(
            child: Column(children: _divided([for (final k in r.otherCupboardKeys) tile(k)])),
          ),
        ],
      ],
    );
  }

  static Widget _sectionCard({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  static List<Widget> _divided(List<Widget> items) => [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) const Divider(height: 1, color: _border),
      items[i],
    ],
  ];

  static Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 10),
    child: Row(
      children: [
        Container(
          width: 20,
          height: 3.5,
          decoration: BoxDecoration(
            color: _amber,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: _slate,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );

  static Widget _missing(String text, VoidCallback onAdd) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        const Icon(Icons.key_off_rounded, size: 18, color: AppColors.warningOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD97706),
            ),
          ),
        ),
        TextButton(
          onPressed: onAdd,
          style: TextButton.styleFrom(foregroundColor: _blue),
          child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

class _SingleRoomHeaderDelegate extends SliverPersistentHeaderDelegate {
  final RoomKeysController controller;
  final String roomNumber;
  final double topPadding;
  final VoidCallback onBack;

  _SingleRoomHeaderDelegate({
    required this.controller,
    required this.roomNumber,
    required this.topPadding,
    required this.onBack,
  });

  @override
  double get minExtent => topPadding + 60.0;

  @override
  double get maxExtent => topPadding + 164.0;

  Widget _statusPill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius = Radius.circular((28.0 * (1.0 - progress)).clamp(0.0, 28.0));

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
            Positioned.fill(
              child: CustomPaint(painter: _SingleRoomOrbPainter()),
            ),
            Positioned(
              top: topPadding + 6,
              left: 14,
              right: 14,
              height: 48,
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onBack,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: Text(
                        'Room $roomNumber',
                        style: const TextStyle(
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
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Opacity(
                opacity: expandedOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ROOM KEYS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Room $roomNumber',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Obx(() {
                      final r = controller.room(roomNumber);
                      return Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _statusPill(
                            Icons.key_rounded,
                            '${r.keys.length} keys · ${r.students.length} students',
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _SingleRoomOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.38, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.62, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.86, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
