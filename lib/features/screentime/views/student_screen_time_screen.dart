import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/screen_time_directory_controller.dart';
import '../widgets/student_overview_body.dart';
import '../widgets/student_directory_view.dart';

/// Warden's screen-time console styled with the signature deep navy header,
/// sky-blue accents, and slate card styling from the Phonebook screen.
class StudentScreenTimeScreen extends GetView<ScreenTimeDirectoryController> {
  final bool showBackButton;
  const StudentScreenTimeScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    // Opened as its own route (not the operator shell tab): apply the route's
    // arguments (e.g. a student name from the phonebook) even when the
    // controller already existed.
    return _LaunchArguments(
      enabled: showBackButton,
      controller: controller,
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Obx(() {
        final selected = controller.selectedStudent.value;
        final detail = controller.detail.value;
        final direct = controller.openedWithDirectTarget.value;
        final canPopDirectly = selected == null || direct;

        return PopScope(
          canPop: canPopDirectly,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (controller.selectedStudent.value != null &&
                !controller.openedWithDirectTarget.value) {
              controller.clearSelectedStudent();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: RefreshIndicator(
              onRefresh: controller.refreshAll,
              color: const Color(0xFF0284C7),
              backgroundColor: Colors.white,
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (selected == null &&
                      scrollInfo is ScrollUpdateNotification &&
                      scrollInfo.metrics.extentAfter < 600) {
                    controller.loadMoreItems();
                  }
                  return false;
                },
                child: CustomScrollView(
                  controller: controller.pageScrollController,
                  key: ValueKey(
                    detail != null ? 'detail_${detail.tag}' : 'directory',
                  ),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ScreenTimeHeaderDelegate(
                        controller: controller,
                        topPadding: MediaQuery.of(context).padding.top,
                        showBackButton: showBackButton,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      sliver: detail == null
                          ? const StudentDirectoryView()
                          : SliverToBoxAdapter(child: StudentOverviewBody(controller: detail)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

}

/// Applies the route arguments to [controller] once the route is shown, and
/// clears the name search again when the route is closed.
class _LaunchArguments extends StatefulWidget {
  final bool enabled;
  final ScreenTimeDirectoryController controller;
  final Widget child;
  const _LaunchArguments({
    required this.enabled,
    required this.controller,
    required this.child,
  });

  @override
  State<_LaunchArguments> createState() => _LaunchArgumentsState();
}

class _LaunchArgumentsState extends State<_LaunchArguments> {
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applied = Get.arguments is Map;
      widget.controller.reapplyLaunchArguments();
    });
  }

  @override
  void dispose() {
    if (_applied) {
      final c = widget.controller;
      Future.microtask(() {
        if (c.openedWithDirectTarget.value) {
          // Opened straight on one student: leave the shared controller on the
          // list again for the Safety tab.
          c.clearSelectedStudent();
        } else if (c.selectedStudent.value == null) {
          c.clearSearch();
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Collapsible shrinking deep navy header with luminous arcs, matching Phonebook header.
class _ScreenTimeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final ScreenTimeDirectoryController controller;
  final double topPadding;
  final bool showBackButton;

  _ScreenTimeHeaderDelegate({
    required this.controller,
    required this.topPadding,
    this.showBackButton = true,
  });

  @override
  double get minExtent => topPadding + 62.0;

  @override
  double get maxExtent {
    // The all-students header has no subtitle line, so it needs less height.
    return topPadding +
        (controller.selectedStudent.value != null ? 176.0 : 108.0);
  }

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

    return Obx(() {
      final selected = controller.selectedStudent.value;
      final direct = controller.openedWithDirectTarget.value;
      final titleText = selected != null
          ? (selected['name'] ?? 'Student')
          : 'Screen Time';
      final subtitleText =
          'Room ${selected?['room'] ?? ''} • Aadhar ${selected?['aadhar'] ?? ''}';
      // The opened student's live flags; the list shows none of them.
      final detail = controller.detail.value;
      final isLoading = detail?.isLoading.value ?? false;
      final isOnline = detail?.isOnline.value ?? false;
      final isLocked = detail?.isDeviceLocked.value ?? false;

      // Refresh button with loading spinner
      Widget refreshButton() => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : controller.refreshAll,
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
                    color: const Color(
                      0xFF03192E,
                    ).withValues(alpha: 0.22 * progress),
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
              RepaintBoundary(
                child: CustomPaint(painter: _HeaderOrbPainter()),
              ),

              // Top pinned navigation bar
              Positioned(
                top: topPadding + 6,
                left: 16,
                right: 16,
                height: 46,
                child: Row(
                  children: [
                    if (selected != null ||
                        (showBackButton && Navigator.canPop(context))) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (selected != null && !direct) {
                              controller.clearSelectedStudent();
                            } else {
                              Get.back();
                            }
                          },
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
                    ],

                    // Collapsed title that fades in on shrink
                    Expanded(
                      child: Opacity(
                        opacity: collapsedTitleOpacity,
                        child: Text(
                          titleText,
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

                    // "All students" button if in direct target mode
                    if (selected != null && direct) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            controller.openedWithDirectTarget.value = false;
                            controller.clearSelectedStudent();
                          },
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
                              Icons.people_alt_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Refresh button (collapsed state only; expanded state
                    // shows it in the content row below)
                    Opacity(
                      opacity: collapsedTitleOpacity,
                      child: IgnorePointer(
                        ignoring: collapsedTitleOpacity < 0.5,
                        child: refreshButton(),
                      ),
                    ),
                  ],
                ),
              ),

              // Expanded content (Amber dash, Overline, Large Title, Subtitle, Frosted pills)
              if (expandedOpacity > 0.05)
                Positioned(
                  top: topPadding + (selected != null ? 54 : 20),
                  left: 20,
                  right: 20,
                  bottom: selected != null ? 12 : 24,
                  child: Opacity(
                    opacity: expandedOpacity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ClipRect(
                            child: Transform.translate(
                              offset: Offset(0, -progress * 18),
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                reverse: true,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Container(
                                    //   width: 28,
                                    //   height: 3.5,
                                    //   decoration: BoxDecoration(
                                    //     color: const Color(0xFFEAAB78),
                                    //     borderRadius: BorderRadius.circular(2),
                                    //   ),
                                    // ),
                                    const SizedBox(height: 6),
                                    Text(
                                      selected != null
                                          ? 'PARENTAL CONTROL'
                                          : 'PARENTAL CONTROL & DEVICE USAGE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFF59E0B),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      titleText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.6,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    if (selected != null)
                                      Text(
                                        subtitleText,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (selected != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _headerPill(
                                            icon: isOnline
                                                ? Icons.circle_rounded
                                                : Icons
                                                      .remove_circle_outline_rounded,
                                            iconColor: isOnline
                                                ? const Color(0xFF34D399)
                                                : const Color(0xFF94A3B8),
                                            label: isOnline
                                                ? 'Online'
                                                : 'Offline',
                                          ),
                                          const SizedBox(width: 8),
                                          _headerPill(
                                            icon: isLocked
                                                ? Icons.lock_rounded
                                                : Icons.lock_open_rounded,
                                            iconColor: isLocked
                                                ? const Color(0xFFF87171)
                                                : const Color(0xFF34D399),
                                            label: isLocked
                                                ? 'Device Locked'
                                                : 'Unlocked',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Aligned with the pills row at the bottom of the content
                        refreshButton(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
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
  bool shouldRebuild(covariant _ScreenTimeHeaderDelegate oldDelegate) {
    return true;
  }
}

/// Custom painter for luminous concentric arcs and ambient light orbs in the header background.
class _HeaderOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top-right luminous ambient glow
    final glowPaintRight = Paint()
      ..shader =
          RadialGradient(
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
      ..shader =
          RadialGradient(
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
