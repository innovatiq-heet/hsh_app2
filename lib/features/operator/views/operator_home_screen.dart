import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/shorebird_service.dart';
import '../../../core/storage/session_store.dart';
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

  const _OperatorAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgTint,
    required this.arrowBgTint,
    required this.waveColor,
    required this.route,
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
        title: 'Campus Geofence',
        subtitle: 'Curfew hours, hostel\nboundaries',
        icon: Icons.location_on_rounded,
        iconColor: Color(0xFFE11D48),
        bgTint: Color(0xFFFFE4E6),
        arrowBgTint: Color(0xFFFFF1F2),
        waveColor: Color(0xFFFECDD3),
        route: Routes.operatorGeofence,
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
    ]),
    /*
    _OperatorGroup('Alumni Network & Community', [
      _OperatorAction(
        title: 'Alumni Console',
        subtitle: 'Manage alumni network,\nevents and community',
        icon: Icons.forum_rounded,
        iconColor: Color(0xFF9333EA),
        bgTint: Color(0xFFF3E8FF),
        arrowBgTint: Color(0xFFFAF5FF),
        waveColor: Color(0xFFE9D5FF),
        route: Routes.operatorAlumni,
      ),
      _OperatorAction(
        title: 'Alumni Directory',
        subtitle: 'Search alumni by batch,\ndegree, company or city',
        icon: Icons.people_alt_rounded,
        iconColor: Color(0xFF2563EB),
        bgTint: Color(0xFFE0F2FE),
        arrowBgTint: Color(0xFFEFF6FF),
        waveColor: Color(0xFFBFDBFE),
        route: Routes.alumniDirectory,
      ),
    ]),
    */
  ];

  /*
  static const _additionalActions = [
    _OperatorAction(
      title: 'Complaints Desk',
      subtitle: 'Inspect & resolve student complaints',
      icon: Icons.handyman_rounded,
      iconColor: Color(0xFF7C3AED),
      bgTint: Color(0xFFF5F3FF),
      arrowBgTint: Color(0xFFEDE9FE),
      waveColor: Color(0xFFDDD6FE),
      route: Routes.complainSolverModule,
    ),
    _OperatorAction(
      title: 'Laundry Desk',
      subtitle: 'Manage wash cycles & student tokens',
      icon: Icons.local_laundry_service_rounded,
      iconColor: Color(0xFF0284C7),
      bgTint: Color(0xFFE0F2FE),
      arrowBgTint: Color(0xFFF0F9FF),
      waveColor: Color(0xFFBAE6FD),
      route: Routes.laundryModule,
    ),
    _OperatorAction(
      title: 'Dynamic QR Attendance',
      subtitle: 'Display rotating QR code for roll call',
      icon: Icons.qr_code_2_rounded,
      iconColor: Color(0xFF0D9488),
      bgTint: Color(0xFFCCFBF1),
      arrowBgTint: Color(0xFFF0FDFA),
      waveColor: Color(0xFF99F6E4),
      route: Routes.operatorAttendanceQrDisplay,
    ),
  ];
  */

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
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OperatorHeader(onLogout: _logout),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final group in _primaryGroups) ...[
                      _SectionHeader(title: group.title),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.08,
                        children: [
                          for (int i = 0; i < group.actions.length; i++)
                            StaggeredSlideFade(
                              index: i,
                              child: _OperatorCard(action: group.actions[i]),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Collapsible More Hostel Services (Complaints, Laundry, Attendance QR)
                    /*
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        leading: Container(
                          width: 20,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        title: const Text(
                          'More Hostel Services (Laundry, Complaints)',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        children: [
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 1.08,
                            children: [
                              for (int i = 0; i < _additionalActions.length; i++)
                                StaggeredSlideFade(
                                  index: i,
                                  child: _OperatorCard(action: _additionalActions[i]),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    */

                    const SizedBox(height: 28),
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
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _BottomNavBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            setState(() => _currentNavIndex = index);
            if (index == 1) {
              Get.toNamed(Routes.operatorDirectory);
            } else if (index == 2) {
              Get.toNamed(Routes.studentScreenTime);
            } else if (index == 3) {
              _showProfileSheet(context);
            }
          },
        ),
      ),
    );
  }
}

/// Deep navy header with luminous curved arcs, calendar pill, building image, and logout button.
class _OperatorHeader extends StatelessWidget {
  final VoidCallback onLogout;

  const _OperatorHeader({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, d MMM yyyy').format(DateTime.now());

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
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
        ),
        child: Stack(
          children: [
            // Glowing decorative arcs and luminous ambient orbs
            Positioned.fill(
              child: CustomPaint(
                painter: _HeaderOrbPainter(),
              ),
            ),

            // Header Content
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top amber dash
                              Container(
                                width: 28,
                                height: 3.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAAB78),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'OPERATOR CONSOLE',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Hostel admin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage students, approvals and finance',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right Logout Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onLogout,
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 46,
                              height: 46,
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
                                size: 21,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Frosted calendar pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

  const _OperatorCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.toNamed(action.route),
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

/// Floating bottom navigation bar matching the design screenshot.
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.people_outline_rounded,
                label: 'Students',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.shield_outlined,
                label: 'Safety',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF0284C7), size: 21),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Icon(icon, color: const Color(0xFF64748B), size: 22),
              ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
