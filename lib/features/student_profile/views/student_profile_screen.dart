import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/models/student_profile/student_profile_model.dart';
import '../../../core/constants/app_routes.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/student_contact_card.dart'
    show CelebrantLightChip, CornerWavePainter;
import '../controllers/student_profile_controller.dart';

class StudentProfileScreen extends GetView<StudentProfileController> {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PhonebookTheme.bg,
        body: Obx(
          () => AsyncStateView(
            isLoading: controller.isLoading.value,
            hasError: controller.hasError.value,
            errorMessage: controller.errorMessage.value,
            onRetry: controller.refreshProfile,
            loadingWidget: const _ProfileSkeleton(),
            builder: (context) {
              final profile = controller.profile.value;
              if (profile == null) return const SizedBox.shrink();
              return RefreshIndicator(
                onRefresh: controller.refreshProfile,
                color: PhonebookTheme.blue,
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    _ProfileHero(profile: profile),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          18,
                          20,
                          28,
                        ),
                        child: _CampusHubSection(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final StudentProfileModel profile;

  const _ProfileHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _DashboardHeaderDelegate(
        profile: profile,
        topPadding: MediaQuery.of(context).padding.top,
      ),
    );
  }
}

class _DashboardHeaderDelegate extends SliverPersistentHeaderDelegate {
  final StudentProfileModel profile;
  final double topPadding;

  _DashboardHeaderDelegate({
    required this.profile,
    required this.topPadding,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';
    return 'Good night';
  }

  bool get _hasPills =>
      profile.room.isNotEmpty ||
      profile.groupName.isNotEmpty ||
      profile.bankCode.isNotEmpty;

  @override
  double get minExtent => topPadding + 62.0;

  @override
  double get maxExtent => topPadding + (_hasPills ? 156.0 : 114.0);

  Widget _roundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final progress = (shrinkOffset / range).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final cornerRadius = Radius.circular((28.0 * (1.0 - progress)).clamp(0.0, 28.0));

    final initial = profile.firstName.isNotEmpty
        ? profile.firstName[0].toUpperCase()
        : '?';
    final fullName = profile.fullName.trim();
    final displayName = fullName.isNotEmpty ? fullName : 'Student Profile';
    final double nameFontSize = fullName.length > 26
        ? 16.5
        : (fullName.length > 18 ? 18.5 : 21.0);

    final pills = <Widget>[
      if (profile.room.isNotEmpty)
        _pill(
          Icons.meeting_room_outlined,
          profile.room.toLowerCase().contains('room')
              ? profile.room
              : 'Room ${profile.room}',
        ),
      if (profile.groupName.isNotEmpty)
        _pill(Icons.groups_outlined, profile.groupName),
      if (profile.bankCode.isNotEmpty)
        _pill(Icons.badge_outlined, 'ID: ${profile.bankCode}'),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: PhonebookTheme.headerGradient,
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
              child: CustomPaint(painter: _DashboardOrbPainter()),
            ),
            // Top bar with avatar, greeting/name, and action buttons
            Positioned(
              top: topPadding + 10,
              left: 18,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: progress > 0.5 ? 38 : 52,
                    height: progress > 0.5 ? 38 : 52,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1.8,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: progress > 0.5 ? 16 : 20,
                          fontWeight: FontWeight.w800,
                          color: PhonebookTheme.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (progress < 0.6)
                          Text(
                            _greeting.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: PhonebookTheme.amberBright,
                              letterSpacing: 1.1,
                            ),
                          ),
                        Text(
                          displayName,
                          maxLines: progress > 0.5 ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: progress > 0.5 ? 16.5 : nameFontSize,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                            height: 1.18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Obx(() {
                    final ctrl = Get.find<StudentProfileController>();
                    final unread = ctrl.unreadAnnouncementsCount.value;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _roundButton(
                          icon: Icons.campaign_rounded,
                          tooltip: 'Announcements',
                          onTap: () => Get.toNamed(
                            Routes.broadcastInbox,
                          )?.then((_) => ctrl.loadHubBadges()),
                        ),
                        if (unread > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 17,
                                minHeight: 17,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unread > 9 ? '9+' : '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(width: 8),
                  _roundButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Settings',
                    onTap: () => Get.toNamed(Routes.setting),
                  ),
                ],
              ),
            ),
            // Bottom frosted identity pills
            if (pills.isNotEmpty && expandedOpacity > 0.05)
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: Row(
                    children: [
                      for (int i = 0; i < pills.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: pills[i]),
                      ],
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

class _DashboardOrbPainter extends CustomPainter {
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

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 20),
            decoration: const BoxDecoration(
              gradient: PhonebookTheme.headerGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonLoader(
                      width: 52,
                      height: 52,
                      borderRadius: BorderRadius.circular(999),
                      baseColor: Colors.white.withValues(alpha: 0.16),
                      highlightColor: Colors.white.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLoader(
                            width: 90,
                            height: 11,
                            baseColor: Colors.white.withValues(alpha: 0.16),
                            highlightColor: Colors.white.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 8),
                          SkeletonLoader(
                            width: 170,
                            height: 20,
                            baseColor: Colors.white.withValues(alpha: 0.18),
                            highlightColor: Colors.white.withValues(alpha: 0.38),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: SkeletonLoader(
                          height: 28,
                          borderRadius: BorderRadius.circular(12),
                          baseColor: Colors.white.withValues(alpha: 0.14),
                          highlightColor: Colors.white.withValues(alpha: 0.32),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Row(
              children: [
                for (int i = 0; i < 2; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  const Expanded(
                    child: SkeletonLoader(
                      height: 140,
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CampusHubSection extends StatelessWidget {
  const _CampusHubSection();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StudentProfileController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            const Text(
              'CAMPUS UPDATES & FEEDBACK',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Announcements Card
            Expanded(
              child: _HubActionCard(
                icon: Icons.campaign_rounded,
                iconColor: const Color(0xFF0284C7),
                iconBg: const Color(0xFFF0F9FF),
                iconBorder: const Color(0xFFBAE6FD),
                waveColor: const Color(0xFFE0F2FE),
                title: 'Announcements',
                subtitle: 'Office notices & news',
                badgeBuilder: () => Obx(() {
                  final unread = controller.unreadAnnouncementsCount.value;
                  return CelebrantLightChip(
                    icon: unread > 0
                        ? Icons.mark_email_unread_rounded
                        : Icons.done_all_rounded,
                    text: unread > 0 ? '$unread New' : 'Up to date',
                    bgColor: unread > 0
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF8FAFC),
                    borderColor: unread > 0
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFE2E8F0),
                    textColor: unread > 0
                        ? const Color(0xFFD97706)
                        : const Color(0xFF64748B),
                  );
                }),
                onTap: () => Get.toNamed(
                  Routes.broadcastInbox,
                )?.then((_) => controller.loadHubBadges()),
              ),
            ),
            const SizedBox(width: 12),
            // Polls & Forms Card
            Expanded(
              child: _HubActionCard(
                icon: Icons.how_to_vote_rounded,
                iconColor: const Color(0xFF0284C7),
                iconBg: const Color(0xFFF0F9FF),
                iconBorder: const Color(0xFFBAE6FD),
                waveColor: const Color(0xFFE0F2FE),
                title: 'Polls & Forms',
                subtitle: 'Hostel decisions & votes',
                badgeBuilder: () => Obx(() {
                  final pending = controller.pendingFormsCount.value;
                  return CelebrantLightChip(
                    icon: pending > 0
                        ? Icons.pending_actions_rounded
                        : Icons.check_circle_outline_rounded,
                    text: pending > 0 ? '$pending to answer' : 'Completed',
                    bgColor: pending > 0
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFECFDF5),
                    borderColor: pending > 0
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFA7F3D0),
                    textColor: pending > 0
                        ? const Color(0xFFD97706)
                        : const Color(0xFF059669),
                  );
                }),
                onTap: () => Get.toNamed(
                  Routes.studentForms,
                )?.then((_) => controller.loadHubBadges()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _HubActionCard(
          icon: Icons.bed_outlined,
          iconColor: const Color(0xFF0284C7),
          iconBg: const Color(0xFFF0F9FF),
          iconBorder: const Color(0xFFBAE6FD),
          waveColor: const Color(0xFFE0F2FE),
          title: 'My Room & Amenities',
          subtitle: 'Room inventory, common spaces & quick issue report',
          badgeBuilder: () => const CelebrantLightChip(
            icon: Icons.inventory_2_outlined,
            text: 'View space',
            bgColor: Color(0xFFF8FAFC),
            borderColor: Color(0xFFE2E8F0),
            textColor: Color(0xFF475569),
          ),
          onTap: () => Get.toNamed(Routes.studentMySpace),
        ),
        Obx(() {
          if (!controller.isLeader.value) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'GROUP LEADER TOOLS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF475569),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Birthday Wishes Card
                  Expanded(
                    child: _HubActionCard(
                      icon: Icons.cake_rounded,
                      iconColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                      iconBorder: const Color(0xFFFDE68A),
                      waveColor: const Color(0xFFFEF9C3),
                      title: 'Birthday Wishes',
                      subtitle: 'Wish group celebrants via WhatsApp',
                      badgeBuilder: () => const CelebrantLightChip(
                        icon: Icons.star_rounded,
                        text: 'Leader Access',
                        bgColor: Color(0xFFFEF3C7),
                        borderColor: Color(0xFFFDE68A),
                        textColor: Color(0xFFD97706),
                      ),
                      onTap: () => Get.toNamed(Routes.operatorBirthdayWishes),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Daily Alumni Connect Card
                  Expanded(
                    child: _HubActionCard(
                      icon: Icons.connect_without_contact_rounded,
                      iconColor: const Color(0xFF0D9488),
                      iconBg: const Color(0xFFCCFBF1),
                      iconBorder: const Color(0xFF99F6E4),
                      waveColor: const Color(0xFFE6FFFA),
                      title: 'Daily Alumni Connect',
                      subtitle: 'Connect with 5 alumni of your group daily',
                      badgeBuilder: () => const CelebrantLightChip(
                        icon: Icons.groups_rounded,
                        text: '5 Daily',
                        bgColor: Color(0xFFCCFBF1),
                        borderColor: Color(0xFF99F6E4),
                        textColor: Color(0xFF0F766E),
                      ),
                      onTap: () => Get.toNamed(Routes.dailyAlumniOutreach),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Parental Controls & Lock Card
                  Expanded(
                    child: _HubActionCard(
                      icon: Icons.lock_clock_rounded,
                      iconColor: const Color(0xFF6366F1),
                      iconBg: const Color(0xFFEEF2FF),
                      iconBorder: const Color(0xFFC7D2FE),
                      waveColor: const Color(0xFFF5F3FF),
                      title: 'Parental Controls & Lock',
                      subtitle: 'Remotely lock devices & manage screen time',
                      badgeBuilder: () => const CelebrantLightChip(
                        icon: Icons.security_rounded,
                        text: 'Leader Access',
                        bgColor: Color(0xFFEEF2FF),
                        borderColor: Color(0xFFC7D2FE),
                        textColor: Color(0xFF4F46E5),
                      ),
                      onTap: () => Get.toNamed(Routes.studentScreenTime),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _HubActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color iconBorder;
  final Color waveColor;
  final String title;
  final String subtitle;
  final Widget Function() badgeBuilder;
  final VoidCallback onTap;

  const _HubActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.iconBorder,
    required this.waveColor,
    required this.title,
    required this.subtitle,
    required this.badgeBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(80, 55),
                  painter: CornerWavePainter(
                    color: waveColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: iconBorder, width: 1),
                          ),
                          alignment: Alignment.center,
                          child: Icon(icon, color: iconColor, size: 21),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    badgeBuilder(),
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
