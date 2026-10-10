import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_routes.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../controllers/phonebook_controller.dart';
import '../models/phonebook_models.dart';
import '../widgets/caller_id_card.dart';

/// Modern Campus Directory & Caller ID Console
class PhonebookScreen extends GetView<PhonebookController> {
  const PhonebookScreen({super.key});

  static Color groupColor(String? group) {
    switch (group?.toLowerCase().trim()) {
      case 'param':
        return const Color(0xFF0284C7);
      case 'pavitra':
        return const Color(0xFF6366F1);
      case 'pulkit':
        return const Color(0xFFEA580C);
      case 'paramanand':
        return const Color(0xFF0D9488);
      case 'alumni':
        return const Color(0xFF9333EA);
      default:
        return const Color(0xFF0284C7);
    }
  }

  static Color groupBgColor(String? group) {
    switch (group?.toLowerCase().trim()) {
      case 'param':
        return const Color(0xFFE0F2FE);
      case 'pavitra':
        return const Color(0xFFEEF2FF);
      case 'pulkit':
        return const Color(0xFFFFEDD5);
      case 'paramanand':
        return const Color(0xFFCCFBF1);
      case 'alumni':
        return const Color(0xFFF3E8FF);
      default:
        return const Color(0xFFE0F2FE);
    }
  }

