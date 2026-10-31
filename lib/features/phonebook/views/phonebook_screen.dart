import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../../shared/widgets/student_contact_card.dart';
import '../controllers/phonebook_controller.dart';
import '../models/phonebook_models.dart';
import '../widgets/alpha_scroll_rail.dart';
import '../widgets/caller_id_card.dart';
import 'student_detail_screen.dart';

/// Modern Campus Directory & Caller ID Console
class PhonebookScreen extends GetView<PhonebookController> {
  final bool showBackButton;
  const PhonebookScreen({super.key, this.showBackButton = true});

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

  void _showStudentContactDetails(
    BuildContext context,
    PhonebookStudent student,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StudentDetailScreen(student: student)),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // The DraggableScrollableSheet below owns the drag, so a fast swipe
      // down from anywhere (handle, title or list) dismisses the sheet.
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
                              'Filter & Sort Students',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Refine by wings, floors, residence, and records',
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
                      // 1. WING / GROUP
                      _filterSectionHeader('HOSTEL WING / GROUP', Icons.apartment_rounded),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PhonebookController.hshGroups.map((g) {
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

                      // 2. FLOOR SELECTOR
                      _filterSectionHeader('HOSTEL FLOOR', Icons.layers_rounded),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PhonebookController.floorOptions.map((f) {
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
                        children: PhonebookController.statusOptions.map((s) {
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

                      // 4. ATTRIBUTES & PROFILE DATA
                      _filterSectionHeader('PROFILE ATTRIBUTES & RECORDS', Icons.check_circle_outline_rounded),
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
                              icon: Icons.cake_outlined,
                              iconColor: const Color(0xFFD97706),
                              title: 'Has Date of Birth (DOB)',
                              subtitle: 'Show students with registered birthday info',
                              value: controller.onlyWithDob.value,
                              onChanged: controller.toggleOnlyWithDob,
                            ),
                            const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                            _toggleRow(
                              icon: Icons.family_restroom_rounded,
                              iconColor: const Color(0xFF059669),
                              title: 'Has Parent Contact Phone',
                              subtitle: 'Show students with Father or Mother numbers',
                              value: controller.onlyWithParents.value,
                              onChanged: controller.toggleOnlyWithParents,
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
                              icon: Icons.home_rounded,
                              iconColor: const Color(0xFF0284C7),
                              title: 'Has Permanent Address',
                              subtitle: 'Show students with hometown/permanent address',
                              value: controller.onlyWithAddress.value,
                              onChanged: controller.toggleOnlyWithAddress,
                            ),
                            const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                            _toggleRow(
                              icon: Icons.fingerprint_rounded,
                              iconColor: const Color(0xFF6366F1),
                              title: 'Has Aadhar Number',
                              subtitle: 'Show students with registered 12-digit Aadhar',
                              value: controller.onlyWithAadhar.value,
                              onChanged: controller.toggleOnlyWithAadhar,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 5. SORT ORDER
                      _filterSectionHeader('SORT STUDENTS BY', Icons.sort_by_alpha_rounded),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PhonebookController.sortOptions.map((s) {
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
                      final count = controller.students.length;
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

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        controller.checkFirstTimeCallerId(() {
          if (context.mounted) {
            CallerIdBottomSheet.show(context);
          }
        });
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        bottomNavigationBar: Obx(() {
          if (!controller.isSelectionMode.value) return const SizedBox.shrink();
          final count = controller.selectedCount;
          final allSelected = count == controller.students.length && count > 0;

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: controller.toggleSelectAll,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Icon(
                              allSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: const Color(0xFF0284C7),
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              allSelected ? 'Deselect All' : 'Select All',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count Selected',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0284C7)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        tooltip: 'Exit Selection',
                        onPressed: controller.exitSelectionMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Share to Any App (System Share Sheet)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: count > 0 ? controller.shareSelectedStudents : null,
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Share directly to WhatsApp
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: count > 0 ? controller.shareSelectedToWhatsApp : null,
                          icon: const Icon(Icons.chat_rounded, size: 18),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Copy
                      IconButton.filledTonal(
                        onPressed: count > 0 ? controller.copySelectedDetails : null,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Copy to Clipboard',
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => controller.syncNow(),
              color: const Color(0xFF0284C7),
              backgroundColor: Colors.white,
              child: CustomScrollView(
                controller: controller.listScrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _PhonebookHeaderDelegate(
                  controller: controller,
                  topPadding: MediaQuery.of(context).padding.top,
                  showBackButton: showBackButton,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search & Filter Launcher Bar
                      Row(
                        children: [
                          Expanded(
                            child: Container(
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
                                  hintText: 'Search student, room, parent, aadhar...',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13.5,
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
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                      onPressed: controller.clearSearch,
                                    );
                                  }),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
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
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showFilterBottomSheet(context),
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: count > 0 ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
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

                      // Group / Wing Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Obx(() {
                          return Row(
                            children: PhonebookController.hshGroups.map((g) {
                              final isSelected = controller.selectedGroup.value == g;
                              final isAlumniChip = g.toLowerCase() == 'alumni';
                              final color = isAlumniChip
                                  ? const Color(0xFF9333EA)
                                  : const Color(0xFF0284C7);

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => controller.selectGroup(g),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7.5,
                                      ),
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
                      const SizedBox(height: 16),
// Section title with live count
                      Obx(() {
                        final count = controller.students.length;
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
                              'STUDENT CONTACTS ($count)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF475569),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Student List Sliver
              Obx(() {
                if (controller.isLoading.value) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  );
                }

                final list = controller.students;
                if (list.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 36,
                        horizontal: 20,
                      ),
                      child: EmptyState(
                        icon: Icons.person_search_rounded,
                        title: 'No student contacts found',
                        message:
                            controller.searchText.value.isNotEmpty ||
                                controller.activeFilterCount > 0
                            ? 'Try clearing active filters or modifying your search query.'
                            : 'Tap Sync to download contacts from the live campus directory.',
                        actionLabel: controller.activeFilterCount > 0 ? 'Clear Filters' : 'Sync Now',
                        onAction: controller.activeFilterCount > 0 ? controller.resetAllFilters : () => controller.syncNow(),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                  // SuperSliverList (not SliverList) so the A-Z rail can jump far without
                  // building every card in between.
                  sliver: SuperSliverList.builder(
                    listController: controller.listController,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final student = list[index];
                      final isSelected = controller.isStudentSelected(student.id);
                      final isSelectionMode = controller.isSelectionMode.value;

                      final card = _StudentPhonebookCard(
                        student: student,
                        isSelected: isSelected,
                        isSelectionMode: isSelectionMode,
                        onTap: () {
                          if (isSelectionMode) {
                            controller.toggleSelectStudent(student.id);
                          } else {
                            _showStudentContactDetails(context, student);
                          }
                        },
                        onLongPress: () {
                          if (!isSelectionMode) {
                            controller.startSelectionMode(student.id);
                          } else {
                            controller.toggleSelectStudent(student.id);
                          }
                        },
                        onCall: (phone) => controller.makeCall(phone),
                        onWhatsApp: (phone) => controller.openWhatsApp(phone),
                        onShare: () => controller.shareStudent(student),
                      );

                      final isNameSort = controller.selectedSort.value == 'Name (A-Z)' &&
                          controller.searchText.value.isEmpty;
                      final studentLetter = PhonebookController.letterOf(student.name);
                      // Use the controller's index so each letter's header appears once,
                      // even when '#' names aren't contiguous in the sort order.
                      final isFirstOfLetter = isNameSort &&
                          (student.isAlumni
                                  ? controller.alumniAlphaIndex
                                  : controller.alphaIndex)[studentLetter] ==
                              index;

                      Widget item = card;
                      if (isFirstOfLetter) {
                        item = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLetterSectionHeader(studentLetter),
                            card,
                          ],
                        );
                      }

                      // Gap between cards (the builder has no separators, so item index == student index).
                      if (index < list.length - 1) {
                        item = Padding(padding: const EdgeInsets.only(bottom: 10), child: item);
                      }

                      if (index < 8) {
                        return StaggeredSlideFade(
                          index: index,
                          duration: const Duration(milliseconds: 280),
                          slideOffset: 12.0,
                          child: item,
                        );
                      }
                      return item;
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        // Alphabet scroll rail — positioned exclusively in the card list space
        Obx(() {
          final showRail =
              controller.searchText.value.isEmpty &&
              controller.railLetters.length > 1 &&
              controller.selectedSort.value == 'Name (A-Z)' &&
              !controller.isLoading.value &&
              controller.students.isNotEmpty;
          if (!showRail) return const SizedBox.shrink();

          final topPad = MediaQuery.of(context).padding.top;
          final bottomPad = MediaQuery.of(context).padding.bottom;

          return Positioned(
            right: 4,
            top: topPad + 68.0, // Strictly below pinned appbar header
            bottom: bottomPad + 24.0, // Above bottom navigation edge
            child: Align(
              alignment: Alignment.centerRight,
              child: AlphaScrollRail(
                alphaIndex: controller.railLetters,
                // Next frame, so the menu doesn't open in the same frame as the
                // rail's own release rebuild.
                onLetterReleased: (letter, position) =>
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _askLetterGroup(context, letter, position),
                    ),
                onLetterSelected: (letter, {isDragging = false}) =>
                    controller.scrollToLetter(letter, isDragging: isDragging),
              ),
            ),
          );
        }),
      ],
        ),
      ),
    );
  }

  /// After a letter is picked on the rail, lets the user choose Students or
  /// Alumni when that letter exists in both; the jump is then made there.
  Future<void> _askLetterGroup(BuildContext context, String letter, Offset position) async {
    if (!controller.letterInBothGroups(letter)) return;
    final size = MediaQuery.sizeOf(context);
    final choice = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx - 160,
        position.dy - 48,
        size.width - position.dx,
        size.height - position.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem<bool>(
          value: false,
          child: Row(children: [
            const Icon(Icons.meeting_room_rounded, size: 18, color: Color(0xFF0284C7)),
            const SizedBox(width: 10),
            Text('Students · $letter'),
          ]),
        ),
        PopupMenuItem<bool>(
          value: true,
          child: Row(children: [
            const Icon(Icons.school_rounded, size: 18, color: Color(0xFF9333EA)),
            const SizedBox(width: 10),
            Text('Alumni · $letter'),
          ]),
        ),
      ],
    );
    if (choice != null) {
      HapticFeedback.selectionClick();
      controller.scrollToLetter(letter, alumni: choice, chosen: true);
    }
  }

  Widget _buildLetterSectionHeader(String letter) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0284C7).withValues(alpha: 0.12),
            const Color(0xFF0284C7).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFF0284C7),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Students starting with "$letter"',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0369A1),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhonebookHeaderDelegate extends SliverPersistentHeaderDelegate {
  final PhonebookController controller;
  final double topPadding;
  final bool showBackButton;

  _PhonebookHeaderDelegate({
    required this.controller,
    required this.topPadding,
    this.showBackButton = true,
  });

  @override
  double get minExtent => topPadding + 60.0;

  @override
  double get maxExtent => topPadding + 158.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');
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
            CustomPaint(painter: _HeaderOrbPainter()),

            // Top pinned navigation bar (Back button, Collapsed title, Sync button)
            Positioned(
              top: topPadding + 6,
              left: 16,
              right: 16,
              height: 46,
              child: Row(
                children: [
                  if (showBackButton && Navigator.canPop(context)) ...[
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
                  ],

                  // Pinned title
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: const Text(
                        'Student Phonebook',
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

                  // Incoming Caller ID button (connect / status)
                  Obx(() {
                    final status = controller.callerId.value;
                    final isWorking = status.isWorking;
                    final isSupported = status.supported;

                    final Color bg = isWorking
                        ? const Color(0xFF10B981).withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.16);
                    final Color border = isWorking
                        ? const Color(0xFF34D399).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.25);
                    final Color iconColor = isWorking
                        ? const Color(0xFF34D399)
                        : (isSupported ? Colors.white : Colors.white60);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => CallerIdBottomSheet.show(context),
                        borderRadius: BorderRadius.circular(24),
                        child: Tooltip(
                          message: isWorking
                              ? 'Caller ID: Active'
                              : (isSupported
                                  ? 'Caller ID: Inactive (Tap to connect)'
                                  : 'Caller ID unavailable'),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: bg,
                              shape: BoxShape.circle,
                              border: Border.all(color: border, width: 1),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  isWorking
                                      ? Icons.phone_in_talk_rounded
                                      : Icons.phone_callback_rounded,
                                  color: iconColor,
                                  size: 20,
                                ),
                                Positioned(
                                  top: 9,
                                  right: 9,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: isWorking
                                          ? const Color(0xFF10B981)
                                          : (isSupported
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF94A3B8)),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF032B4F),
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),

                  // Sync directory button
                  Obx(() {
                    final isSyncing = controller.isSyncing.value;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isSyncing ? null : () => controller.syncNow(),
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
                          child: isSyncing
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.sync_rounded,
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

            // Hero expanded text & status pills
            Positioned(
              left: 20,
              right: 20,
              bottom: 22,
              child: Opacity(
                opacity: expandedOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'STUDENT DIRECTORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Hostel Phonebook',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Obx(() {
                      final sync = controller.lastSync.value;
                      final count = controller.totalCachedCount.value;

                      return Wrap(
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
                                const Icon(Icons.people_alt_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  '$count Verified Contacts',
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history_rounded, size: 13, color: Colors.white70),
                                const SizedBox(width: 5),
                                Text(
                                  sync != null ? dateFormat.format(sync) : 'Never synced',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
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

class _HeaderOrbPainter extends CustomPainter {
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

/// Student contact card in directory view, using shared [StudentContactCard].
class _StudentPhonebookCard extends StatelessWidget {
  final PhonebookStudent student;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<String> onCall;
  final ValueChanged<String> onWhatsApp;
  final VoidCallback? onShare;

  const _StudentPhonebookCard({
    required this.student,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    this.onLongPress,
    required this.onCall,
    required this.onWhatsApp,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return StudentContactCard(
      name: student.name,
      room: student.room,
      groupName: student.groupName,
      bankCode: student.bankCode,
      dobText: student.hasDob
          ? '${student.formattedDob}${student.ageText.isNotEmpty ? " (${student.ageText})" : ""}'
          : null,
      primaryPhone: student.primaryPhone,
      alternatePhonesCount:
          student.phones.length > 1 ? student.phones.length - 1 : 0,
      whatsappNumber: student.whatsappNumber,
      isAlumni: student.isAlumni,
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
      onTap: onTap,
      onLongPress: onLongPress,
      onCall: onCall,
      onWhatsApp: onWhatsApp,
      onShare: onShare,
      margin: EdgeInsets.zero,
    );
  }
}
