import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/utils/student_photo.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/models/anniversary/anniversary_models.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/student_avatar.dart';
import '../../shared/widgets/student_contact_card.dart';
import '../controllers/admin_anniversary_controller.dart';

/// Modern, executive view of Hostel Parents' Marriage Anniversary Greetings & Automation,
/// styled with the signature deep navy header, sky-blue accents, amber section dashes,
/// and slate card styling from the Phonebook, Birthday Wishes, Geofence, and Student Locations screens.
class AdminAnniversaryScreen extends GetView<AdminAnniversaryController> {
  const AdminAnniversaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Obx(() {
          final data = controller.dashboard.value;
          final isLoading = controller.isLoading.value;
          final error = controller.error.value;

          if (isLoading && data == null) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE11D48)),
            );
          }

          if (error.isNotEmpty && data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 44,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: controller.loadDashboard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFFE11D48),
            backgroundColor: Colors.white,
            onRefresh: () async {
              await controller.loadDashboard();
              if (controller.selectedTab.value == 3) {
                await controller.loadAllStudents();
              } else if (controller.selectedTab.value == 4) {
                await controller.loadLogs();
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _AdminAnniversaryHeaderDelegate(
                    controller: controller,
                    topPadding: topPadding,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tab Category Pills Bar
                        _buildTabPillBar(),
                        const SizedBox(height: 18),

                        // Active Tab Content
                        _buildActiveTabContent(context, data),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ============================================================
  // TAB PILLS BAR
  // ============================================================

  Widget _buildTabPillBar() {
    return Obx(() {
      final current = controller.selectedTab.value;
      final todayCount = controller.dashboard.value?.todaysAnniversaries.length ?? 0;
      final tomorrowCount = controller.dashboard.value?.tomorrowsAnniversaries.length ?? 0;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildTabPill(
              index: 0,
              label: 'Today',
              count: todayCount,
              icon: Icons.volunteer_activism_rounded,
              isSelected: current == 0,
              activeColor: const Color(0xFFE11D48),
            ),
            const SizedBox(width: 8),
            _buildTabPill(
              index: 1,
              label: 'Tomorrow',
              count: tomorrowCount,
              icon: Icons.event_rounded,
              isSelected: current == 1,
              activeColor: const Color(0xFF059669),
            ),
            const SizedBox(width: 8),
            _buildTabPill(
              index: 2,
              label: 'Template & Settings',
              icon: Icons.tune_rounded,
              isSelected: current == 2,
              activeColor: const Color(0xFFD97706),
            ),
            const SizedBox(width: 8),
            _buildTabPill(
              index: 3,
              label: 'Directory',
              icon: Icons.people_alt_rounded,
              isSelected: current == 3,
              activeColor: const Color(0xFF0284C7),
            ),
            const SizedBox(width: 8),
            _buildTabPill(
              index: 4,
              label: 'History Logs',
              icon: Icons.history_rounded,
              isSelected: current == 4,
              activeColor: const Color(0xFF7C3AED),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTabPill({
    required int index,
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    int? count,
  }) {
    return InkWell(
      onTap: () {
        controller.selectedTab.value = index;
        if (index == 3 && controller.allStudents.isEmpty) {
          controller.loadAllStudents();
        } else if (index == 4 && controller.logs.isEmpty) {
          controller.loadLogs();
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ACTIVE TAB SWITCHER
  // ============================================================

  Widget _buildActiveTabContent(BuildContext context, AnniversaryDashboardData? data) {
    final tab = controller.selectedTab.value;
    switch (tab) {
      case 0:
        return _buildTodayTab(context, data?.todaysAnniversaries ?? []);
      case 1:
        return _buildTomorrowTab(context, data?.tomorrowsAnniversaries ?? []);
      case 2:
        return _buildTemplateStudioTab(context, data);
      case 3:
        return _buildDirectoryTab(context);
      case 4:
        return _buildLogsTab(context);
      default:
        return const SizedBox();
    }
  }

  // ============================================================
  // TAB 0: TODAY'S CELEBRANTS
  // ============================================================

  Widget _buildTodayTab(BuildContext context, List<AnniversaryStudentRecord> records) {
    if (records.isEmpty) {
      return _buildEmptyCelebrantsState(
        title: 'No Anniversaries Today',
        subtitle: "None of our students' parents have marriage anniversaries today.",
        icon: Icons.volunteer_activism_rounded,
        color: const Color(0xFFE11D48),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFECDD3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE11D48),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${records.length} Families Celebrating Today",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF881337),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Wish both Father & Mother together or individually',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF9F1239),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _confirmSendAllDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send_rounded, size: 15),
                label: const Text(
                  'Send All',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // List of Family Cards
        ...records.map((r) => _buildFamilyCelebrantCard(context, r, isToday: true)),
      ],
    );
  }

  // ============================================================
  // TAB 1: TOMORROW'S CELEBRANTS
  // ============================================================

  Widget _buildTomorrowTab(BuildContext context, List<AnniversaryStudentRecord> records) {
    if (records.isEmpty) {
      return _buildEmptyCelebrantsState(
        title: 'No Anniversaries Tomorrow',
        subtitle: "No student parents have marriage anniversaries scheduled for tomorrow.",
        icon: Icons.event_available_rounded,
        color: const Color(0xFF059669),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF059669),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_note_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${records.length} Families Celebrating Tomorrow",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Preview upcoming celebrations or send advance greetings',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...records.map((r) => _buildFamilyCelebrantCard(context, r, isToday: false)),
      ],
    );
  }

  // ============================================================
  // FAMILY CELEBRANT CARD (PHONEBOOK / BIRTHDAY STYLED)
  // ============================================================

  Widget _buildFamilyCelebrantCard(
    BuildContext context,
    AnniversaryStudentRecord record, {
    required bool isToday,
  }) {
    final isAlumni = record.isAlumni;
    final group = record.groupName;
    final isSent = record.alreadySentToday;

    final Color accentColor = isToday
        ? (isSent ? const Color(0xFF059669) : const Color(0xFFE11D48))
        : const Color(0xFF0284C7);

    final Color avatarBgColor = isAlumni
        ? const Color(0xFFF3E8FF)
        : (group != null
            ? StudentContactCard.groupColor(group).withValues(alpha: 0.12)
            : const Color(0xFFFFF1F2));

    final Color avatarTextColor = isAlumni
        ? const Color(0xFF9333EA)
        : (group != null
            ? StudentContactCard.groupColor(group)
            : const Color(0xFFE11D48));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSent ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Card Top Row: Avatar, Names, Milestone & Status Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudentAvatar(
                  name: record.name,
                  bankCode: record.studentCode,
                  size: 40,
                  background: avatarBgColor,
                  child: Text(
                    record.name.isNotEmpty ? record.name[0].toUpperCase() : '💍',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: avatarTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              record.parentsNames,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('💍', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Student: ${record.name} • Room ${record.room}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isToday ? (isSent ? 'Sent ✓' : 'Pending') : 'Upcoming',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4.5,
            children: [
              // Group / Alumni Chip
              _buildCelebrantLightChip(
                icon: isAlumni ? Icons.school_rounded : Icons.groups_rounded,
                text: isAlumni ? 'Alumni' : (group ?? 'Active'),
                bgColor: isAlumni ? const Color(0xFFF3E8FF) : StudentContactCard.groupBgColor(group),
                borderColor: isAlumni
                    ? const Color(0xFFE9D5FF)
                    : StudentContactCard.groupColor(group).withValues(alpha: 0.25),
                textColor: isAlumni ? const Color(0xFF9333EA) : StudentContactCard.groupColor(group),
              ),
              // Milestone Chip
              _buildCelebrantLightChip(
                icon: Icons.volunteer_activism_rounded,
                text: record.yearsMilestoneLabel,
                bgColor: const Color(0xFFFFF1F2),
                borderColor: const Color(0xFFFECDD3),
                textColor: const Color(0xFFE11D48),
              ),
              // Anniversary Date Chip
              if (record.anniversaryDate.isNotEmpty)
                _buildCelebrantLightChip(
                  icon: Icons.event_rounded,
                  text: record.anniversaryDate,
                  bgColor: const Color(0xFFF0F9FF),
                  borderColor: const Color(0xFFBAE6FD),
                  textColor: const Color(0xFF0284C7),
                ),
            ],
          ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 2. Parents Phone Grid: Father & Mother sub-cards
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FATHER SUB-CARD
                    Expanded(
                      child: _buildParentSubCard(
                        context: context,
                        record: record,
                        title: 'Father',
                        name: record.fatherName.isNotEmpty ? record.fatherName : 'Father',
                        phone: record.fatherPhone,
                        icon: Icons.person_rounded,
                        accentColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFF0F9FF),
                        recipientType: 'father',
                      ),
                    ),
                    const SizedBox(width: 10),
                    // MOTHER SUB-CARD
                    Expanded(
                      child: _buildParentSubCard(
                        context: context,
                        record: record,
                        title: 'Mother',
                        name: record.motherName.isNotEmpty ? record.motherName : 'Mother',
                        phone: record.motherPhone,
                        icon: Icons.face_3_rounded,
                        accentColor: const Color(0xFFD946EF),
                        bgColor: const Color(0xFFFDF4FF),
                        recipientType: 'mother',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Primary Actions: Wish Both Parents + Wish Another No.
                // Same width and height; labels shrink to fit narrow phones.
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: record.hasAnyPhone ? () => controller.wishBoth(record) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE11D48),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.favorite_rounded, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Wish Both Parents 🎉',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => _showWishWithAnotherNumberSheet(context, record),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.phone_iphone_rounded, size: 16, color: Color(0xFF059669)),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Another No.',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Parent Sub-Card ---

  Widget _buildParentSubCard({
    required BuildContext context,
    required AnniversaryStudentRecord record,
    required String title,
    required String name,
    required String phone,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required String recipientType,
  }) {
    final photoOf = recipientType == 'mother' ? PhotoOf.mother : PhotoOf.father;
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final hasPhone = clean.length >= 6;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The parent's photo (named after the student's Aadhar), else the icon.
              StudentAvatar(
                name: name,
                bankCode: record.studentCode,
                photoOf: photoOf,
                size: 34,
                background: accentColor.withValues(alpha: 0.14),
                child: Icon(icon, size: 17, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            hasPhone ? phone : 'No phone listed',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: hasPhone ? const Color(0xFF475569) : const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Actions: Call and WhatsApp (opens this phone's WhatsApp with the wish)
          Row(
            children: [
              Expanded(
                child: _ParentActionIcon(
                  tooltip: 'Call',
                  icon: Icon(Icons.call_rounded, size: 18, color: hasPhone ? accentColor : const Color(0xFF94A3B8)),
                  background: hasPhone ? accentColor.withValues(alpha: 0.14) : const Color(0xFFE2E8F0),
                  onTap: hasPhone ? () => controller.callPhone(phone) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ParentActionIcon(
                  tooltip: 'WhatsApp',
                  icon: FaIcon(
                    FontAwesomeIcons.whatsapp,
                    size: 18,
                    color: hasPhone ? Colors.white : const Color(0xFF94A3B8),
                  ),
                  background: hasPhone ? const Color(0xFF25D366) : const Color(0xFFE2E8F0),
                  onTap: hasPhone
                      ? () => controller.wishViaDeviceWhatsApp(
                            phone: phone,
                            record: record,
                            recipientType: recipientType,
                          )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 3: ANNIVERSARY DIRECTORY (PHONEBOOK STYLED)
  // ============================================================

  Widget _buildDirectoryTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Title & Overline
        _buildSectionHeader(
          title: controller.isLeader.value
              ? '${controller.leaderGroup.value ?? "Group"} Anniversary Directory'
              : 'Hostel Parents Anniversary Directory',
        ),
        const SizedBox(height: 12),

        // Search Bar & Filter Button styled exactly like PhonebookScreen & BirthdayScreen
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: controller.searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (query) => controller.loadAllStudents(query: query),
                  decoration: InputDecoration(
                    hintText: 'Search by student, parent, room, phone...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                      onPressed: () {
                        controller.searchController.clear();
                        controller.loadAllStudents();
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Filter Button with Badge
            Obx(() {
              final count = controller.activeFilterCount;
              return Material(
                color: count > 0 ? const Color(0xFF0284C7) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: count > 0 ? 3 : 1,
                shadowColor: count > 0 ? const Color(0xFF0284C7).withValues(alpha: 0.3) : Colors.black12,
                child: InkWell(
                  key: const ValueKey('anniversary_directory_filter_button'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showFilterBottomSheet(context),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: count > 0 ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: count > 0 ? Colors.white : const Color(0xFF0284C7),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Color(0xFF0284C7),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),

        // Filter chips bar
        Obx(() {
          final list = controller.allStudents;
          final hostelCount = list.where((s) => !s.isAlumni).length;
          final alumniCount = list.where((s) => s.isAlumni).length;
          final withDateCount = list.where((s) => s.anniversaryDate.trim().isNotEmpty).length;
          final withoutDateCount = list.length - withDateCount;
          final currentFilter = controller.directoryFilter.value;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildDirectoryFilterChip(
                  label: 'All (${list.length})',
                  isSelected: currentFilter == 'all',
                  onTap: () => controller.directoryFilter.value = 'all',
                  activeColor: const Color(0xFF0284C7),
                ),
                const SizedBox(width: 8),
                _buildDirectoryFilterChip(
                  label: 'Hostel Residents ($hostelCount)',
                  icon: Icons.home_rounded,
                  isSelected: currentFilter == 'hostel',
                  onTap: () => controller.directoryFilter.value = 'hostel',
                  activeColor: const Color(0xFF0284C7),
                ),
                const SizedBox(width: 8),
                _buildDirectoryFilterChip(
                  label: 'With Anniversary ($withDateCount)',
                  icon: Icons.volunteer_activism_rounded,
                  isSelected: currentFilter == 'has_date',
                  onTap: () => controller.directoryFilter.value = 'has_date',
                  activeColor: const Color(0xFFE11D48),
                ),
                const SizedBox(width: 8),
                _buildDirectoryFilterChip(
                  label: 'Without Date ($withoutDateCount)',
                  icon: Icons.event_busy_rounded,
                  isSelected: currentFilter == 'no_date',
                  onTap: () => controller.directoryFilter.value = 'no_date',
                  activeColor: const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                _buildDirectoryFilterChip(
                  label: 'Alumni ($alumniCount)',
                  icon: Icons.school_rounded,
                  isSelected: currentFilter == 'alumni',
                  onTap: () => controller.directoryFilter.value = 'alumni',
                  activeColor: const Color(0xFF9333EA),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),

        // Directory Students / Families List
        Obx(() {
          if (controller.isLoadingStudents.value) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF0284C7)),
              ),
            );
          }

          final list = controller.filteredStudents;
          if (list.isEmpty) {
            return _buildEmptyCelebrantsState(
              title: 'No Matching Records Found',
              subtitle: controller.activeFilterCount > 0
                  ? 'No families match your active filters. Try clearing or relaxing the filters.'
                  : 'Tap Search or refresh to load parent anniversary directory records.',
              icon: Icons.person_search_rounded,
              color: const Color(0xFF0284C7),
            );
          }

          final currentFilter = controller.directoryFilter.value;
          final hostelStudents = list.where((s) => !s.isAlumni).toList();
          final alumniStudents = list.where((s) => s.isAlumni).toList();

          if (currentFilter == 'hostel') {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(
                  title: 'Hostel Residents (${hostelStudents.length})',
                  trailing: _buildHeaderTag('ACTIVE RESIDENTS', const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
                ),
                const SizedBox(height: 10),
                ...hostelStudents.map((s) => _buildDirectoryStudentCard(context, s)),
              ],
            );
          }

          if (currentFilter == 'alumni') {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(
                  title: 'Alumni Students (${alumniStudents.length})',
                  trailing: _buildHeaderTag('ALUMNI', const Color(0xFFF3E8FF), const Color(0xFF9333EA)),
                ),
                const SizedBox(height: 10),
                ...alumniStudents.map((s) => _buildDirectoryStudentCard(context, s)),
              ],
            );
          }

          // Default: Hostel Residents FIRST, then Alumni Students AFTERWARDS!
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hostelStudents.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'Hostel Residents (${hostelStudents.length})',
                  trailing: _buildHeaderTag('ACTIVE RESIDENTS FIRST', const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
                ),
                const SizedBox(height: 10),
                ...hostelStudents.map((s) => _buildDirectoryStudentCard(context, s)),
              ],
              if (alumniStudents.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionHeader(
                  title: 'Alumni Students (${alumniStudents.length})',
                  trailing: _buildHeaderTag('ALUMNI', const Color(0xFFF3E8FF), const Color(0xFF9333EA)),
                ),
                const SizedBox(height: 10),
                ...alumniStudents.map((s) => _buildDirectoryStudentCard(context, s)),
              ],
            ],
          );
        }),
      ],
    );
  }

  // --- Directory Student Card (Phonebook card styled) ---

  Widget _buildDirectoryStudentCard(BuildContext context, AnniversaryStudentRecord s) {
    final isAlumni = s.isAlumni;
    final group = s.groupName;

    final Color avatarBgColor = isAlumni
        ? const Color(0xFFF3E8FF)
        : (group != null
            ? StudentContactCard.groupColor(group).withValues(alpha: 0.12)
            : const Color(0xFFFFF1F2));

    final Color avatarTextColor = isAlumni
        ? const Color(0xFF9333EA)
        : (group != null
            ? StudentContactCard.groupColor(group)
            : const Color(0xFFE11D48));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlumni ? const Color(0xFFE9D5FF) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          StudentAvatar(
            name: s.name,
            bankCode: s.studentCode,
            size: 38,
            background: avatarBgColor,
            child: Text(
              s.name.isNotEmpty ? s.name[0].toUpperCase() : '💍',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: avatarTextColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        s.parentsNames,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('💍', style: TextStyle(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Student: ${s.name}",
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Status Tag
                    _buildCelebrantLightChip(
                      icon: isAlumni ? Icons.school_rounded : Icons.groups_rounded,
                      text: isAlumni ? 'Alumni' : (group ?? 'Active'),
                      bgColor: isAlumni ? const Color(0xFFF3E8FF) : StudentContactCard.groupBgColor(group),
                      borderColor: isAlumni
                          ? const Color(0xFFE9D5FF)
                          : StudentContactCard.groupColor(group).withValues(alpha: 0.25),
                      textColor: isAlumni ? const Color(0xFF9333EA) : StudentContactCard.groupColor(group),
                    ),
                    // Room Tag
                    if (s.room != 'N/A' && !isAlumni)
                      _buildTag(
                        icon: Icons.meeting_room_rounded,
                        text: 'Room ${s.room}',
                      ),
                    // Code Tag
                    if (s.studentCode.isNotEmpty)
                      _buildTag(
                        icon: Icons.badge_outlined,
                        text: s.studentCode,
                      ),
                    // Anniversary Date Tag
                    if (s.anniversaryDate.isNotEmpty)
                      _buildTag(
                        icon: Icons.volunteer_activism_rounded,
                        text: s.anniversaryDate,
                        color: const Color(0xFFE11D48),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Call & WhatsApp quick actions
          if (s.hasFatherPhone || s.hasMotherPhone)
            IconButton(
              icon: const Icon(
                Icons.phone_rounded,
                size: 18,
                color: Color(0xFF0284C7),
              ),
              tooltip: 'Call Parents',
              onPressed: () {
                if (s.hasFatherPhone && s.hasMotherPhone) {
                  _showParentPhonePickerSheet(context, s, isCall: true);
                } else if (s.hasFatherPhone) {
                  controller.callPhone(s.fatherPhone);
                } else if (s.hasMotherPhone) {
                  controller.callPhone(s.motherPhone);
                }
              },
            ),
          if (s.hasFatherPhone || s.hasMotherPhone)
            IconButton(
              icon: const Icon(
                Icons.chat_rounded,
                size: 18,
                color: Color(0xFF059669),
              ),
              tooltip: 'Send Anniversary Greeting',
              onPressed: () => _showParentPhonePickerSheet(context, s, isCall: false),
            ),
        ],
      ),
    );
  }

  // --- Parent Phone Picker Sheet ---

  void _showParentPhonePickerSheet(
    BuildContext context,
    AnniversaryStudentRecord record, {
    required bool isCall,
  }) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isCall ? Icons.phone_rounded : Icons.chat_rounded,
                  color: isCall ? const Color(0xFF0284C7) : const Color(0xFF059669),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isCall ? "Call Parents" : "Wish ${record.parentsNames}",
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (record.hasFatherPhone) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                ),
                tileColor: const Color(0xFFF0F9FF),
                leading: StudentAvatar(
                  name: record.fatherName,
                  bankCode: record.studentCode,
                  photoOf: PhotoOf.father,
                  size: 38,
                  background: const Color(0xFFE0F2FE),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF0284C7), size: 20),
                ),
                title: Text(
                  record.fatherName.isNotEmpty ? record.fatherName : 'Father',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: Text(record.fatherPhone, style: const TextStyle(fontSize: 12)),
                trailing: Icon(isCall ? Icons.call_rounded : Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Get.back();
                  if (isCall) {
                    controller.callPhone(record.fatherPhone);
                  } else {
                    controller.wishViaDeviceWhatsApp(
                      phone: record.fatherPhone,
                      record: record,
                      recipientType: 'father',
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
            if (record.hasMotherPhone) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFF5D0FE)),
                ),
                tileColor: const Color(0xFFFDF4FF),
                leading: StudentAvatar(
                  name: record.motherName,
                  bankCode: record.studentCode,
                  photoOf: PhotoOf.mother,
                  size: 38,
                  background: const Color(0xFFFAE8FF),
                  child: const Icon(Icons.face_3_rounded, color: Color(0xFFD946EF), size: 20),
                ),
                title: Text(
                  record.motherName.isNotEmpty ? record.motherName : 'Mother',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: Text(record.motherPhone, style: const TextStyle(fontSize: 12)),
                trailing: Icon(isCall ? Icons.call_rounded : Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Get.back();
                  if (isCall) {
                    controller.callPhone(record.motherPhone);
                  } else {
                    controller.wishViaDeviceWhatsApp(
                      phone: record.motherPhone,
                      record: record,
                      recipientType: 'mother',
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
            if (!isCall) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Get.back();
                  controller.wishBoth(record);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.favorite_rounded, size: 16),
                label: const Text('Wish Both via Server Bot', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILTER BOTTOM SHEET (MATCHES PHONEBOOK & BIRTHDAY)
  // ============================================================

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0,
        maxChildSize: 0.85,
        snap: true,
        snapSizes: const [0.85],
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // Drag Handle & Top Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                            child: Column(
                              children: [
                                Center(
                                  child: Container(
                                    width: 44,
                                    height: 4.5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCBD5E1),
                                      borderRadius: BorderRadius.circular(2.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.tune_rounded, color: Color(0xFF0284C7), size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Filter & Sort Parents',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            'Refine by wings, floors, residence, and anniversary info',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Obx(() {
                                      if (controller.activeFilterCount == 0) return const SizedBox.shrink();
                                      return TextButton(
                                        onPressed: () {
                                          controller.resetAllFilters();
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        ),
                                        child: const Text(
                                          'Reset All',
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                      );
                                    }),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                                      tooltip: 'Close',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ],
                      ),
                    ),

                    // Scrollable Content
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      sliver: SliverToBoxAdapter(
                        child: Obx(() {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. HOSTEL WING / GROUP
                              if (!controller.isLeader.value) ...[
                                _filterSectionHeader('HOSTEL WING / GROUP', Icons.apartment_rounded),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: AdminAnniversaryController.hshGroups.map((g) {
                                    final sel = controller.selectedGroup.value == g;
                                    final isAlumni = g.toLowerCase() == 'alumni';
                                    final color = isAlumni ? const Color(0xFF9333EA) : const Color(0xFF0284C7);
                                    return FilterChip(
                                      label: Text(g),
                                      selected: sel,
                                      selectedColor: color,
                                      checkmarkColor: Colors.white,
                                      labelStyle: TextStyle(
                                        color: sel ? Colors.white : const Color(0xFF334155),
                                        fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: sel ? color : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      onSelected: (v) => controller.selectGroup(g),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 20),
                              ] else ...[
                                _filterSectionHeader('ASSIGNED LEADER GROUP', Icons.shield_rounded),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFBAE6FD)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF0284C7), size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${controller.leaderGroup.value ?? "Your"} Group (Exclusive)',
                                        style: const TextStyle(
                                          color: Color(0xFF0284C7),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // 2. FLOOR SELECTOR
                              _filterSectionHeader('HOSTEL FLOOR', Icons.layers_rounded),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: AdminAnniversaryController.floorOptions.map((f) {
                                  final sel = controller.selectedFloor.value == f;
                                  return FilterChip(
                                    label: Text(f),
                                    selected: sel,
                                    selectedColor: const Color(0xFF0284C7),
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: sel ? Colors.white : const Color(0xFF334155),
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: sel ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    onSelected: (v) => controller.selectFloor(f),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              // 3. RESIDENCE STATUS
                              _filterSectionHeader('RESIDENCE STATUS', Icons.badge_rounded),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: AdminAnniversaryController.statusOptions.map((s) {
                                  final sel = controller.selectedStatus.value == s;
                                  return FilterChip(
                                    label: Text(s),
                                    selected: sel,
                                    selectedColor: const Color(0xFF059669),
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: sel ? Colors.white : const Color(0xFF334155),
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: sel ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    onSelected: (v) => controller.selectStatus(s),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              // 4. ANNIVERSARY & CONTACT ATTRIBUTES
                              _filterSectionHeader('ANNIVERSARY & CONTACT ATTRIBUTES', Icons.volunteer_activism_rounded),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    _toggleRow(
                                      icon: Icons.volunteer_activism_rounded,
                                      iconColor: const Color(0xFFE11D48),
                                      title: 'Has Anniversary Date',
                                      subtitle: 'Show students with parents anniversary date registered',
                                      value: controller.onlyWithAnniversaryDate.value,
                                      onChanged: controller.toggleOnlyWithAnniversaryDate,
                                    ),
                                    const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                                    _toggleRow(
                                      icon: Icons.event_busy_rounded,
                                      iconColor: const Color(0xFF64748B),
                                      title: 'Missing Anniversary Date',
                                      subtitle: 'Show records needing anniversary date entry',
                                      value: controller.onlyWithoutAnniversaryDate.value,
                                      onChanged: controller.toggleOnlyWithoutAnniversaryDate,
                                    ),
                                    const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                                    _toggleRow(
                                      icon: Icons.person_rounded,
                                      iconColor: const Color(0xFF0284C7),
                                      title: 'Has Father Phone',
                                      subtitle: "Show records with Father's contact number",
                                      value: controller.onlyWithFatherPhone.value,
                                      onChanged: controller.toggleOnlyWithFatherPhone,
                                    ),
                                    const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                                    _toggleRow(
                                      icon: Icons.face_3_rounded,
                                      iconColor: const Color(0xFFD946EF),
                                      title: 'Has Mother Phone',
                                      subtitle: "Show records with Mother's contact number",
                                      value: controller.onlyWithMotherPhone.value,
                                      onChanged: controller.toggleOnlyWithMotherPhone,
                                    ),
                                    const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                                    _toggleRow(
                                      icon: Icons.family_restroom_rounded,
                                      iconColor: const Color(0xFF059669),
                                      title: 'Has Both Parents Phones',
                                      subtitle: 'Show records with both Father and Mother numbers',
                                      value: controller.onlyWithBothPhones.value,
                                      onChanged: controller.toggleOnlyWithBothPhones,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 5. SORT ORDER
                              _filterSectionHeader('SORT CELEBRANTS BY', Icons.sort_by_alpha_rounded),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: AdminAnniversaryController.sortOptions.map((s) {
                                  final sel = controller.selectedSort.value == s;
                                  return ChoiceChip(
                                    label: Text(s),
                                    selected: sel,
                                    selectedColor: const Color(0xFF0F172A),
                                    labelStyle: TextStyle(
                                      color: sel ? Colors.white : const Color(0xFF334155),
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: sel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    onSelected: (v) => controller.selectSort(s),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Sticky Action Button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Obx(() {
                        final count = controller.filteredStudents.length;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Apply Filters & Show ($count Parents)',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ],
                        );
                      }),
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

  Widget _filterSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0284C7)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF475569),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeTrackColor: const Color(0xFF0284C7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      secondary: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  // ============================================================
  // TAB 2: TEMPLATE STUDIO & CUSTOM WISHING DESK
  // ============================================================

  Widget _buildTemplateStudioTab(BuildContext context, AnniversaryDashboardData? data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Template Editor Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFFE11D48), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anniversary Greeting Template',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Automated message sent to parents on their anniversary',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Variable Chips
              const Text(
                'Available Variables (tap to insert):',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildVariableChip('{parents_names}'),
                  _buildVariableChip('{father_name}'),
                  _buildVariableChip('{mother_name}'),
                  _buildVariableChip('{student_name}'),
                  _buildVariableChip('{years}'),
                  _buildVariableChip('{room}'),
                  _buildVariableChip('{father_first_name}'),
                  _buildVariableChip('{father_middle_name}'),
                  _buildVariableChip('{father_last_name}'),
                  _buildVariableChip('{mother_first_name}'),
                  _buildVariableChip('{mother_middle_name}'),
                  _buildVariableChip('{mother_last_name}'),
                ],
              ),
              const SizedBox(height: 12),

              // Template TextField
              TextField(
                controller: controller.templateController,
                focusNode: controller.templateFocus,
                maxLines: 4,
                style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: 'Enter anniversary message template...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Live preview, filled with a real celebrant (or a sample)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller.templateController,
                builder: (context, value, _) {
                  final record = controller.previewRecord;
                  final text = value.text.trim();
                  final rendered = text.isEmpty
                      ? 'Your message preview will appear here.'
                      : controller.formatMessage(text, record, 'father');
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message preview · ${record.name}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rendered,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: text.isEmpty ? const Color(0xFF64748B) : const Color(0xFF064E3B),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Settings Row: Enable Toggle & Send Time
              Row(
                children: [
                  Expanded(
                    child: Obx(() => SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Enable Automation',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Auto-dispatch on scheduled time',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          value: controller.isAnniversaryEnabled.value,
                          activeTrackColor: const Color(0xFFE11D48),
                          onChanged: (val) => controller.isAnniversaryEnabled.value = val,
                        )),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: controller.sendTimeController,
                      decoration: InputDecoration(
                        labelText: 'Time',
                        hintText: '08:30',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Save Button
              Obx(() => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: controller.isSaving.value ? null : controller.saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: controller.isSaving.value
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Configuration',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. WISH VIA ANOTHER WHATSAPP NUMBER
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.send_to_mobile_rounded, color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wish via Another WhatsApp Number',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        Text(
                          'Send greeting to any custom number directly from device WhatsApp or Bot',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextField(
                controller: controller.customWishPhoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Parent WhatsApp Phone Number',
                  hintText: 'e.g. 98250 12345',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF059669)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: controller.customWishMessageController,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Custom Wish Message (Optional)',
                  hintText: 'Leave empty to use active template...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final phone = controller.customWishPhoneController.text.trim();
                        if (phone.isEmpty) {
                          AppSnackbar.warning('Enter Phone', 'Please enter a target phone number.');
                          return;
                        }
                        final customMsg = controller.customWishMessageController.text.trim().isNotEmpty
                            ? controller.customWishMessageController.text.trim()
                            : controller.templateController.text.trim();
                        controller.openWhatsAppDirect(phone, customText: customMsg);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text(
                        'Open in WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final phone = controller.customWishPhoneController.text.trim();
                        if (phone.isEmpty) {
                          AppSnackbar.warning('Enter Phone', 'Please enter a target phone number.');
                          return;
                        }
                        controller.sendTestWish(phone);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF065F46),
                        side: const BorderSide(color: Color(0xFF059669), width: 1.3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.smart_toy_outlined, size: 16),
                      label: const Text(
                        'Send via Bot',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVariableChip(String tag) {
    return InkWell(
      onTap: () => controller.insertTemplateVariable(tag),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: Text(
          tag,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE11D48),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TAB 4: HISTORY & LOGS
  // ============================================================

  Widget _buildLogsTab(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingLogs.value) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
          ),
        );
      }

      final logs = controller.logs;
      if (logs.isEmpty) {
        return _buildEmptyCelebrantsState(
          title: 'No Delivery Logs Yet',
          subtitle: 'Sent anniversary wishes and delivery statuses will appear here.',
          icon: Icons.history_rounded,
          color: const Color(0xFF7C3AED),
        );
      }

      return Column(
        children: logs.map((log) {
          final isSent = log.status.toLowerCase() == 'sent';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: log.recipientType.toLowerCase().contains('father')
                            ? const Color(0xFFF0F9FF)
                            : const Color(0xFFFDF4FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        log.recipientType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: log.recipientType.toLowerCase().contains('father')
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFD946EF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${log.studentName} (Room ${log.room})",
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSent ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        log.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSent ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Phone: ${log.phone} • Date: ${log.wishDate}",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    log.message,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.3),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  // ============================================================
  // COMMON HELPER WIDGETS
  // ============================================================

  Widget _buildCelebrantLightChip({
    required IconData icon,
    required String text,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    final effectiveColor = color ?? const Color(0xFF475569);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: effectiveColor),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
              letterSpacing: -0.2,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildDirectoryFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFCBD5E1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : activeColor,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCelebrantsState({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
          ),
        ],
      ),
    );
  }

  // --- Confirmation & Custom Number Dialogs ---

  void _confirmSendAllDialog(BuildContext context) {
    final count = controller.dashboard.value?.todaysAnniversaries.length ?? 0;
    const rose = Color(0xFFE11D48);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: rose.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism_rounded, color: rose, size: 28),
              ),
              const SizedBox(height: 14),
              const Text(
                'Send all wishes?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                count > 0
                    ? 'Anniversary greetings will be sent on WhatsApp to the parents of '
                        '$count ${count == 1 ? 'student' : 'students'} celebrating today.'
                    : 'Anniversary greetings will be sent on WhatsApp to all parents celebrating today.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          controller.sendAllWishesToday();
                        },
                        icon: const Icon(Icons.send_rounded, size: 17),
                        label: const Text('Send now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rose,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWishWithAnotherNumberSheet(BuildContext context, AnniversaryStudentRecord record) {
    final customPhoneCtrl = TextEditingController();
    String recipientChoice = 'both';

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_iphone_rounded, color: Color(0xFF059669), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "Wish ${record.parentsNames}",
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter an alternate WhatsApp number for this family or wish directly from your own phone.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: customPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Alternate WhatsApp Number',
                  hintText: 'e.g. 98250 12345',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final phone = customPhoneCtrl.text.trim();
                        if (phone.isEmpty) {
                          AppSnackbar.warning('Enter Phone', 'Please enter a target number.');
                          return;
                        }
                        Get.back();
                        controller.wishCustomNumber(
                          record: record,
                          phone: phone,
                          recipientType: recipientChoice,
                          viaBot: false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                      label: const Text('Open WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final phone = customPhoneCtrl.text.trim();
                        if (phone.isEmpty) {
                          AppSnackbar.warning('Enter Phone', 'Please enter a target number.');
                          return;
                        }
                        Get.back();
                        controller.wishCustomNumber(
                          record: record,
                          phone: phone,
                          recipientType: recipientChoice,
                          viaBot: true,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.smart_toy_rounded, size: 16),
                      label: const Text('Send via Bot', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

// ===========================================================================
// EXECUTIVE SLIVER PERSISTENT HEADER DELEGATE (MATCHES BIRTHDAY SCREEN)
// ===========================================================================

class _AdminAnniversaryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final AdminAnniversaryController controller;
  final double topPadding;

  _AdminAnniversaryHeaderDelegate({
    required this.controller,
    required this.topPadding,
  });

  @override
  double get minExtent => topPadding + 62.0;

  @override
  double get maxExtent => topPadding + 228.0;

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
      (32.0 * (1.0 - progress)).clamp(0.0, 32.0),
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
            // Ambient orbs & concentric rings
            CustomPaint(painter: _HeaderOrbPainter()),

            // Top pinned navigation bar (Back, Title, Status Chip, Refresh)
            Positioned(
              top: topPadding + 6,
              left: 16,
              right: 16,
              height: 46,
              child: Row(
                children: [
                  // Back button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Get.back(),
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

                  // Collapsed title
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: Obx(() {
                        final title = controller.isLeader.value
                            ? (controller.leaderGroup.value != null
                                ? '${controller.leaderGroup.value} Anniversaries'
                                : 'Group Anniversaries')
                            : "Parents' Anniversary";
                        return Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                    ),
                  ),

                  // Status Indicator / Leader Group Chip
                  Obx(() {
                    final isLeader = controller.isLeader.value;
                    if (isLeader) {
                      final group = controller.leaderGroup.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_rounded, color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              group != null && group.isNotEmpty ? '$group Leader' : 'Leader',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final isOnline = controller.dashboard.value?.isWhatsAppConnected ?? false;
                    return GestureDetector(
                      onTap: () => Get.toNamed(Routes.whatsappNumbers),
                      child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF10B981).withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isOnline ? const Color(0xFF6EE7B7) : Colors.white.withValues(alpha: 0.28),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOnline ? Icons.chat_bubble_rounded : Icons.link_off_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isOnline ? 'WA Online' : 'WA Offline',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),

                  // Refresh button with spinner
                  Obx(() {
                    final isLoading = controller.isLoading.value;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isLoading
                            ? null
                            : () {
                                controller.loadDashboard();
                                if (controller.selectedTab.value == 3) {
                                  controller.loadAllStudents();
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
                  }),
                ],
              ),
            ),

            // Expanded Header Content
            if (expandedOpacity > 0.02)
              Positioned(
                left: 20,
                right: 20,
                bottom: 12,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: Transform.translate(
                    offset: Offset(0, -progress * 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAAB78),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Obx(() {
                          final isLeader = controller.isLeader.value;
                          final group = controller.leaderGroup.value;
                          final overline = isLeader
                              ? (group != null ? '$group GROUP LEADER' : 'LEADER PORTAL')
                              : 'AUTOMATED GREETINGS & CELEBRANTS';
                          final title = isLeader
                              ? (group != null ? '$group Celebrants' : "Parents' Anniversary")
                              : "Parents' Anniversary";
                          final subtitle = isLeader
                              ? (group != null
                                  ? 'Wish $group group families on marriage anniversaries'
                                  : 'Wish parents of your group on their special day')
                              : 'Marriage anniversary greetings for Father & Mother';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                overline.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 10),

                        // Frosted Summary Metric Cards
                        Obx(_buildHeaderMetricCards),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMetricCards() {
    final data = controller.dashboard.value;
    final todayCount = data?.todaysAnniversaries.length ?? 0;
    final tomorrowCount = data?.tomorrowsAnniversaries.length ?? 0;
    final totalStudents = controller.allStudents.length;
    final isAuto = controller.isAnniversaryEnabled.value;

    return Row(
      children: [
        // Today
        Expanded(
          child: _HeaderMetricCard(
            title: 'Today',
            countText: '$todayCount',
            icon: Icons.volunteer_activism_rounded,
            accentColor: const Color(0xFFFDA4AF),
            highlightAlert: todayCount > 0,
            isSelected: controller.selectedTab.value == 0,
            onTap: () => controller.selectedTab.value = 0,
          ),
        ),
        const SizedBox(width: 8),

        // Tomorrow
        Expanded(
          child: _HeaderMetricCard(
            title: 'Tomorrow',
            countText: '$tomorrowCount',
            icon: Icons.event_rounded,
            accentColor: const Color(0xFF86EFAC),
            isSelected: controller.selectedTab.value == 1,
            onTap: () => controller.selectedTab.value = 1,
          ),
        ),
        const SizedBox(width: 8),

        // Directory
        Expanded(
          child: _HeaderMetricCard(
            title: 'Directory',
            countText: totalStudents > 0 ? '$totalStudents' : 'View',
            icon: Icons.people_alt_rounded,
            accentColor: const Color(0xFFA78BFA),
            isSelected: controller.selectedTab.value == 3,
            onTap: () {
              controller.selectedTab.value = 3;
              if (controller.allStudents.isEmpty) {
                controller.loadAllStudents();
              }
            },
          ),
        ),
        const SizedBox(width: 8),

        // Automation Status
        Expanded(
          child: _HeaderMetricCard(
            title: 'Automation',
            countText: isAuto ? 'ON' : 'OFF',
            icon: Icons.bolt_rounded,
            accentColor: isAuto ? const Color(0xFFFDE047) : const Color(0xFFCBD5E1),
            isSelected: controller.selectedTab.value == 2,
            onTap: () => controller.selectedTab.value = 2,
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _AdminAnniversaryHeaderDelegate oldDelegate) {
    return oldDelegate.controller != controller || oldDelegate.topPadding != topPadding;
  }
}

// ===========================================================================
// FROSTED SUMMARY METRIC CARD
// ===========================================================================

class _HeaderMetricCard extends StatelessWidget {
  final String title;
  final String countText;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final bool highlightAlert;
  final VoidCallback onTap;

  const _HeaderMetricCard({
    required this.title,
    required this.countText,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    this.highlightAlert = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.28)
                : (highlightAlert
                    ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.14)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : (highlightAlert
                      ? const Color(0xFFFCA5A5)
                      : Colors.white.withValues(alpha: 0.22)),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: highlightAlert
                    ? const Color(0xFFFF8A8A)
                    : (isSelected ? Colors.white : accentColor),
              ),
              const SizedBox(height: 2),
              Text(
                countText,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: Colors.white.withValues(
                    alpha: isSelected ? 1.0 : 0.85,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// HEADER ORB PAINTER (AMBIENT GLOW & CONCENTRIC ARCS)
// ===========================================================================

class _HeaderOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top-right ambient orb
    final paint1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.2), 70, paint1);

    // Bottom-left concentric ring
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.9), 90, ringPaint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.9), 130, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Icon-only action on a parent box (Call / WhatsApp): equal width, 36 high.
class _ParentActionIcon extends StatelessWidget {
  final String tooltip;
  final Widget icon;
  final Color background;
  final VoidCallback? onTap;

  const _ParentActionIcon({
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(height: 36, child: Center(child: icon)),
        ),
      ),
    );
  }
}
