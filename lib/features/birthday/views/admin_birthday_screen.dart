import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/birthday/birthday_models.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/status_badge.dart';
import '../controllers/admin_birthday_controller.dart';

class AdminBirthdayScreen extends GetView<AdminBirthdayController> {
  const AdminBirthdayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: Obx(() {
        final data = controller.dashboard.value;
        final isLoading = controller.isLoading.value;
        final error = controller.error.value;

        if (isLoading && data == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (error.isNotEmpty && data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.errorRed),
                  const SizedBox(height: AppDimens.gapMd),
                  Text(error, textAlign: TextAlign.center, style: AppTextStyles.bodyMd),
                  const SizedBox(height: AppDimens.gapLg),
                  ElevatedButton(
                    onPressed: controller.loadDashboard,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        return AppRefreshIndicator(
          onRefresh: controller.loadDashboard,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            slivers: [
              _buildHeader(context, data),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTabBar(),
                      const SizedBox(height: AppDimens.gapLg),
                      _buildActiveTabContent(data),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeader(BuildContext context, BirthdayDashboardData? data) {
    final isOnline = data?.isWhatsAppConnected ?? false;
    final sender = data?.senderPhone;

    return SliverGradientHeader(
      expandedHeight: 130,
      overline: 'Automated Greetings & Celebrants',
      title: 'Birthday Wishes',
      titleStyle: AppTextStyles.headline.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: controller.loadDashboard,
        ),
      ],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFF10B981).withValues(alpha: 0.25)
                  : Colors.red.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              border: Border.all(
                color: isOnline ? const Color(0xFF10B981) : Colors.redAccent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: isOnline ? const Color(0xFF10B981) : Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline
                      ? (sender != null ? 'WA Online: +$sender' : 'WhatsApp Online')
                      : 'WhatsApp Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Obx(
            () => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Auto-Dispatch',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: controller.isAutoEnabled.value,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: controller.toggleAutomation,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Obx(() {
      final current = controller.selectedTab.value;
      final todayCount = controller.dashboard.value?.todaysBirthdays.length ?? 0;
      final tomorrowCount = controller.dashboard.value?.tomorrowsBirthdays.length ?? 0;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tabButton(0, 'Today ($todayCount)', Icons.cake_rounded, current == 0),
            const SizedBox(width: 8),
            _tabButton(1, 'Tomorrow ($tomorrowCount)', Icons.event_rounded, current == 1),
            const SizedBox(width: 8),
            _tabButton(2, 'Template Studio', Icons.tune_rounded, current == 2),
            const SizedBox(width: 8),
            _tabButton(3, 'Directory', Icons.people_alt_rounded, current == 3),
            const SizedBox(width: 8),
            _tabButton(4, 'Logs & Test', Icons.history_rounded, current == 4),
          ],
        ),
      );
    });
  }