  void _showStudentContactDetails(BuildContext context, PhonebookStudent student) {
    final isAlumni = student.room == 'Alumni' ||
        student.room == null ||
        student.room!.isEmpty ||
        student.room!.toLowerCase() == 'n/a' ||
        student.room!.toLowerCase() == 'none';
    final gColor = isAlumni ? const Color(0xFF9333EA) : groupColor(student.groupName);
    final gBg = isAlumni ? const Color(0xFFF3E8FF) : groupBgColor(student.groupName);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: SafeArea(
            child: Column(
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: gBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: gColor.withValues(alpha: 0.2)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                        style: TextStyle(
                          color: gColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (isAlumni)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE9D5FF)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.school_rounded, size: 12, color: Color(0xFF7E22CE)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Alumni',
                                        style: TextStyle(
                                          color: Color(0xFF7E22CE),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (student.room != null && student.room!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    'Room ${student.room}',
                                    style: const TextStyle(
                                      color: Color(0xFF334155),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              if (student.groupName != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: groupBgColor(student.groupName),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: groupColor(student.groupName).withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    student.groupName!,
                                    style: TextStyle(
                                      color: groupColor(student.groupName),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              if (student.enrollmentNumber.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    '#${student.enrollmentNumber}',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
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
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'REGISTERED PHONE NUMBERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (student.phones.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No phone numbers registered for this contact.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                    ),
                  )
                else
                  ...student.phones.map((p) {
                    final isWhatsApp = p.label.toLowerCase().contains('whatsapp');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isWhatsApp ? const Color(0xFFECFDF5) : const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isWhatsApp ? Icons.chat_rounded : Icons.phone_rounded,
                              size: 18,
                              color: isWhatsApp ? const Color(0xFF059669) : const Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.phone,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  p.label,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                            tooltip: 'Copy Number',
                            onPressed: () => controller.copyToClipboard(p.phone, p.label),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF059669)),
                            tooltip: 'WhatsApp',
                            onPressed: () {
                              Navigator.pop(ctx);
                              controller.openWhatsApp(p.phone);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.call_rounded, size: 18, color: Color(0xFF0284C7)),
                            tooltip: 'Call Phone',
                            onPressed: () {
                              Navigator.pop(ctx);
                              controller.makeCall(p.phone);
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                if (student.email != null && student.email!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'EMAIL ADDRESS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCFBF1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.email_rounded, size: 18, color: Color(0xFF0D9488)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            student.email!,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                          tooltip: 'Copy Email',
                          onPressed: () => controller.copyToClipboard(student.email!, 'Email'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Get.toNamed(
                        Routes.studentScreenTime,
                        arguments: {
                          'name': student.name,
                          'room': student.room ?? '',
                        },
                      );
                    },
                    icon: const Icon(Icons.phone_android_rounded, size: 18),
                    label: const Text('View Individual Screen Time'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          onRefresh: () => controller.syncNow(),
          color: const Color(0xFF0284C7),
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _PhonebookHeader(controller: controller),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Caller ID Card Widget
                      const CallerIdCard(),
                      const SizedBox(height: 16),

                      // Search Input Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: controller.searchController,
                          onChanged: controller.onSearchChanged,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by name, room, alumni, ID or phone...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF0284C7),
                              size: 22,
                            ),
                            suffixIcon: Obx(() {
                              if (controller.isSearching.value) {
                                return const Padding(
                                  padding: EdgeInsets.all(13),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                );
                              }
                              if (controller.searchText.value.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                                onPressed: controller.clearSearch,
                              );
                            }),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Group / Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Obx(() {
                          return Row(
                            children: PhonebookController.hshGroups.map((g) {
                              final isSelected = controller.selectedGroup.value == g;
                              final isAlumniChip = g.toLowerCase() == 'alumni';
                              final color = isAlumniChip ? const Color(0xFF9333EA) : const Color(0xFF0284C7);

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => controller.selectGroup(g),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                                      decoration: BoxDecoration(
                                        color: isSelected ? color : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected ? color : const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: color.withValues(alpha: 0.25),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isAlumniChip) ...[
                                            Icon(
                                              Icons.school_rounded,
                                              size: 14,
                                              color: isSelected ? Colors.white : const Color(0xFF9333EA),
                                            ),
                                            const SizedBox(width: 5),
                                          ],
                                          Text(
                                            g,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : const Color(0xFF475569),
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Section title
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
                          Obx(() {
                            // Directory contacts count commented out as of now:
                            // final count = controller.students.length;
                            final group = controller.selectedGroup.value;
                            return Text(
                              group == 'All'
                                  ? 'Directory Contacts' // 'Directory Contacts ($count)'
                                  : '$group Contacts',   // '$group Contacts ($count)'
                              style: const TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Student Contact List
              Obx(() {
                if (controller.isLoading.value) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                      ),
                    ),
                  );
                }

                final list = controller.students;
                if (list.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: EmptyState(
                        icon: Icons.person_search_rounded,
                        title: 'No student contacts found',
                        message: controller.searchText.value.isNotEmpty ||
                                controller.selectedGroup.value != 'All'
                            ? 'Try clearing filters or search query.'
                            : 'Tap Sync to download contacts from the live campus directory.',
                        actionLabel: 'Sync Now',
                        onAction: () => controller.syncNow(),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final student = list[index];
                      final card = _StudentPhonebookCard(
                        student: student,
                        onTap: () => _showStudentContactDetails(context, student),
                        onCall: (phone) => controller.makeCall(phone),
                        onWhatsApp: (phone) => controller.openWhatsApp(phone),
                      );

                      if (index < 8) {
                        return StaggeredSlideFade(
                          index: index,
                          duration: const Duration(milliseconds: 280),
                          slideOffset: 12.0,
                          child: card,
                        );
                      }
                      return card;
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deep navy header with luminous arcs, hostel photo overlay, sync action and status pills.
class _PhonebookHeader extends StatelessWidget {
  final PhonebookController controller;

  const _PhonebookHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');

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
                        if (Navigator.canPop(context)) ...[
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
                          const SizedBox(width: 14),
                        ],

                        // Title & overline
                        Expanded(
                          child: Column(
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
                              const SizedBox(height: 7),
                              Text(
                                'CAMPUS DIRECTORY & CALLER ID',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Student Phonebook',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Residents, alumni & parent caller records',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Sync directory button
                        Obx(() {
                          final isSyncing = controller.isSyncing.value;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isSyncing ? null : () => controller.syncNow(),
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: isSyncing
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.sync_rounded,
                                        color: Colors.white,
                                        size: 21,
                                      ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Frosted status pills
                    Obx(() {
                      // Directory contacts count pill commented out as of now:
                      // final count = controller.totalCachedCount.value;
                      final syncDate = controller.lastSync.value;
                      final callerOn = controller.callerId.value.isWorking;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            // _headerPill(
                            //   icon: Icons.groups_rounded,
                            //   label: '$count Cached',
                            // ),
                            // const SizedBox(width: 8),
                            _headerPill(
                              icon: Icons.cloud_done_rounded,
                              label: syncDate != null
                                  ? 'Synced ${dateFormat.format(syncDate)}'
                                  : 'Not synced yet',
                            ),
                            const SizedBox(width: 8),
                            _headerPill(
                              icon: callerOn ? Icons.phone_callback_rounded : Icons.phone_disabled_rounded,
                              label: callerOn ? 'Caller ID Active' : 'Caller ID Inactive',
                              iconColor: callerOn ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                            ),
                          ],
                        ),
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

  Widget _headerPill({
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
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
          Icon(
            icon,
            size: 13.5,
            color: iconColor ?? Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

/// Modern student contact card matching the Operator console card design
class _StudentPhonebookCard extends StatelessWidget {
  final PhonebookStudent student;
  final VoidCallback onTap;
  final ValueChanged<String> onCall;
  final ValueChanged<String> onWhatsApp;

  const _StudentPhonebookCard({
    required this.student,
    required this.onTap,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final primary = student.primaryPhone;
    final isAlumni = student.room == 'Alumni' ||
        student.room == null ||
        student.room!.isEmpty ||
        student.room!.toLowerCase() == 'n/a' ||
        student.room!.toLowerCase() == 'none';

    final gColor = isAlumni ? const Color(0xFF9333EA) : PhonebookScreen.groupColor(student.groupName);
    final gBg = isAlumni ? const Color(0xFFF3E8FF) : PhonebookScreen.groupBgColor(student.groupName);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: gBg,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: gColor.withValues(alpha: 0.2)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                        style: TextStyle(
                          color: gColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (isAlumni)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE9D5FF)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.school_rounded, size: 11, color: Color(0xFF7E22CE)),
                                      SizedBox(width: 3.5),
                                      Text(
                                        'Alumni',
                                        style: TextStyle(
                                          color: Color(0xFF7E22CE),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (student.room != null && student.room!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    'Room ${student.room}',
                                    style: const TextStyle(
                                      color: Color(0xFF334155),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              if (student.groupName != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: PhonebookScreen.groupBgColor(student.groupName),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: PhonebookScreen.groupColor(student.groupName).withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    student.groupName!,
                                    style: TextStyle(
                                      color: PhonebookScreen.groupColor(student.groupName),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              if (student.enrollmentNumber.isNotEmpty)
                                Text(
                                  '#${student.enrollmentNumber}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Primary phone & quick communication action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          size: 15,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          primary,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (student.phones.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+${student.phones.length - 1} more',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (primary != 'No Phone')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onWhatsApp(primary),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: const Icon(
                                  Icons.chat_rounded,
                                  size: 16,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onCall(primary),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.call_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
