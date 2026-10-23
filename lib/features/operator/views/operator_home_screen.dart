import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/services/shorebird_service.dart';
import '../../../core/storage/session_store.dart';
import '../../phonebook/bindings/phonebook_binding.dart';
import '../../phonebook/views/phonebook_screen.dart';
import '../../screentime/bindings/student_screen_time_binding.dart';
import '../../screentime/views/student_screen_time_screen.dart';
import '../../shared/widgets/staggered_slide_fade.dart';

class _OperatorAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgTint;
  final Color arrowBgTint;
  final Color waveColor;
  final String route;

  /// Shown to platform admins only (e.g. Manage Users).
  final bool adminOnly;

  const _OperatorAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgTint,
    required this.arrowBgTint,
    required this.waveColor,
    required this.route,
    this.adminOnly = false,
  });
}

class _OperatorGroup {
  final String title;
  final List<_OperatorAction> actions;

  const _OperatorGroup(this.title, this.actions);
}

/// Operator & Hostel Warden Console Dashboard.
class OperatorHomeScreen extends StatefulWidget {
  const OperatorHomeScreen({super.key});

  @override
  State<OperatorHomeScreen> createState() => _OperatorHomeScreenState();
}

class _OperatorHomeScreenState extends State<OperatorHomeScreen> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    // Pre-initialise controllers for the in-shell tabs so they are ready
    // when the user switches tabs without navigating away.
    PhonebookBinding().dependencies();
    StudentScreenTimeBinding().dependencies();
  }


  Future<void> _logout() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out from the Operator Console?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Get.back(result: true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Get.find<SessionStore>().clear();
      Get.offAllNamed(Routes.login);
    }
  }

  void _showProfileSheet(BuildContext context) {
    final sessionStore = Get.find<SessionStore>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0284C7), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sessionStore.currentSession?.name.isNotEmpty == true
                              ? sessionStore.currentSession!.name
                              : 'Hostel Operator',
                          style: AppTextStyles.headline.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Administrator • Operator Role',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0284C7)),
                title: const Text('Current Academic Session', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(DateFormat('yyyy').format(DateTime.now())),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48)),
                title: const Text('Sign Out', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: _currentNavIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentNavIndex != 0) {
            setState(() => _currentNavIndex = 0);
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          // IndexedStack keeps all tab widgets alive; no route push → no back button.
          body: IndexedStack(
            index: _currentNavIndex,
            children: [
              // Tab 0 – Home Dashboard
              _OperatorHomeDashboard(
                onSelectTab: (index) => setState(() => _currentNavIndex = index),
                onLogout: _logout,
              ),
              // Tab 1 – Students (Phonebook)
              const PhonebookScreen(showBackButton: false),
              // Tab 2 – Safety (Screen Time)
              const StudentScreenTimeScreen(showBackButton: false),
            ],
          ),
          bottomNavigationBar: _OperatorBottomNavBar(
            currentIndex: _currentNavIndex,
            onTap: (index) {
              if (index == 3) {
                _showProfileSheet(context);
              } else {
                setState(() => _currentNavIndex = index);
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Deep navy header with luminous curved arcs, calendar pill, building image, and logout button.
/// Collapsible shrinking deep navy header with luminous arcs, matching Phonebook header.
class _OperatorHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final VoidCallback onLogout;

  _OperatorHeaderDelegate({
    required this.topPadding,
    required this.onLogout,
  });

  @override
  double get minExtent => topPadding + 60.0;

  @override
  double get maxExtent => topPadding + 172.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final dateStr = DateFormat('EEE, d MMM yyyy').format(DateTime.now());
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius = Radius.circular(
      (28.0 * (1.0 - progress)).clamp(0.0, 28.0),
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
            // Luminous decorative ambient glow & arcs
            CustomPaint(painter: _HeaderOrbPainter()),

            // Top pinned navigation bar (Collapsed title + right top logout icon)
            Positioned(
              top: topPadding + 6,
              left: 16,
              right: 16,
              height: 46,
              child: Row(
                children: [
                  // Collapsed title that fades in on shrink
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: const Text(
                        'Hostel Admin',
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

                  // Right top Logout Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onLogout,
                      borderRadius: BorderRadius.circular(24),
                      child: Tooltip(
                        message: 'Sign Out',
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
                            Icons.logout_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Hero expanded text & date pill below (fades out as you scroll down)
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Opacity(
                opacity: expandedOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'OPERATOR CONSOLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Hostel Admin',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white70),
                              const SizedBox(width: 6),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, size: 13, color: Colors.white70),
                              SizedBox(width: 5),
                              Text(
                                'Manage & Approvals',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
  bool shouldRebuild(covariant _OperatorHeaderDelegate oldDelegate) =>
      oldDelegate.topPadding != topPadding || oldDelegate.onLogout != onLogout;
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
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.90, size.height * 0.15),
        radius: size.width * 0.55,
      ));
    canvas.drawCircle(Offset(size.width * 0.90, size.height * 0.15), size.width * 0.55, glowPaintRight);

    // Bottom-left subtle ambient glow
    final glowPaintLeft = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0284C7).withValues(alpha: 0.12),
          const Color(0xFF032B4F).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.10, size.height * 0.85),
        radius: size.width * 0.45,
      ));
    canvas.drawCircle(Offset(size.width * 0.10, size.height * 0.85), size.width * 0.45, glowPaintLeft);

    // Elegant concentric arcs with smooth stroke
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.065)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.38, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.62, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.86, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.92), size.width * 0.46, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Section title with amber indicator bar.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

/// Interactive 2x2 card with pastel squircle icon, circle arrow, and organic corner wave.
class _OperatorCard extends StatelessWidget {
  final _OperatorAction action;
  final VoidCallback? onTap;

  const _OperatorCard({
    required this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Get.toNamed(action.route),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Bottom-right decorative curved wave
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(82, 58),
                  painter: _CornerWavePainter(
                    color: action.waveColor.withValues(alpha: 0.45),
                  ),
                ),
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: squircle icon + circular arrow
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: action.bgTint,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            action.icon,
                            color: action.iconColor,
                            size: 22,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: action.arrowBgTint,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: action.iconColor,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      action.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

/// Custom painter for organic curved wave in the bottom-right corner of each card.
class _CornerWavePainter extends CustomPainter {
  final Color color;

  const _CornerWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.72,
      size.width * 0.55,
      size.height * 0.48,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.22,
      size.width,
      0,
    );
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerWavePainter oldDelegate) => oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Home-tab dashboard
// ---------------------------------------------------------------------------
class _OperatorHomeDashboard extends StatelessWidget {
  final ValueChanged<int>? onSelectTab;
  final VoidCallback? onLogout;

  const _OperatorHomeDashboard({
    this.onSelectTab,
    this.onLogout,
  });

  static const _primaryGroups = [
    _OperatorGroup('Student Management & Safety', [
      _OperatorAction(
        title: 'Student Phonebook',
        subtitle: 'Campus contacts &\ncommunication',
        icon: Icons.groups_rounded,
        iconColor: Color(0xFF0284C7),
        bgTint: Color(0xFFE0F2FE),
        arrowBgTint: Color(0xFFF0F9FF),
        waveColor: Color(0xFFBAE6FD),
        route: Routes.operatorDirectory,
      ),
      _OperatorAction(
        title: 'Screen Time',
        subtitle: 'Telemetry, app\nrestrictions',
        icon: Icons.phone_android_rounded,
        iconColor: Color(0xFFEA580C),
        bgTint: Color(0xFFFFEDD5),
        arrowBgTint: Color(0xFFFFF7ED),
        waveColor: Color(0xFFFED7AA),
        route: Routes.studentScreenTime,
      ),
      _OperatorAction(
        title: 'Student Locations',
        subtitle: 'Live student location\noverview',
        icon: Icons.radar_rounded,
        iconColor: Color(0xFF0D9488),
        bgTint: Color(0xFFCCFBF1),
        arrowBgTint: Color(0xFFF0FDFA),
        waveColor: Color(0xFF99F6E4),
        route: Routes.operatorStudentLocations,
      ),
      _OperatorAction(
        title: 'Birthday Wishes',
        subtitle: 'Automated greetings &\ncelebrants',
        icon: Icons.cake_rounded,
        iconColor: Color(0xFFD97706),
        bgTint: Color(0xFFFEF3C7),
        arrowBgTint: Color(0xFFFFFBEB),
        waveColor: Color(0xFFFDE68A),
        route: Routes.operatorBirthdayWishes,
      ),
    ]),
    _OperatorGroup('Hostel Services & Staff', [
      _OperatorAction(
        title: 'Complaints Desk',
        subtitle: 'Room complaints &\nstatus updates',
        icon: Icons.handyman_rounded,
        iconColor: Color(0xFF7C3AED),
        bgTint: Color(0xFFF5F3FF),
        arrowBgTint: Color(0xFFEDE9FE),
        waveColor: Color(0xFFDDD6FE),
        route: Routes.complainSolverModule,
      ),
      _OperatorAction(
        title: 'Manage User',
        subtitle: 'Complaint solvers &\nlaundry staff',
        icon: Icons.manage_accounts_rounded,
        iconColor: Color(0xFF4F46E5),
        bgTint: Color(0xFFE0E7FF),
        arrowBgTint: Color(0xFFEEF2FF),
        waveColor: Color(0xFFC7D2FE),
        route: Routes.operatorManageUsers,
        adminOnly: true,
      ),
    ]),
  ];

  List<_OperatorGroup> _visibleGroups(BuildContext context) {
    final isAdmin = Get.find<SessionStore>().currentSession?.role == UserRole.admin;
    return [
      for (final group in _primaryGroups)
        _OperatorGroup(group.title, [
          for (final action in group.actions)
            if (!action.adminOnly || isAdmin) action,
        ]),
    ].where((group) => group.actions.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _visibleGroups(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        if (onLogout != null)
          SliverPersistentHeader(
            pinned: true,
            delegate: _OperatorHeaderDelegate(
              topPadding: topPadding,
              onLogout: onLogout!,
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int g = 0; g < groups.length; g++) ...[
                  _SectionHeader(title: groups[g].title),
                  const SizedBox(height: 8),
                  GridView.count(
                    padding: EdgeInsets.zero,
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.10,
                    children: [
                      for (int i = 0; i < groups[g].actions.length; i++)
                        StaggeredSlideFade(
                          index: i,
                          child: _OperatorCard(
                            action: groups[g].actions[i],
                            onTap: () {
                              if (groups[g].actions[i].route == Routes.operatorDirectory) {
                                onSelectTab?.call(1);
                              } else if (groups[g].actions[i].route == Routes.studentScreenTime) {
                                onSelectTab?.call(2);
                              } else {
                                Get.toNamed(groups[g].actions[i].route);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                  if (g < groups.length - 1) const SizedBox(height: 14),
                ],
                const SizedBox(height: 10),
                Center(
                  child: FutureBuilder<String>(
                    future: ShorebirdService.instance.getFullVersionInfo(),
                    builder: (context, snapshot) {
                      final info = snapshot.data ?? AppConfig.appVersionDisplay;
                      return Text(
                        'Hostel Admin Console • $info',
                        style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Modern bottom nav bar – floating pill indicator style
// ---------------------------------------------------------------------------

class _OperatorBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _OperatorBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItemData(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _NavItemData(icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Students'),
    _NavItemData(icon: Icons.shield_outlined, activeIcon: Icons.shield_rounded, label: 'Safety'),
    _NavItemData(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF03192E).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4, left: 8, right: 8),
          child: Row(
            children: [
              for (int i = 0; i < _items.length; i++)
                Expanded(
                  child: _ModernNavItem(
                    data: _items[i],
                    isSelected: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _ModernNavItem extends StatefulWidget {
  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModernNavItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ModernNavItem> createState() => _ModernNavItemState();
}

class _ModernNavItemState extends State<_ModernNavItem> {
  bool _isPressed = false;

  static const _activeIconColor = Color(0xFF0284C7);
  static const _activeTextColor = Color(0xFF032B4F);
  static const _inactiveColor = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: isSelected
                    ? const EdgeInsets.symmetric(horizontal: 18, vertical: 5)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFE0F2FE),
                            const Color(0xFFBAE6FD).withValues(alpha: 0.5),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: Icon(
                    isSelected ? widget.data.activeIcon : widget.data.icon,
                    key: ValueKey('${widget.data.label}_$isSelected'),
                    color: isSelected ? _activeIconColor : _inactiveColor,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? _activeTextColor : _inactiveColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
                child: Text(
                  widget.data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(top: 2),
                width: isSelected ? 14 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
