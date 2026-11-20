import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/models/anniversary/anniversary_models.dart';
import '../../../core/utils/app_snackbar.dart';
import '../controllers/admin_anniversary_controller.dart';

class AdminAnniversaryScreen extends GetView<AdminAnniversaryController> {
  const AdminAnniversaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                _buildSliverAppBar(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTabPillBar(),
                        const SizedBox(height: 18),
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

  // --- Sliver App Bar ---

  Widget _buildSliverAppBar(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      expandedHeight: 140,
      backgroundColor: const Color(0xFF0F172A),
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF881337), // Rose 900
                Color(0xFF0F172A), // Slate 900
              ],
            ),
          ),
          padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      onPressed: () => Get.back(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Parents' Anniversary",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDA4AF).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDA4AF).withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Color(0xFFFECDD3),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Marriage anniversary greetings for Father & Mother',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      onPressed: () => controller.loadDashboard(),
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

  // --- Tab Category Pills ---

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
                  )
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
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

  // --- Active Tab Switcher ---

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
        ...records.map((r) => _buildFamilyAnniversaryCard(context, r, isToday: true)),
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
        ...records.map((r) => _buildFamilyAnniversaryCard(context, r, isToday: false)),
      ],
    );
  }

  // ============================================================
  // FAMILY ANNIVERSARY CARD (BOTH FATHER & MOTHER)
  // ============================================================

  Widget _buildFamilyAnniversaryCard(
    BuildContext context,
    AnniversaryStudentRecord record, {
    required bool isToday,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // 1. Family Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF1F2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
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
                                color: Color(0xFF881337),
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('💍', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            "Student: ${record.name}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Room ${record.room}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Milestone Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    record.yearsMilestoneLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Parents Phone & Details Grid (Father on left, Mother on right)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FATHER CARD
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
                    const SizedBox(width: 12),
                    // MOTHER CARD
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
                const SizedBox(height: 14),

                // 3. Master Bottom Actions
                Row(
                  children: [
                    // WISH BOTH (AUTOMATED BOT)
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: record.hasAnyPhone
                            ? () => controller.wishBoth(record)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.favorite_rounded, size: 16),
                        label: const Text(
                          'Wish Both Parents',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // WISH WITH ANOTHER WHATSAPP NUMBER (DIALOG)
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _showWishWithAnotherNumberSheet(context, record),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.phone_iphone_rounded, size: 16, color: Color(0xFF059669)),
                        label: const Text(
                          'Another No.',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
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

  // --- Sub Card for Father or Mother ---

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
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
          const SizedBox(height: 2),
          Text(
            hasPhone ? phone : 'No phone listed',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: hasPhone ? const Color(0xFF475569) : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),

          // Action buttons: Bot Wish + Device WhatsApp Wish
          Row(
            children: [
              // Wish via Bot
              Expanded(
                child: InkWell(
                  onTap: hasPhone
                      ? () => recipientType == 'father'
                          ? controller.wishFather(record)
                          : controller.wishMother(record)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: hasPhone ? accentColor : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Bot',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: hasPhone ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Wish via Device WhatsApp (Opens WA on device)
              Expanded(
                child: InkWell(
                  onTap: hasPhone
                      ? () => controller.wishViaDeviceWhatsApp(
                            phone: phone,
                            record: record,
                            recipientType: recipientType,
                          )
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: hasPhone ? const Color(0xFF25D366) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 11,
                          color: hasPhone ? Colors.white : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'WA',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: hasPhone ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
                ],
              ),
              const SizedBox(height: 12),

              // Template TextField
              TextField(
                controller: controller.templateController,
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

        // 2. DEDICATED SECTION: WISH VIA ANOTHER WHATSAPP NUMBER
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

              // Phone Number Input
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

              // Message Input
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

              // Dual Actions: Open in My WhatsApp vs Send via Bot
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
                        backgroundColor: const Color(0xFF25D366), // WhatsApp Green
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
      onTap: () {
        final text = controller.templateController.text;
        controller.templateController.text = '$text $tag';
      },
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
  // TAB 3: ANNIVERSARY DIRECTORY
  // ============================================================

  Widget _buildDirectoryTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Bar
        TextField(
          controller: controller.searchController,
          decoration: InputDecoration(
            hintText: 'Search by student, parent, room, phone...',
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Group Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Obx(() => Row(
                children: AdminAnniversaryController.hshGroups.map((g) {
                  final isSel = controller.selectedGroup.value == g;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(g),
                      selected: isSel,
                      onSelected: (_) => controller.selectGroup(g),
                      selectedColor: const Color(0xFF0284C7),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  );
                }).toList(),
              )),
        ),
        const SizedBox(height: 14),

        // List
        Obx(() {
          if (controller.isLoadingStudents.value) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF0284C7)),
              ),
            );
          }

          final list = controller.filteredStudents;
          if (list.isEmpty) {
            return _buildEmptyCelebrantsState(
              title: 'No Matching Records',
              subtitle: 'No parents found matching your search and filter criteria.',
              icon: Icons.search_off_rounded,
              color: const Color(0xFF64748B),
            );
          }

          return Column(
            children: list.map((r) => _buildFamilyAnniversaryCard(context, r, isToday: false)).toList(),
          );
        }),
      ],
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

  // --- Empty State ---

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

  // --- Confirmation & Dialogs ---

  void _confirmSendAllDialog(BuildContext context) {
    Get.defaultDialog(
      title: 'Send All Wishes?',
      titleStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      middleText: "Automated anniversary greetings will be dispatched via WhatsApp to all parents celebrating today.",
      textConfirm: 'Send Now',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: const Color(0xFFE11D48),
      onConfirm: () {
        Get.back();
        controller.sendAllWishesToday();
      },
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
