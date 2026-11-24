import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/models/birthday/birthday_models.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/student_contact_card.dart';
import '../controllers/admin_birthday_controller.dart';
import '../models/parent_birthday.dart';
import '../widgets/parent_birthday_section.dart';
import '../widgets/template_library.dart';
import '../widgets/template_preview.dart';
import '../../shared/widgets/student_avatar.dart';

/// Modern, executive view of Hostel Birthday Greetings & Automation,
/// styled with the signature deep navy header, sky-blue accents, amber section dashes,
/// and slate card styling from the Phonebook, Geofence, and Student Locations screens.
class AdminBirthdayScreen extends GetView<AdminBirthdayController> {
  const AdminBirthdayScreen({super.key});

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
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
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
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Retry',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final isOnline =
              (data?.isWhatsAppConnected ?? false) ||
              controller.connectedPhone.isNotEmpty;

          return RefreshIndicator(
            onRefresh: () async {
              await controller.loadDashboard();
              if (!controller.isLeader.value) {
                await controller.fetchWhatsAppStatus();
              }
            },
            color: const Color(0xFF0284C7),
            backgroundColor: Colors.white,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _AdminBirthdayHeaderDelegate(
                    controller: controller,
                    topPadding: topPadding,
                    onOpenLinkSheet: controller.isLeader.value
                        ? null
                        : () => _showLinkDeviceSheet(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. WhatsApp Connection Alert Banner (if disconnected) - Admins only
                        if (!controller.isLeader.value && !isOnline) ...[
                          _buildNotConnectedBanner(context),
                          const SizedBox(height: 16),
                        ],

                        // 2. Tab Category Pills
                        _buildTabPillBar(),
                        const SizedBox(height: 18),

                        // 3. Tab Content
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

  // --- WhatsApp Disconnected Banner ---

  Widget _buildNotConnectedBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phonelink_erase_rounded,
              color: Color(0xFFD97706),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'WhatsApp Device Not Linked',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: Color(0xFF92400E),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'UNLINKED',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Link your phone number to dispatch automated greetings to students.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF78350F),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _showLinkDeviceSheet(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_rounded, color: Colors.white, size: 15),
                        SizedBox(width: 5),
                        Text(
                          'Link WhatsApp Device',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab Category Pills ---

  Widget _buildTabPillBar() {
    return Obx(() {
      final current = controller.selectedTab.value;
      final todayCount =
          controller.dashboard.value?.todaysBirthdays.length ?? 0;
      final tomorrowCount =
          controller.dashboard.value?.tomorrowsBirthdays.length ?? 0;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildTabPill(
              index: 0,
              label: 'Today',
              count: todayCount,
              icon: Icons.cake_rounded,
              isSelected: current == 0,
              activeColor: const Color(0xFF0284C7),
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
              label: controller.isLeader.value ? 'Wish Template' : 'Template Studio',
              icon: Icons.tune_rounded,
              isSelected: current == 2,
              activeColor: const Color(0xFFD97706),
            ),
            const SizedBox(width: 8),
            _buildTabPill(
              index: 3,
              label: controller.isLeader.value ? 'Group Directory' : 'Directory',
              icon: Icons.people_alt_rounded,
              isSelected: current == 3,
              activeColor: const Color(0xFF6366F1),
            ),
            if (!controller.isLeader.value) ...[
              const SizedBox(width: 8),
              _buildTabPill(
                index: 4,
                label: 'Logs & Test',
                icon: Icons.history_rounded,
                isSelected: current == 4,
                activeColor: const Color(0xFF0284C7),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildTabPill({
    required int index,
    required String label,
    int? count,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (controller.selectedTab.value == 2 && index != 2 && controller.hasUnsavedChanges) {
            controller.discardUnsavedChanges();
          }
          controller.selectedTab.value = index;
          if (index == 3 && controller.allStudents.isEmpty) {
            controller.fetchStudents();
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.28),
                      blurRadius: 8,
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
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  letterSpacing: -0.1,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- Active Tab Content Dispatcher ---

  Widget _buildActiveTabContent(
    BuildContext context,
    BirthdayDashboardData? data,
  ) {
    return Obx(() {
      if (controller.isLeader.value && controller.selectedTab.value == 4) {
        return _buildTodayTab(context, data);
      }
      switch (controller.selectedTab.value) {
        case 0:
          return _buildTodayTab(context, data);
        case 1:
          return _buildTomorrowTab(context, data);
        case 2:
          return controller.isLeader.value
              ? _buildLeaderTemplateTab(context)
              : _buildTemplateStudioTab(data);
        case 3:
          return _buildDirectoryTab(context);
        case 4:
          return _buildLogsAndTestTab(context, data);
        default:
          return _buildTodayTab(context, data);
      }
    });
  }

  // --- Tab 0: Today's Celebrants ---

  /// Today: students' birthdays, then parents' own birthdays (from the
  /// phonebook on this phone).
  Widget _buildTodayTab(BuildContext context, BirthdayDashboardData? data) {
    return Obx(() => _withParentBirthdays(
          students: data?.todaysBirthdays ?? const [],
          parents: controller.parentBirthdaysToday.toList(),
          isToday: true,
          studentsPart: () => _buildTodayStudents(context, data),
        ));
  }

  /// Tomorrow: students' birthdays, then parents' own birthdays.
  Widget _buildTomorrowTab(BuildContext context, BirthdayDashboardData? data) {
    return Obx(() => _withParentBirthdays(
          students: data?.tomorrowsBirthdays ?? const [],
          parents: controller.parentBirthdaysTomorrow.toList(),
          isToday: false,
          studentsPart: () => _buildTomorrowStudents(context, data),
        ));
  }

  /// The students part as before (with its empty card when nobody at all
  /// celebrates), followed by the parents' section when there are any.
  Widget _withParentBirthdays({
    required List<BirthdayStudentModel> students,
    required List<ParentBirthday> parents,
    required bool isToday,
    required Widget Function() studentsPart,
  }) {
    if (parents.isEmpty) return studentsPart();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (students.isNotEmpty) ...[
          studentsPart(),
          const SizedBox(height: 22),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              isToday ? 'No student birthdays today.' : 'No student birthdays tomorrow.',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ),
        ParentBirthdaySection(
          controller: controller,
          parents: parents,
          isToday: isToday,
          // No student card (with its Send All) today: offer it here when the run includes parents.
          showSendAll: isToday &&
              students.isEmpty &&
              !controller.isLeader.value &&
              controller.parentBirthdaysFromServer.value &&
              controller.includeParentBirthdays.value,
        ),
      ],
    );
  }

  Widget _buildTodayStudents(BuildContext context, BirthdayDashboardData? data) {
    final list = data?.todaysBirthdays ?? [];

    if (list.isEmpty) {
      return _buildEmptyStateCard(
        icon: Icons.cake_outlined,
        iconColor: const Color(0xFFD97706),
        iconBgColor: const Color(0xFFFEF3C7),
        title: 'No Birthdays Today',
        subtitle: controller.isLeader.value
            ? 'No students in ${controller.leaderGroup.value ?? "your"} group celebrate their birthday today.'
            : "No registered students celebrate their birthday today. Check tomorrow's tab for upcoming hostel celebrants.",
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Dispatch Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF0F9FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: Color(0xFF0284C7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${list.length} Celebrant${list.length > 1 ? "s" : ""} Today!',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Obx(() {
                      final isLeader = controller.isLeader.value;
                      return Text(
                        isLeader
                            ? 'Tap below to wish group celebrants directly on WhatsApp.'
                            : 'Automated WhatsApp wishes scheduled via linked device.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          height: 1.3,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Obx(() {
                if (controller.isLeader.value) {
                  return const SizedBox.shrink();
                }
                final isBusy = controller.isTriggering.value;
                final alreadySent = controller.hasSentToday.value;
                final isLinked = controller.isWhatsAppLinked;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isBusy
                          ? null
                          : () {
                              if (alreadySent) return;
                              controller.triggerAllToday(
                                onNeedLinkDevice: () =>
                                    _showLinkDeviceSheet(context),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alreadySent
                            ? const Color(0xFFF1F5F9)
                            : (isLinked
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFFD97706)),
                        foregroundColor: alreadySent
                            ? const Color(0xFF64748B)
                            : Colors.white,
                        disabledBackgroundColor: const Color(0xFFF1F5F9),
                        disabledForegroundColor: const Color(0xFF64748B),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              alreadySent
                                  ? 'Sent Today ✓'
                                  : 'Send All',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...() {
          final hostelList = list.where((s) => !controller.isAlumni(s)).toList();
          final alumniList = list.where((s) => controller.isAlumni(s)).toList();

          if (hostelList.isNotEmpty && alumniList.isNotEmpty) {
            return [
              _buildSectionHeader(
                title: "Hostel Celebrants (${hostelList.length})",
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'RESIDENTS FIRST',
                    style: TextStyle(
                      color: Color(0xFF0284C7),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...hostelList.map((s) => _buildStudentCelebrantCard(s, isToday: true)),
              const SizedBox(height: 20),
              _buildSectionHeader(
                title: "Alumni Celebrants (${alumniList.length})",
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'ALUMNI',
                    style: TextStyle(
                      color: Color(0xFF9333EA),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...alumniList.map((s) => _buildStudentCelebrantCard(s, isToday: true)),
            ];
          }

          final isAlumniOnly = hostelList.isEmpty && alumniList.isNotEmpty;
          return [
            _buildSectionHeader(
              title: isAlumniOnly
                  ? "Alumni Celebrants (${list.length})"
                  : "Today's Celebrants (${list.length})",
            ),
            const SizedBox(height: 12),
            ...list.map((s) => _buildStudentCelebrantCard(s, isToday: true)),
          ];
        }(),
      ],
    );
  }

  // --- Tab 1: Tomorrow's Celebrants ---

  Widget _buildTomorrowStudents(BuildContext context, BirthdayDashboardData? data) {
    final list = data?.tomorrowsBirthdays ?? [];

    if (list.isEmpty) {
      return _buildEmptyStateCard(
        icon: Icons.event_available_rounded,
        iconColor: const Color(0xFF059669),
        iconBgColor: const Color(0xFFECFDF5),
        title: 'No Birthdays Tomorrow',
        subtitle: controller.isLeader.value
            ? 'There are no birthdays in ${controller.leaderGroup.value ?? "your"} group scheduled for tomorrow.'
            : 'There are no student birthdays scheduled for tomorrow.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...() {
          final hostelList = list.where((s) => !controller.isAlumni(s)).toList();
          final alumniList = list.where((s) => controller.isAlumni(s)).toList();

          if (hostelList.isNotEmpty && alumniList.isNotEmpty) {
            return [
              _buildSectionHeader(
                title: "Hostel Celebrants (${hostelList.length})",
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'RESIDENTS FIRST',
                    style: TextStyle(
                      color: Color(0xFF0284C7),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...hostelList.map((s) => _buildStudentCelebrantCard(s, isToday: false)),
              const SizedBox(height: 20),
              _buildSectionHeader(
                title: "Alumni Celebrants (${alumniList.length})",
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'ALUMNI',
                    style: TextStyle(
                      color: Color(0xFF9333EA),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...alumniList.map((s) => _buildStudentCelebrantCard(s, isToday: false)),
            ];
          }

          final isAlumniOnly = hostelList.isEmpty && alumniList.isNotEmpty;
          return [
            _buildSectionHeader(
              title: isAlumniOnly
                  ? "Alumni Celebrants (${list.length})"
                  : "Tomorrow's Celebrants (${list.length})",
            ),
            const SizedBox(height: 12),
            ...list.map((s) => _buildStudentCelebrantCard(s, isToday: false)),
          ];
        }(),
      ],
    );
  }

  // --- Modern Celebrant VIP Card (Light Executive Theme, Milestone Banner & Modern Actions) ---

  Widget _buildStudentCelebrantCard(
    BirthdayStudentModel s, {
    required bool isToday,
  }) {
    final isSent = s.alreadySentToday;
    final turningAge = _computeTurningAge(s.dob);
    final formattedDob = _formatCelebrantDob(s.dob);
    final hasContact = s.whatsappNumber.isNotEmpty || s.phone.isNotEmpty;
    final group = controller.groupFor(s);
    final isAlumni = controller.isAlumni(s);

    // Color tokens matching the operator home screen palette
    final Color waveColor = isToday
        ? (isSent ? const Color(0xFF99F6E4) : const Color(0xFFFDE68A))
        : const Color(0xFFBAE6FD);
    final Color bgTint = isToday
        ? (isSent ? const Color(0xFFCCFBF1) : const Color(0xFFFEF3C7))
        : const Color(0xFFE0F2FE);
    final Color accentColor = isToday
        ? (isSent ? const Color(0xFF0D9488) : const Color(0xFFD97706))
        : const Color(0xFF0284C7);
    final Color arrowBgTint = isToday
        ? (isSent ? const Color(0xFFF0FDFA) : const Color(0xFFFFFBEB))
        : const Color(0xFFF0F9FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          // Bottom-right organic corner wave (operator card signature)
          Positioned(
            bottom: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(110, 75),
              painter: _CornerWavePainter(
                color: waveColor.withValues(alpha: 0.55),
              ),
            ),
          ),

          // Card content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Identity Row: Avatar + Name/Subtitle + Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Squircle avatar
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        StudentAvatar(
                          name: s.name,
                          bankCode: s.studentCode,
                          size: 46,
                          circle: false,
                          background: bgTint,
                          child: Text(
                            s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              isToday ? Icons.cake_rounded : Icons.star_rounded,
                              color: Colors.white,
                              size: 9.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 12),

                    // Name + Milestone subtitle (inline with avatar)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isToday
                                ? (turningAge != null
                                      ? 'Turning ${_getOrdinal(turningAge)} Today 🎉'
                                      : 'Today\'s Celebrant 🎂')
                                : (turningAge != null
                                      ? 'Turns ${_getOrdinal(turningAge)} Tomorrow ✨'
                                      : 'Tomorrow\'s Celebrant ✨'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: accentColor,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Top-right status pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: arrowBgTint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: waveColor, width: 1.1),
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
                            isToday
                                ? (isSent ? 'Sent ✓' : 'Pending')
                                : 'Upcoming',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 2. Metadata chips — only non-redundant info
                Wrap(
                  spacing: 6,
                  runSpacing: 4.5,
                  children: [
                    // Group or Alumni, styled like the phonebook card
                    _buildCelebrantLightChip(
                      icon: isAlumni
                          ? Icons.school_rounded
                          : Icons.groups_rounded,
                      text: isAlumni ? 'Alumni' : (group ?? 'Active'),
                      bgColor: isAlumni
                          ? const Color(0xFFF3E8FF)
                          : StudentContactCard.groupBgColor(group),
                      borderColor: isAlumni
                          ? const Color(0xFFE9D5FF)
                          : StudentContactCard.groupColor(
                              group,
                            ).withValues(alpha: 0.25),
                      textColor: isAlumni
                          ? const Color(0xFF9333EA)
                          : StudentContactCard.groupColor(group),
                    ),
                    // Room (skip N/A — day scholars need no chip)
                    if (s.room != 'N/A' && !isAlumni)
                      _buildCelebrantLightChip(
                        icon: Icons.meeting_room_rounded,
                        text: 'Room ${s.room}',
                        bgColor: const Color(0xFFF1F5F9),
                        borderColor: const Color(0xFFE2E8F0),
                        textColor: const Color(0xFF334155),
                      ),
                    // Student code / bank code
                    // if (s.studentCode.isNotEmpty)
                    //   _buildCelebrantLightChip(
                    //     icon: Icons.tag_rounded,
                    //     text: s.studentCode,
                    //     bgColor: const Color(0xFFF1F5F9),
                    //     borderColor: const Color(0xFFE2E8F0),
                    //     textColor: const Color(0xFF475569),
                    //   ),
                    // DOB date only — age already shown in subtitle
                    if (formattedDob.isNotEmpty)
                      _buildCelebrantLightChip(
                        icon: Icons.cake_outlined,
                        text: formattedDob,
                        bgColor: const Color(0xFFF0F9FF),
                        borderColor: const Color(0xFFBAE6FD),
                        textColor: const Color(0xFF0284C7),
                      ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // 4. Action buttons
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    if (hasContact) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => controller.sendWishToStudent(s),
                          icon: Icon(
                            Icons.chat_bubble_rounded,
                            size: 15,
                            color: isSent
                                ? const Color(0xFF065F46)
                                : Colors.white,
                          ),
                          label: Text(
                            isSent
                                ? 'Sent • Chat on WA'
                                : 'Send WhatsApp Wish 🎉',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSent
                                  ? const Color(0xFF065F46)
                                  : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSent
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFF059669),
                            foregroundColor: isSent
                                ? const Color(0xFF065F46)
                                : Colors.white,
                            elevation: 0,
                            side: isSent
                                ? const BorderSide(color: Color(0xFFA7F3D0))
                                : null,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ] else ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'No Phone Registered',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],

                    if (s.phone.isNotEmpty) ...[
                      _buildLightCardActionButton(
                        icon: Icons.phone_rounded,
                        iconColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFE0F2FE),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                        tooltip: 'Call Student (${s.phone})',
                        onTap: () => controller.callPhone(s.phone),
                      ),
                    ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildLightCardActionButton({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    Border? border,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 55,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: iconColor),
          ),
        ),
      ),
    );
  }

  int? _computeTurningAge(String dobStr) {
    if (dobStr.isEmpty) return null;
    try {
      final parsed = DateTime.tryParse(dobStr);
      if (parsed == null) return null;
      final now = DateTime.now();
      int age = now.year - parsed.year;
      return age > 0 ? age : null;
    } catch (_) {
      return null;
    }
  }

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  String _formatCelebrantDob(String dobStr) {
    if (dobStr.isEmpty) return '';
    try {
      final parsed = DateTime.tryParse(dobStr);
      if (parsed == null) return dobStr;
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
    } catch (_) {
      return dobStr;
    }
  }

  // --- Tab 2: Template Studio & Config ---

  Widget _buildTemplateStudioTab(BirthdayDashboardData? data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Delivery & Schedule Configuration Card
        _buildSectionHeader(title: 'Automation & Delivery Setup'),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Daily Schedule Time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Send Time (IST)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Automated greetings will dispatch at this hour',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Obx(
                    () => ActionChip(
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      avatar: const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: Color(0xFF0284C7),
                      ),
                      label: Text(
                        controller.sendTime.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      onPressed: () async {
                        final parts = controller.sendTime.value.split(':');
                        final initial = TimeOfDay(
                          hour: int.tryParse(parts.first) ?? 8,
                          minute: int.tryParse(parts.last) ?? 0,
                        );
                        final picked = await showTimePicker(
                          context: Get.context!,
                          initialTime: initial,
                        );
                        if (picked != null) {
                          final h = picked.hour.toString().padLeft(2, '0');
                          final m = picked.minute.toString().padLeft(2, '0');
                          controller.sendTime.value = '$h:$m';
                        }
                      },
                    ),
                  ),
                ],
              ),
              const Divider(height: 28, color: Color(0xFFF1F5F9)),

              // Target Audience Selection
              const Text(
                'Target Audience',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Obx(
                () => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _audienceChip(
                      'student_only',
                      'Students Only',
                      Icons.school_rounded,
                    ),
                    _audienceChip(
                      'parent_only',
                      'Parents Only',
                      Icons.family_restroom_rounded,
                    ),
                    _audienceChip(
                      'student_and_parent',
                      'Students & Parents',
                      Icons.people_alt_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Obx(() {
                final aud = controller.targetAudience.value;
                String desc;
                if (aud == 'parent_only') {
                  desc = '⚠️ Wishes will be sent to Parents only (Students will not receive wishes).';
                } else if (aud == 'student_and_parent') {
                  desc = '✨ Wishes will be sent to both the Student and their Parents.';
                } else {
                  desc = '👤 Wishes will be sent to Students only.';
                }
                return Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: aud == 'parent_only'
                        ? const Color(0xFFD97706)
                        : const Color(0xFF64748B),
                  ),
                );
              }),

              // Parents' own birthdays in Send All and the daily run (servers that support it)
              Obx(() {
                if (!controller.supportsParentBirthdays) return const SizedBox.shrink();
                final on = controller.includeParentBirthdays.value;
                return Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: on ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: on ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cake_rounded, size: 20, color: Color(0xFFD97706)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Also wish parents on their own birthday",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Send All and the daily run also wish fathers and mothers whose birthday it is, '
                              'with the Father / Mother templates. Each parent once a day.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: on,
                        activeTrackColor: const Color(0xFFD97706),
                        onChanged: (v) => controller.includeParentBirthdays.value = v,
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 28, color: Color(0xFFF1F5F9)),

              // Admin Notification Phone
              const Text(
                'Admin Digest Alert Mobile (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller.adminPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'e.g. 9876543210',
                  prefixIcon: const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF0284C7),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF0284C7),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // 2. Custom Message Template Card
        _buildSectionHeader(title: 'Wish Templates'),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Saved templates per audience, with the active one marked.
              BirthdayTemplateLibrary(controller: controller),
              const Divider(height: 30, color: Color(0xFFF1F5F9)),

              Obx(
                () => Text(
                  switch (controller.editingAudience.value) {
                    BirthdayAudience.parent => 'Edit Template · to parents on the student\'s birthday',
                    BirthdayAudience.father => 'Edit Father Birthday Template',
                    BirthdayAudience.mother => 'Edit Mother Birthday Template',
                    _ => 'Edit Student Template',
                  },
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller.templateNameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Template name',
                  hintText: 'e.g. Festive wish',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF0284C7),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Personalization Placeholders',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap tags below to inject dynamic details into the greeting message:',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),

              // Placeholder chips
              Obx(
                () => Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: BirthdayAudience.parentBirthdays.contains(controller.editingAudience.value)
                      ? [
                          _varChip('{parent_name}', 'Parent Name'),
                          _varChip('{first_name}', 'Parent First Name'),
                          _varChip('{student_name}', 'Child Name'),
                          _varChip('{age}', 'Age'),
                          _varChip('{room}', 'Room No'),
                        ]
                      : [
                          _varChip('{first_name}', 'First Name'),
                          _varChip('{student_name}', 'Full Name'),
                          _varChip('{room}', 'Room No'),
                          _varChip('{student_code}', 'Student Code'),
                        ],
                ),
              ),
              const SizedBox(height: 14),

              // Template Editor
              TextField(
                controller: controller.templateController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter your custom birthday greeting...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF0284C7),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Live preview: rebuilds on every keystroke in the template editor.
              Obx(
                () {
                  final audience = controller.editingAudience.value;
                  final ownBirthday = BirthdayAudience.parentBirthdays.contains(audience);
                  return BirthdayTemplatePreview(
                    templateController: controller.templateController,
                    parentRole: ownBirthday ? audience : null,
                    title: switch (audience) {
                      BirthdayAudience.parent => 'WhatsApp Preview · sent to parents',
                      BirthdayAudience.father => 'WhatsApp Preview · father\'s birthday',
                      BirthdayAudience.mother => 'WhatsApp Preview · mother\'s birthday',
                      _ => 'WhatsApp Preview · sent to students',
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              Obx(
                () => controller.hasUnsavedChanges
                    ? Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'You have unsaved changes. Tap "Save Configuration" to apply them.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: controller.discardUnsavedChanges,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: const Text(
                                'Discard',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFD97706),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Save Button
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: controller.isSaving.value
                        ? null
                        : controller.saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: controller.isSaving.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      controller.isSaving.value
                          ? 'Saving Changes...'
                          : 'Save Configuration',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _audienceChip(String value, String label, IconData icon) {
    final isSelected = controller.targetAudience.value == value;

    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => controller.targetAudience.value = value,
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected ? Colors.white : const Color(0xFF64748B),
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF334155),
      ),
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _varChip(String tag, String label) {
    return ActionChip(
      backgroundColor: const Color(0xFFE0F2FE),
      side: const BorderSide(color: Color(0xFFBAE6FD)),
      label: Text(
        '+ $tag',
        style: const TextStyle(
          color: Color(0xFF0284C7),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: () => controller.insertVariableTag(tag),
    );
  }

  Widget _leaderVarChip(String tag, String label) {
    return ActionChip(
      backgroundColor: const Color(0xFFFEF3C7),
      side: const BorderSide(color: Color(0xFFFDE68A)),
      label: Text(
        '+ $tag',
        style: const TextStyle(
          color: Color(0xFFD97706),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: () => controller.insertLeaderPlaceholder(tag),
    );
  }

  // --- Leader Tab 2: Personal Wish Template ---

  Widget _buildLeaderTemplateTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => _buildSectionHeader(
            title: controller.leaderGroup.value != null &&
                    controller.leaderGroup.value!.isNotEmpty
                ? '${controller.leaderGroup.value} Group · Birthday Wish Template'
                : 'Group Birthday Wish Template',
          ),
        ),
        const SizedBox(height: 10),

        // Info Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF15803D),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personalized Leader Greeting',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'When you tap "Send WhatsApp Wish 🎉" on any group student\'s birthday card, this customized message will be pre-filled in your WhatsApp.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: const Color(0xFF166534).withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Editor Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Greeting Message',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      controller.resetLeaderTemplateToDefault();
                      AppSnackbar.info(
                        'Reset to Default',
                        'Restored the recommended birthday greeting template.',
                      );
                    },
                    icon: const Icon(
                      Icons.restart_alt_rounded,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    label: const Text(
                      'Reset to Default',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Personalization Placeholders',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap any tag below to insert dynamic student details:',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),

              // Placeholder chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _leaderVarChip('{first_name}', 'First Name'),
                  _leaderVarChip('{student_name}', 'Full Name'),
                  _leaderVarChip('{room_number}', 'Room No'),
                  _leaderVarChip('{student_code}', 'Student Code'),
                ],
              ),
              const SizedBox(height: 14),

              // Template Editor TextField
              TextField(
                controller: controller.leaderTemplateController,
                maxLines: 6,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your personalized birthday greeting...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF0284C7),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Live WhatsApp Message Preview
              BirthdayTemplatePreview(
                templateController: controller.leaderTemplateController,
                title: 'WhatsApp Preview · Leader Greeting',
              ),
              const SizedBox(height: 20),

              // Save Button
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: controller.isSaving.value
                        ? null
                        : () => controller.saveLeaderTemplate(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: controller.isSaving.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      controller.isSaving.value
                          ? 'Saving Template...'
                          : 'Save Wish Template',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // --- Tab 3: Directory ---

  Widget _buildDirectoryTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => _buildSectionHeader(
            title: controller.isLeader.value
                ? '${controller.leaderGroup.value ?? "Group"} Birthday Directory'
                : 'Hostel Birthday Directory',
          ),
        ),
        const SizedBox(height: 12),

        // Search Bar & Filter Button styled like PhonebookScreen
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
                  onSubmitted: (query) => controller.fetchStudents(query: query),
                  decoration: InputDecoration(
                    hintText: 'Search by student name, code, or room...',
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
                        controller.fetchStudents();
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
            Obx(() {
              final count = controller.activeFilterCount;
              return Material(
                color: count > 0 ? const Color(0xFF0284C7) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: count > 0 ? 3 : 1,
                shadowColor: count > 0 ? const Color(0xFF0284C7).withValues(alpha: 0.3) : Colors.black12,
                child: InkWell(
                  key: const ValueKey('birthday_directory_filter_button'),
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
          final hostelCount = list.where((s) => !controller.isAlumni(s)).length;
          final alumniCount = list.where((s) => controller.isAlumni(s)).length;
          final withDobCount = list.where((s) => s.dob.trim().isNotEmpty).length;
          final withoutDobCount = list.length - withDobCount;
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
                  label: 'With Birthday ($withDobCount)',
                  icon: Icons.cake_outlined,
                  isSelected: currentFilter == 'has_dob',
                  onTap: () => controller.directoryFilter.value = 'has_dob',
                  activeColor: const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                _buildDirectoryFilterChip(
                  label: 'Without Birthday ($withoutDobCount)',
                  icon: Icons.event_busy_rounded,
                  isSelected: currentFilter == 'no_dob',
                  onTap: () => controller.directoryFilter.value = 'no_dob',
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
            return _buildEmptyStateCard(
              icon: Icons.person_search_rounded,
              iconColor: const Color(0xFF0284C7),
              iconBgColor: const Color(0xFFE0F2FE),
              title: 'No Students Found',
              subtitle: controller.activeFilterCount > 0
                  ? 'No students match your active filters. Try clearing or relaxing the filters.'
                  : 'Tap Search to query and load student directory records.',
            );
          }

          final currentFilter = controller.directoryFilter.value;

          // Split students: active hostel residents first, alumni afterwards
          final hostelStudents = list.where((s) => !controller.isAlumni(s)).toList();
          final alumniStudents = list.where((s) => controller.isAlumni(s)).toList();

          if (currentFilter == 'hostel') {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(
                  title: 'Hostel Residents (${hostelStudents.length})',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'ACTIVE RESIDENTS',
                      style: TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...hostelStudents.map((s) => _buildDirectoryStudentCard(s)),
              ],
            );
          }

          if (currentFilter == 'alumni') {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(
                  title: 'Alumni Students (${alumniStudents.length})',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'ALUMNI',
                      style: TextStyle(
                        color: Color(0xFF9333EA),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...alumniStudents.map((s) => _buildDirectoryStudentCard(s)),
              ],
            );
          }

          if (currentFilter == 'has_dob') {
            final withDobHostel = hostelStudents.where((s) => s.dob.trim().isNotEmpty).toList();
            final withDobAlumni = alumniStudents.where((s) => s.dob.trim().isNotEmpty).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (withDobHostel.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'Hostel Residents with Birthday (${withDobHostel.length})',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'HOSTEL FIRST',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...withDobHostel.map((s) => _buildDirectoryStudentCard(s)),
                ],
                if (withDobAlumni.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    title: 'Alumni with Birthday (${withDobAlumni.length})',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'ALUMNI',
                        style: TextStyle(
                          color: Color(0xFF9333EA),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...withDobAlumni.map((s) => _buildDirectoryStudentCard(s)),
                ],
              ],
            );
          }

          if (currentFilter == 'no_dob') {
            final noDobHostel = hostelStudents.where((s) => s.dob.trim().isEmpty).toList();
            final noDobAlumni = alumniStudents.where((s) => s.dob.trim().isEmpty).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (noDobHostel.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'Hostel Residents without Birthday (${noDobHostel.length})',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'NO DOB',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...noDobHostel.map((s) => _buildDirectoryStudentCard(s)),
                ],
                if (noDobAlumni.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    title: 'Alumni without Birthday (${noDobAlumni.length})',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'ALUMNI',
                        style: TextStyle(
                          color: Color(0xFF9333EA),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...noDobAlumni.map((s) => _buildDirectoryStudentCard(s)),
                ],
              ],
            );
          }

          // Default: 'all' filter shows Hostel Residents FIRST, followed by Alumni Students AFTERWARDS!
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hostelStudents.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'Hostel Residents (${hostelStudents.length})',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'ACTIVE RESIDENTS FIRST',
                      style: TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...hostelStudents.map((s) => _buildDirectoryStudentCard(s)),
              ],
              if (alumniStudents.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionHeader(
                  title: 'Alumni Students (${alumniStudents.length})',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'ALUMNI',
                      style: TextStyle(
                        color: Color(0xFF9333EA),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...alumniStudents.map((s) => _buildDirectoryStudentCard(s)),
              ],
            ],
          );
        }),
      ],
    );
  }

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
                                            'Filter & Sort Celebrants',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            'Refine by wings, floors, residence, and birthday info',
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
                                  children: AdminBirthdayController.hshGroups.map((g) {
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
                                children: AdminBirthdayController.floorOptions.map((f) {
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
                                children: AdminBirthdayController.statusOptions.map((s) {
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

                              // 4. BIRTHDAY & CONTACT ATTRIBUTES
                              _filterSectionHeader('BIRTHDAY & CONTACT ATTRIBUTES', Icons.cake_outlined),
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
                                      icon: Icons.cake_rounded,
                                      iconColor: const Color(0xFFD97706),
                                      title: 'Has Date of Birth (DOB)',
                                      subtitle: 'Show students with registered birthday info',
                                      value: controller.onlyWithDob.value,
                                      onChanged: controller.toggleOnlyWithDob,
                                    ),
                                    const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                                    _toggleRow(
                                      icon: Icons.event_busy_rounded,
                                      iconColor: const Color(0xFF64748B),
                                      title: 'Missing Date of Birth (No DOB)',
                                      subtitle: 'Show students needing birthday registration',
                                      value: controller.onlyWithoutDob.value,
                                      onChanged: controller.toggleOnlyWithoutDob,
                                    ),
                                    const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                                    _toggleRow(
                                      icon: Icons.chat_rounded,
                                      iconColor: const Color(0xFF10B981),
                                      title: 'Has Dedicated WhatsApp Number',
                                      subtitle: 'Show students with verified WhatsApp details',
                                      value: controller.onlyWithWhatsApp.value,
                                      onChanged: controller.toggleOnlyWithWhatsApp,
                                    ),
                                    const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                                    _toggleRow(
                                      icon: Icons.family_restroom_rounded,
                                      iconColor: const Color(0xFF0284C7),
                                      title: 'Has Parent Contact Phone',
                                      subtitle: 'Show students with Parent contact details',
                                      value: controller.onlyWithParents.value,
                                      onChanged: controller.toggleOnlyWithParents,
                                    ),
                                    const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                                    _toggleRow(
                                      icon: Icons.phone_rounded,
                                      iconColor: const Color(0xFF6366F1),
                                      title: 'Has Personal Phone',
                                      subtitle: 'Show students with registered personal phone',
                                      value: controller.onlyWithPhone.value,
                                      onChanged: controller.toggleOnlyWithPhone,
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
                                children: AdminBirthdayController.sortOptions.map((s) {
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
                              'Apply Filters & Show ($count Students)',
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
        Icon(icon, size: 15, color: const Color(0xFF0284C7)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF475569),
            letterSpacing: 0.6,
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
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF0284C7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: 1.1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectoryStudentCard(BirthdayStudentModel s) {
    final isAlumni = controller.isAlumni(s);
    final group = controller.groupFor(s);
    final Color avatarBgColor = isAlumni
        ? const Color(0xFFF3E8FF)
        : (group != null
            ? StudentContactCard.groupColor(group).withValues(alpha: 0.12)
            : const Color(0xFFE0F2FE));
    final Color avatarTextColor = isAlumni
        ? const Color(0xFF9333EA)
        : (group != null
            ? StudentContactCard.groupColor(group)
            : const Color(0xFF0284C7));

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
              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
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
                Text(
                  s.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildStudentStatusTag(s),
                    if (!isAlumni)
                      _buildTag(
                        icon: Icons.meeting_room_rounded,
                        text: s.room == 'N/A' ? 'Room N/A' : 'Room ${s.room}',
                        color: s.room == 'N/A' ? const Color(0xFFD97706) : null,
                      ),
                    if (s.studentCode.isNotEmpty)
                      _buildTag(
                        icon: Icons.badge_outlined,
                        text: s.studentCode,
                      ),
                    if (s.dob.isNotEmpty)
                      _buildTag(
                        icon: Icons.cake_outlined,
                        text: s.dob,
                        color: const Color(0xFFD97706),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (s.phone.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.phone_rounded,
                size: 18,
                color: Color(0xFF0284C7),
              ),
              tooltip: 'Call ${s.phone}',
              onPressed: () => controller.callPhone(s.phone),
            ),
          if (s.whatsappNumber.isNotEmpty || s.phone.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.chat_rounded,
                size: 18,
                color: Color(0xFF059669),
              ),
              tooltip: 'Send Birthday Wish',
              onPressed: () => controller.sendWishToStudent(s),
            ),
        ],
      ),
    );
  }

  // --- Tab 4: Logs & Sandbox ---

  Widget _buildLogsAndTestTab(
    BuildContext context,
    BirthdayDashboardData? data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sandbox Card
        _buildSectionHeader(title: 'Live Testing Sandbox'),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Instant Test Dispatch',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter any phone number to immediately test delivering the greeting template via WhatsApp without affecting celebrants:',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.testPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. 9876543210',
                        prefixIcon: const Icon(
                          Icons.phone_android_rounded,
                          color: Color(0xFF0284C7),
                          size: 20,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF0284C7),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Obx(
                    () => ElevatedButton(
                      onPressed: controller.isTriggering.value
                          ? null
                          : () {
                              if (!controller.isWhatsAppLinked) {
                                AppSnackbar.warning(
                                  'WhatsApp Not Connected',
                                  'Please link your WhatsApp device first before sending a test wish.',
                                );
                                _showLinkDeviceSheet(context);
                                return;
                              }
                              controller.sendTestWish(
                                onNeedLinkDevice: () =>
                                    _showLinkDeviceSheet(context),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: controller.isTriggering.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Send Test',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Recent Logs Card
        Obx(() => _buildSectionHeader(title: 'Recent Dispatch Logs (${controller.allLogs.length})')),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _buildLogsByDate(context),
        ),
      ],
    );
  }

  /// Dispatch logs under date headers, with a date filter row on top. The
  /// "Pick a day" chip loads an earlier day's logs, which the dashboard doesn't carry.
  Widget _buildLogsByDate(BuildContext context) {
    return Obx(() {
      final logs = controller.allLogs;
      final groups = AdminBirthdayController.groupLogsByDate(logs);
      var selected = controller.logDateFilter.value;
      // Forget a filter whose date is no longer in the logs; a day loaded on demand stays, even if empty.
      if (selected != null &&
          !controller.loadedLogDates.contains(selected) &&
          !groups.any((g) => g.date == selected)) {
        selected = null;
      }
      final visible = selected == null
          ? groups
          : groups.where((g) => g.date == selected).toList();
      final emptyDay = selected != null && visible.isEmpty ? selected : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _logDayPickerChip(context, selected),
                _logDateChip(
                  label: 'All dates',
                  count: logs.length,
                  isSelected: selected == null,
                  date: null,
                ),
                if (emptyDay != null)
                  _logDateChip(
                    label: AdminBirthdayController.logDateChipLabel(emptyDay),
                    count: 0,
                    isSelected: true,
                    date: emptyDay,
                  ),
                for (final g in groups)
                  _logDateChip(
                    label: AdminBirthdayController.logDateChipLabel(g.date),
                    count: g.logs.length,
                    isSelected: selected == g.date,
                    date: g.date,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if ((logs.isEmpty && selected == null) || emptyDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  emptyDay != null
                      ? 'No wishes were logged on ${AdminBirthdayController.logDateLabel(emptyDay)}.'
                      : 'No delivery logs yet.',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            ),
          for (final g in visible) ...[
            _logDateHeader(g.date, g.logs),
            for (var i = 0; i < g.logs.length; i++) ...[
              if (i > 0) const Divider(height: 14, color: Color(0xFFF1F5F9)),
              _buildLogRow(g.logs[i]),
            ],
            const SizedBox(height: 14),
          ],
        ],
      );
    });
  }

  /// Opens a calendar and loads every wish logged on the chosen day.
  Widget _logDayPickerChip(BuildContext context, String? selected) {
    final loading = controller.isLoadingLogs.value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        onPressed: loading ? null : () => _pickLogDay(context, selected),
        avatar: loading
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              )
            : const Icon(Icons.event_rounded, size: 14, color: Color(0xFF0284C7)),
        label: const Text('Pick a day'),
        labelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0284C7),
        ),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFBAE6FD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _pickLogDay(BuildContext context, String? selected) async {
    final now = DateFormatting.utcToIst(DateTime.now().toUtc());
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(2020);
    var initial = DateTime.tryParse(selected ?? '') ?? today;
    if (initial.isAfter(today)) initial = today;
    if (initial.isBefore(firstDate)) initial = firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: today,
      helpText: 'Show wishes logged on',
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    await controller.loadLogsForDate('${picked.year}-${two(picked.month)}-${two(picked.day)}');
  }

  Widget _logDateChip({
    required String label,
    required int count,
    required bool isSelected,
    required String? date,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        selected: isSelected,
        onSelected: (_) => controller.logDateFilter.value = date,
        showCheckmark: false,
        label: Text('$label · $count'),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
        selectedColor: const Color(0xFF0284C7),
        backgroundColor: const Color(0xFFF1F5F9),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _logDateHeader(String date, List<BirthdayLogModel> logs) {
    final sent = logs.where((l) => l.isSent).length;
    final failed = logs.length - sent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 13,
            color: Color(0xFF0284C7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AdminBirthdayController.logDateLabel(date),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Text(
            failed > 0 ? '$sent sent · $failed failed' : '$sent sent',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: failed > 0
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogRow(BirthdayLogModel log) {
    final sentAt = DateTime.tryParse(log.sentAt);
    final isParent = log.recipientType.toLowerCase() == 'parent';
    final details = [
      log.room == 'N/A' ? 'Room N/A' : 'Room ${log.room}',
      if (log.phone.isNotEmpty) log.phone,
      if (sentAt != null) DateFormatting.time(sentAt),
    ].join(' • ');
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: log.isSent
                ? const Color(0xFFECFDF5)
                : const Color(0xFFFEF2F2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            log.isSent ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 16,
            color: log.isSent
                ? const Color(0xFF059669)
                : const Color(0xFFDC2626),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      log.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildTag(
                    icon: isParent
                        ? Icons.family_restroom_rounded
                        : Icons.school_rounded,
                    text: isParent ? 'Parent' : 'Student',
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                details,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: log.isSent
                ? const Color(0xFFECFDF5)
                : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: log.isSent
                  ? const Color(0xFFA7F3D0)
                  : const Color(0xFFFCA5A5),
            ),
          ),
          child: Text(
            log.status.toUpperCase(),
            style: TextStyle(
              color: log.isSent
                  ? const Color(0xFF065F46)
                  : const Color(0xFF991B1B),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // --- Device Linking Modal Bottom Sheet ---

  /// Linking happens on the WhatsApp Numbers screen, where every number
  /// (the Main one and any added later) is linked, shown and disconnected.
  void _showLinkDeviceSheet(BuildContext context) {
    if (controller.isLeader.value) return;
    Get.toNamed(Routes.whatsappNumbers);
  }

  // --- Shared Reusable Section Headers & Tags ---

  Widget _buildSectionHeader({required String title, Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        ?trailing,
      ],
    );
  }

  /// Group or Alumni tag for a directory row, colored like the phonebook card.
  Widget _buildStudentStatusTag(BirthdayStudentModel s) {
    if (controller.isAlumni(s)) {
      return _buildTag(
        icon: Icons.school_rounded,
        text: 'Alumni',
        color: const Color(0xFF9333EA),
      );
    }
    final group = controller.groupFor(s);
    return _buildTag(
      icon: Icons.groups_rounded,
      text: group ?? 'Active',
      color: StudentContactCard.groupColor(group),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color ?? const Color(0xFF64748B)),
          const SizedBox(width: 3.5),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pinned Hero Gradient Header Delegate (Matches StudentLocations & Geofence)
// ---------------------------------------------------------------------------

class _AdminBirthdayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final AdminBirthdayController controller;
  final double topPadding;
  final VoidCallback? onOpenLinkSheet;

  _AdminBirthdayHeaderDelegate({
    required this.controller,
    required this.topPadding,
    this.onOpenLinkSheet,
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
            // Ambient orbs & concentric rings
            CustomPaint(painter: _HeaderOrbPainter()),

            // Top pinned navigation bar (Back, Title, WhatsApp Link, Refresh)
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
                            ? (controller.leaderGroup.value != null ? '${controller.leaderGroup.value} Birthdays' : 'Group Birthdays')
                            : 'Birthday Wishes';
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

                  // WhatsApp quick link button (Admin) or Leader Group Chip (Leader)
                  Obx(() {
                    final isLeader = controller.isLeader.value;
                    if (isLeader) {
                      final group = controller.leaderGroup.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
                            const Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              group != null && group.isNotEmpty
                                  ? '$group Leader'
                                  : 'Leader',
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

                    final isOnline =
                        (controller.dashboard.value?.isWhatsAppConnected ??
                            false) ||
                        controller.connectedPhone.isNotEmpty;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onOpenLinkSheet,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isOnline
                                  ? const Color(0xFF6EE7B7)
                                  : Colors.white.withValues(alpha: 0.28),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOnline
                                    ? Icons.chat_bubble_rounded
                                    : Icons.link_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isOnline ? 'WA Online' : 'Link WA',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
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
                                if (!controller.isLeader.value) {
                                  controller.fetchWhatsAppStatus();
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

            // Expanded Header Content (Dash, Overline, Title, Subtitle, Metric cards)
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
                              ? (group != null ? '$group Celebrants' : 'Group Birthdays')
                              : 'Birthday Wishes';
                          final subtitle = isLeader
                              ? (group != null ? 'Wish $group group members on their special day' : 'Wish your group members on their special day')
                              : 'Automated WhatsApp greetings & hostel celebrants';
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

  /// Frosted summary metric cards in the hero header.
  Widget _buildHeaderMetricCards() {
    final isLeader = controller.isLeader.value;
    final data = controller.dashboard.value;
    final todayCount = data?.todaysBirthdays.length ?? 0;
    final tomorrowCount = data?.tomorrowsBirthdays.length ?? 0;

    if (isLeader) {
      final totalGroupStudents = controller.allStudents.length;
      return Row(
        children: [
          // Today
          Expanded(
            child: _HeaderMetricCard(
              title: 'Today',
              countText: '$todayCount',
              icon: Icons.cake_rounded,
              accentColor: const Color(0xFF38BDF8),
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

          // Template
          Expanded(
            child: _HeaderMetricCard(
              title: 'Template',
              countText: 'Custom',
              icon: Icons.tune_rounded,
              accentColor: const Color(0xFFFBBF24),
              isSelected: controller.selectedTab.value == 2,
              onTap: () => controller.selectedTab.value = 2,
            ),
          ),
          const SizedBox(width: 8),

          // Directory
          Expanded(
            child: _HeaderMetricCard(
              title: 'Directory',
              countText: totalGroupStudents > 0 ? '$totalGroupStudents' : 'View',
              icon: Icons.people_alt_rounded,
              accentColor: const Color(0xFFA78BFA),
              isSelected: controller.selectedTab.value == 3,
              onTap: () {
                controller.selectedTab.value = 3;
                if (controller.allStudents.isEmpty) {
                  controller.fetchStudents();
                }
              },
            ),
          ),
        ],
      );
    }

    final isOnline =
        (data?.isWhatsAppConnected ?? false) ||
        controller.connectedPhone.isNotEmpty;
    final isAuto = controller.isAutoEnabled.value;

    return Row(
      children: [
        // Today
        Expanded(
          child: _HeaderMetricCard(
            title: 'Today',
            countText: '$todayCount',
            icon: Icons.cake_rounded,
            accentColor: const Color(0xFF38BDF8),
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

        // WhatsApp Online / Offline
        Expanded(
          child: _HeaderMetricCard(
            title: isOnline ? 'WA Online' : 'Link WA',
            countText: isOnline ? 'Active' : 'Offline',
            icon: isOnline ? Icons.chat_bubble_rounded : Icons.link_off_rounded,
            accentColor: isOnline
                ? const Color(0xFF34D399)
                : const Color(0xFFFF8A8A),
            highlightAlert: !isOnline,
            isSelected: false,
            onTap: onOpenLinkSheet ?? () {},
          ),
        ),
        const SizedBox(width: 8),

        // Automation Status
        Expanded(
          child: _HeaderMetricCard(
            title: 'Automation',
            countText: isAuto ? 'ON' : 'OFF',
            icon: Icons.bolt_rounded,
            accentColor: isAuto
                ? const Color(0xFFFDE047)
                : const Color(0xFFCBD5E1),
            isSelected: false,
            onTap: () => controller.toggleAutomation(!isAuto),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _AdminBirthdayHeaderDelegate oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.onOpenLinkSheet != onOpenLinkSheet;
  }
}

// ---------------------------------------------------------------------------
// Frosted Summary Metric Card (Matches StudentLocations)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Header Orb Painter (Ambient glow and concentric arcs)
// ---------------------------------------------------------------------------

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

    // Concentric delicate arc rings
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Corner Wave Painter — organic curved wave in the bottom-right of each card
// (matches the operator home screen _CornerWavePainter exactly)
// ---------------------------------------------------------------------------

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
  bool shouldRepaint(covariant _CornerWavePainter oldDelegate) =>
      oldDelegate.color != color;
}
