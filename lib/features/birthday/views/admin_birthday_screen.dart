import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/models/birthday/birthday_models.dart';
import '../../../core/utils/app_snackbar.dart';
import '../controllers/admin_birthday_controller.dart';

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
              await controller.fetchWhatsAppStatus();
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
                    onOpenLinkSheet: () => _showLinkDeviceSheet(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. WhatsApp Connection Alert Banner (if disconnected)
                        if (!isOnline) ...[
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
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
              label: 'Template Studio',
              icon: Icons.tune_rounded,
              isSelected: current == 2,
              activeColor: const Color(0xFFD97706),
            ),
            // const SizedBox(width: 8),
            // _buildTabPill(
            //   index: 3,
            //   label: 'Directory',
            //   icon: Icons.people_alt_rounded,
            //   isSelected: current == 3,
            //   activeColor: const Color(0xFF6366F1),
            // ),
            const SizedBox(width: 8),
            _buildTabPill(
              index: 4,
              label: 'Logs & Test',
              icon: Icons.history_rounded,
              isSelected: current == 4,
              activeColor: const Color(0xFF0284C7),
            ),
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
      switch (controller.selectedTab.value) {
        case 0:
          return _buildTodayTab(context, data);
        case 1:
          return _buildTomorrowTab(context, data);
        case 2:
          return _buildTemplateStudioTab(data);
        case 3:
          return _buildDirectoryTab();
        case 4:
          return _buildLogsAndTestTab(context, data);
        default:
          return _buildTodayTab(context, data);
      }
    });
  }

  // --- Tab 0: Today's Celebrants ---

  Widget _buildTodayTab(BuildContext context, BirthdayDashboardData? data) {
    final list = data?.todaysBirthdays ?? [];

    if (list.isEmpty) {
      return _buildEmptyStateCard(
        icon: Icons.cake_outlined,
        iconColor: const Color(0xFFD97706),
        iconBgColor: const Color(0xFFFEF3C7),
        title: 'No Birthdays Today',
        subtitle:
            "No registered students celebrate their birthday today. Check tomorrow's tab for upcoming hostel celebrants.",
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
                    const Text(
                      'Automated WhatsApp wishes scheduled via linked device.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Obx(() {
                final isBusy = controller.isTriggering.value;
                final alreadySent = controller.hasSentToday.value;
                final isLinked = controller.isWhatsAppLinked;

                return ElevatedButton(
                  onPressed: isBusy
                      ? null
                      : () {
                          if (!isLinked) {
                            AppSnackbar.warning(
                              'WhatsApp Not Connected',
                              'Please link your WhatsApp device first before sending birthday wishes.',
                            );
                            _showLinkDeviceSheet(context);
                            return;
                          }
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
                              : (isLinked ? 'Send All' : 'Connect WA'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildSectionHeader(title: "Today's Celebrants (${list.length})"),
        const SizedBox(height: 12),

        ...list.map((s) => _buildStudentCelebrantCard(s, isToday: true)),
      ],
    );
  }

  // --- Tab 1: Tomorrow's Celebrants ---

  Widget _buildTomorrowTab(BuildContext context, BirthdayDashboardData? data) {
    final list = data?.tomorrowsBirthdays ?? [];

    if (list.isEmpty) {
      return _buildEmptyStateCard(
        icon: Icons.event_available_rounded,
        iconColor: const Color(0xFF059669),
        iconBgColor: const Color(0xFFECFDF5),
        title: 'No Birthdays Tomorrow',
        subtitle: 'There are no student birthdays scheduled for tomorrow.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(title: "Tomorrow's Celebrants (${list.length})"),
        const SizedBox(height: 12),
        ...list.map((s) => _buildStudentCelebrantCard(s, isToday: false)),
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
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: bgTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
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
                    // Room (skip N/A — day scholars need no chip)
                    if (s.room != 'N/A')
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
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
        _buildSectionHeader(title: 'Custom Wish Template'),
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
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _varChip('{first_name}', 'First Name'),
                  _varChip('{student_name}', 'Full Name'),
                  _varChip('{room}', 'Room No'),
                  _varChip('{student_code}', 'Student Code'),
                ],
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

              // Live Preview Mockup
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECE5DD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD1D7DB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.chat_rounded,
                          size: 14,
                          color: Color(0xFF075E54),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'WhatsApp Preview Mockup',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF075E54),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        controller.templateController.text
                            .replaceAll('{first_name}', 'Rahul')
                            .replaceAll('{student_name}', 'Rahul Sharma')
                            .replaceAll('{name}', 'Rahul Sharma')
                            .replaceAll('{room}', '306')
                            .replaceAll('{room_number}', '306')
                            .replaceAll('{student_code}', 'HSH-105'),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
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

  // --- Tab 3: Directory ---

  Widget _buildDirectoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(title: 'Hostel Birthday Directory'),
        const SizedBox(height: 12),

        // Search Bar styled like StudentLocationsScreen
        Container(
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

          final list = controller.allStudents;
          if (list.isEmpty) {
            return _buildEmptyStateCard(
              icon: Icons.person_search_rounded,
              iconColor: const Color(0xFF0284C7),
              iconBgColor: const Color(0xFFE0F2FE),
              title: 'No Students Found',
              subtitle:
                  'Tap Search to query and load student directory records.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Showing ${list.length} Students (Active & Alumni)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              ...list
                  .take(100)
                  .map(
                    (s) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
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
                                    _buildTag(
                                      icon: Icons.meeting_room_rounded,
                                      text: s.room == 'N/A'
                                          ? 'Room N/A'
                                          : 'Room ${s.room}',
                                      color: s.room == 'N/A'
                                          ? const Color(0xFFD97706)
                                          : null,
                                    ),
                                    if (s.dob.isNotEmpty)
                                      _buildTag(
                                        icon: Icons.cake_outlined,
                                        text: s.dob,
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
                              onPressed: () => controller.callPhone(s.phone),
                            ),
                          if (s.whatsappNumber.isNotEmpty || s.phone.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.chat_rounded,
                                size: 18,
                                color: Color(0xFF059669),
                              ),
                              onPressed: () => controller.sendWishToStudent(s),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        }),
      ],
    );
  }

  // --- Tab 4: Logs & Sandbox ---

  Widget _buildLogsAndTestTab(
    BuildContext context,
    BirthdayDashboardData? data,
  ) {
    final logs = data?.recentLogs ?? [];

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
        _buildSectionHeader(title: 'Recent Dispatch Logs (${logs.length})'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No delivery logs yet.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 14, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final log = logs[index];
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
                            log.isSent
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
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
                              Text(
                                log.studentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${log.room == "N/A" ? "Room N/A" : "Room ${log.room}"} • ${log.phone} • ${log.wishDate}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
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
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Device Linking Modal Bottom Sheet ---

  void _showLinkDeviceSheet(BuildContext context) {
    controller.startLinkingPolling();
    if (controller.waQr.isEmpty) {
      controller.loadQrCode();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Obx(() {
            final isConnected = controller.connectedPhone.isNotEmpty;
            final isPairing = controller.isPairingLoading.value;
            final code = controller.pairingCode.value;
            final qr = controller.waQr.value;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Color(0xFF059669),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WhatsApp Device Linking',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            isConnected
                                ? 'Connected as +${controller.connectedPhone.value}'
                                : 'Link your number to dispatch greetings',
                            style: TextStyle(
                              fontSize: 12,
                              color: isConnected
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF64748B),
                              fontWeight: isConnected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 16),

                if (isConnected) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF059669),
                          size: 44,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'WhatsApp is Online & Linked',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Automated birthday wishes will be sent from +${controller.connectedPhone.value}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Disconnect WhatsApp?'),
                          content: const Text(
                            'This will unlink your device session. You will need to link it again to send greetings.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                              child: const Text(
                                'Disconnect',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await controller.disconnectWhatsAppSession();
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text(
                      'Unlink / Disconnect Session',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ] else ...[
                  // Not Connected State
                  const Text(
                    'Option 1: Link with Phone Number (Recommended)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'No camera required. Enter your WhatsApp number to get an 8-character pairing code.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller.pairPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'WhatsApp Phone Number',
                            hintText: 'e.g. 919876543210',
                            prefixIcon: const Icon(
                              Icons.phone_rounded,
                              color: Color(0xFF0284C7),
                              size: 18,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: isPairing
                            ? null
                            : controller.requestPairingCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isPairing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Get Code',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                  ),

                  // Display Pairing Code
                  if (code.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'YOUR 8-CHARACTER PAIRING CODE',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E40AF),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                code,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  color: Color(0xFF1D4ED8),
                                ),
                                tooltip: 'Copy Code',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: code));
                                  Get.snackbar(
                                    'Copied',
                                    'Pairing code copied to clipboard',
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'How to link on your phone:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '1. Open WhatsApp > Settings > Linked Devices > Link a Device',
                                  style: TextStyle(fontSize: 11),
                                ),
                                Text(
                                  '2. Tap "Link with phone number instead" at the bottom',
                                  style: TextStyle(fontSize: 11),
                                ),
                                Text(
                                  '3. Enter the 8-character code shown above',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Option 2: Always visible Scan QR Code section
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Option 2: Scan QR Code',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (controller.isCheckingStatus.value)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0284C7),
                          ),
                        )
                      else
                        InkWell(
                          onTap: controller.loadQrCode,
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 14,
                                  color: Color(0xFF0284C7),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Refresh QR',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Scan this QR code using WhatsApp > Linked Devices > Link a Device:',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (qr.isNotEmpty) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: QrImageView(
                          data: qr,
                          version: QrVersions.auto,
                          size: 190.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Point your camera at this QR code. Will link automatically.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: controller.isCheckingStatus.value
                            ? const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Generating WhatsApp QR Code...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 44,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'QR code not loaded',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: controller.loadQrCode,
                                    icon: const Icon(
                                      Icons.qr_code_scanner_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Load / Show QR Code',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
              ],
            );
          }),
        ),
      ),
    ).whenComplete(() {
      controller.stopLinkingPolling();
    });
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
  final VoidCallback onOpenLinkSheet;

  _AdminBirthdayHeaderDelegate({
    required this.controller,
    required this.topPadding,
    required this.onOpenLinkSheet,
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
                      child: const Text(
                        'Birthday Wishes',
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

                  // WhatsApp quick link button
                  Obx(() {
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
                                controller.fetchWhatsAppStatus();
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
                        Text(
                          'AUTOMATED GREETINGS & CELEBRANTS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Birthday Wishes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Automated WhatsApp greetings & hostel celebrants',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
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

  /// 4 Frosted summary metric cards in the hero header.
  Widget _buildHeaderMetricCards() {
    final data = controller.dashboard.value;
    final todayCount = data?.todaysBirthdays.length ?? 0;
    final tomorrowCount = data?.tomorrowsBirthdays.length ?? 0;
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
            onTap: onOpenLinkSheet,
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
        oldDelegate.topPadding != topPadding;
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