  Widget _tabButton(int index, String label, IconData icon, bool isSelected) {
    return InkWell(
      onTap: () {
        controller.selectedTab.value = index;
        if (index == 3 && controller.allStudents.isEmpty) {
          controller.fetchStudents();
        }
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(BirthdayDashboardData? data) {
    return Obx(() {
      switch (controller.selectedTab.value) {
        case 0:
          return _buildTodayTab(data);
        case 1:
          return _buildTomorrowTab(data);
        case 2:
          return _buildTemplateStudioTab(data);
        case 3:
          return _buildDirectoryTab();
        case 4:
          return _buildLogsAndTestTab(data);
        default:
          return _buildTodayTab(data);
      }
    });
  }

  Widget _buildTodayTab(BirthdayDashboardData? data) {
    final list = data?.todaysBirthdays ?? [];

    if (list.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cake_outlined, size: 32, color: Color(0xFFD97706)),
              ),
              const SizedBox(height: AppDimens.gapLg),
              const Text(
                'No Birthdays Today',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                "No registered students have their birthday today. Check tomorrow's tab for upcoming celebrants.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action card
        Container(
          padding: const EdgeInsets.all(AppDimens.gapMd),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.celebration_rounded, color: Colors.white, size: 28),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${list.length} Birthday Celebrant${list.length > 1 ? "s" : ""} Today!',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Ready to send celebratory greetings via WhatsApp.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Obx(
                () => ElevatedButton(
                  onPressed: controller.isTriggering.value ? null : controller.triggerAllToday,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF047857),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: controller.isTriggering.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF047857)),
                        )
                      : const Text('Send All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapLg),
        ...list.map((s) => _buildStudentCelebrantCard(s, isToday: true)),
      ],
    );
  }

  Widget _buildTomorrowTab(BirthdayDashboardData? data) {
    final list = data?.tomorrowsBirthdays ?? [];

    if (list.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_available_rounded, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: AppDimens.gapMd),
              const Text(
                'No Birthdays Tomorrow',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'There are no birthdays scheduled for tomorrow.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
          child: Text(
            '${list.length} Student${list.length > 1 ? "s" : ""} turning a year older tomorrow:',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        ...list.map((s) => _buildStudentCelebrantCard(s, isToday: false)),
      ],
    );
  }

  Widget _buildStudentCelebrantCard(BirthdayStudentModel s, {required bool isToday}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
      child: AppCard(
        padding: const EdgeInsets.all(AppDimens.gapMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFFEF3C7),
                  child: Text(
                    s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: AppDimens.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.room == 'N/A' ? 'Room N/A' : 'Room ${s.room}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ),
                          if (s.studentCode.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              'ID: ${s.studentCode}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (isToday)
                  StatusBadge(
                    label: s.alreadySentToday ? 'Sent Today' : 'Pending',
                    color: s.alreadySentToday ? AppColors.successGreen : AppColors.warningOrange,
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.gapMd),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppDimens.gapSm),
            Row(
              children: [
                if (s.dob.isNotEmpty) ...[
                  const Icon(Icons.cake_outlined, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 4),
                  Text(s.dob, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                ] else
                  const Spacer(),
                if (s.phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, size: 18, color: AppColors.primary),
                    tooltip: 'Call Phone',
                    onPressed: () => controller.callPhone(s.phone),
                  ),
                if (s.whatsappNumber.isNotEmpty || s.phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_rounded, size: 18, color: Color(0xFF10B981)),
                    tooltip: 'WhatsApp Message',
                    onPressed: () => controller.openWhatsApp(
                      s.whatsappNumber.isNotEmpty ? s.whatsappNumber : s.phone,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateStudioTab(BirthdayDashboardData? data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppDimens.gapLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Automation & Delivery Setup',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppDimens.gapMd),

              // Time picker
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppDimens.gapMd),
                  const Expanded(
                    child: Text('Scheduled Daily Send Time (IST)', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Obx(
                    () => ActionChip(
                      label: Text(controller.sendTime.value, style: const TextStyle(fontWeight: FontWeight.w700)),
                      avatar: const Icon(Icons.edit, size: 14),
                      onPressed: () async {
                        final parts = controller.sendTime.value.split(':');
                        final initial = TimeOfDay(
                          hour: int.tryParse(parts.first) ?? 8,
                          minute: int.tryParse(parts.last) ?? 0,
                        );
                        final picked = await showTimePicker(context: Get.context!, initialTime: initial);
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
              const Divider(height: 24, color: AppColors.border),

              // Target audience
              const Text('Target Audience', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Obx(
                () => Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Students Only'),
                      selected: controller.targetAudience.value == 'student_only',
                      onSelected: (v) => controller.targetAudience.value = 'student_only',
                    ),
                    ChoiceChip(
                      label: const Text('Parents Only'),
                      selected: controller.targetAudience.value == 'parent_only',
                      onSelected: (v) => controller.targetAudience.value = 'parent_only',
                    ),
                    ChoiceChip(
                      label: const Text('Students & Parents'),
                      selected: controller.targetAudience.value == 'student_and_parent',
                      onSelected: (v) => controller.targetAudience.value = 'student_and_parent',
                    ),
                  ],
                ),
              ),
              const Divider(height: 24, color: AppColors.border),

              // Admin notification phone
              TextField(
                controller: controller.adminPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Admin Digest Alert Mobile (Optional)',
                  hintText: 'e.g. 9876543210',
                  prefixIcon: Icon(Icons.notifications_active_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapLg),

        // Template card
        AppCard(
          padding: const EdgeInsets.all(AppDimens.gapLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Custom Wish Template',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap chips below to insert personalized variables into your message:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimens.gapMd),

              // Variable chips
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
              const SizedBox(height: AppDimens.gapMd),

              // Template editor
              TextField(
                controller: controller.templateController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter your custom birthday message...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: AppDimens.gapLg),

              // Live preview
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECE5DD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1D7DB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.chat_rounded, size: 14, color: Color(0xFF075E54)),
                        SizedBox(width: 6),
                        Text(
                          'WhatsApp Preview Mockup',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF075E54)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
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
                        style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.gapXl),

              // Save button
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: controller.isSaving.value ? null : controller.saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: controller.isSaving.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded, color: Colors.white),
                    label: Text(
                      controller.isSaving.value ? 'Saving...' : 'Save Configuration',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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

  Widget _varChip(String tag, String label) {
    return ActionChip(
      backgroundColor: const Color(0xFFEFF6FF),
      side: const BorderSide(color: Color(0xFFBFDBFE)),
      label: Text(
        '+ $tag',
        style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 11, fontWeight: FontWeight.w700),
      ),
      onPressed: () => controller.insertVariableTag(tag),
    );
  }

  Widget _buildDirectoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller.searchController,
          decoration: InputDecoration(
            hintText: 'Search by student name, code, or room...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                controller.searchController.clear();
                controller.fetchStudents();
              },
            ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (query) => controller.fetchStudents(query: query),
        ),
        const SizedBox(height: AppDimens.gapLg),
        Obx(() {
          if (controller.isLoadingStudents.value) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final list = controller.allStudents;
          if (list.isEmpty) {
            return const AppCard(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text('No students found. Tap Search to refresh directory.'),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Showing ${list.length} Students (Active & N/A Room)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimens.gapSm),
              ...list.take(100).map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.surfaceMuted,
                              child: Text(
                                s.name.isNotEmpty ? s.name[0] : '?',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        s.room == 'N/A' ? 'Room N/A' : 'Room ${s.room}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: s.room == 'N/A' ? Colors.orange.shade800 : AppColors.textSecondary,
                                          fontWeight: s.room == 'N/A' ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                      if (s.dob.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text('DOB: ${s.dob}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (s.phone.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.phone_rounded, size: 16, color: AppColors.primary),
                                onPressed: () => controller.callPhone(s.phone),
                              ),
                            if (s.whatsappNumber.isNotEmpty || s.phone.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFF10B981)),
                                onPressed: () => controller.openWhatsApp(
                                  s.whatsappNumber.isNotEmpty ? s.whatsappNumber : s.phone,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildLogsAndTestTab(BirthdayDashboardData? data) {
    final logs = data?.recentLogs ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sandbox Card
        AppCard(
          padding: const EdgeInsets.all(AppDimens.gapLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Test Sandbox',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter any phone number to immediately test delivering the greeting message without affecting live celebrants:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimens.gapMd),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.testPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Test Mobile Number',
                        hintText: 'e.g. 9876543210',
                        prefixIcon: Icon(Icons.phone_android_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapMd),
                  Obx(
                    () => ElevatedButton(
                      onPressed: controller.isTriggering.value ? null : controller.sendTestWish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      child: controller.isTriggering.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Send Test', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapLg),

        // Logs Card
        AppCard(
          padding: const EdgeInsets.all(AppDimens.gapLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Delivery Logs (${logs.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppDimens.gapMd),
              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No delivery logs yet.')),
                )
              else
                ...logs.map(
                  (log) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          log.isSent ? Icons.check_circle_rounded : Icons.error_rounded,
                          size: 18,
                          color: log.isSent ? const Color(0xFF10B981) : AppColors.errorRed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.studentName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                '${log.room == "N/A" ? "Room N/A" : "Room ${log.room}"} • ${log.phone} • ${log.wishDate}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: log.status.toUpperCase(),
                          color: log.isSent ? AppColors.successGreen : AppColors.errorRed,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
