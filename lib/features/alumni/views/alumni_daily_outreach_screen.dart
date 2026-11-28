import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/models/alumni/alumni_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../phonebook/controllers/phonebook_controller.dart';
import '../../phonebook/views/student_detail_screen.dart';
import '../../shared/widgets/navy_sliver_header.dart';
import '../../shared/widgets/sheet_scaffold.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/alumni_daily_outreach_controller.dart';
import '../widgets/alumni_outreach_sheets.dart';
import '../../shared/widgets/student_avatar.dart';

/// Colours of the leader tools (Birthday Wishes, Screen Time): slate text and
/// cards, sky-blue accent, green for done, amber for still to do.
class _C {
  static const bg = Color(0xFFF8FAFC);
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const soft = Color(0xFFF1F5F9);
  static const accent = Color(0xFF0284C7);
  static const accentSoft = Color(0xFFE0F2FE);
  static const done = Color(0xFF16A34A);
  static const doneSoft = Color(0xFFDCFCE7);
  static const doneBorder = Color(0xFFBBF7D0);
  static const danger = Color(0xFFE11D48);
  static const whatsapp = Color(0xFF25D366);
}

BoxDecoration _cardDecoration({Color border = _C.border}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: border),
  boxShadow: [BoxShadow(color: _C.ink.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
);

/// Leader tools → Daily Alumni Connect: today's alumni to greet on WhatsApp,
/// the group's history, and the message they get.
class AlumniDailyOutreachScreen extends GetView<AlumniDailyOutreachController> {
  const AlumniDailyOutreachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: RefreshIndicator(
          onRefresh: controller.refreshAll,
          color: _C.accent,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              Obx(() {
                final target = controller.outreachData.value?.targetDailyCount ?? 5;
                return NavySliverHeader(
                  title: 'Daily Alumni Connect',
                  subtitle: '${controller.currentGroup.value} group · $target alumni a day',
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: [
                    NavyHeaderAction(
                      icon: Icons.info_outline_rounded,
                      tooltip: 'How it works',
                      onTap: () => _HowItWorksSheet.show(target),
                    ),
                  ],
                );
              }),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.paddingOf(context).bottom),
                sliver: Obx(() => SliverList.list(children: _content(context))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final data = controller.outreachData.value;
    if (data == null) {
      if (controller.loadError.value.isNotEmpty) {
        return [
          _MessageBox(
            icon: Icons.cloud_off_rounded,
            color: _C.danger,
            title: 'Could not load today\'s alumni',
            message: controller.loadError.value,
            actionLabel: 'Try again',
            onAction: controller.loadDailyOutreach,
          ),
        ];
      }
      return const [
        SkeletonLoader(height: 150, borderRadius: BorderRadius.all(Radius.circular(18))),
        SizedBox(height: 16),
        SkeletonLoader(height: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
        SizedBox(height: 16),
        SkeletonLoader(height: 190, borderRadius: BorderRadius.all(Radius.circular(18))),
        SizedBox(height: 12),
        SkeletonLoader(height: 190, borderRadius: BorderRadius.all(Radius.circular(18))),
      ];
    }

    return [
      if (controller.selectedTab.value == OutreachTab.today) ...[
        _ProgressCard(data: data, isAdmin: !controller.isLeader.value),
        const SizedBox(height: 14),
      ],
      if (!controller.isLeader.value) ...[_GroupPicker(controller: controller), const SizedBox(height: 14)],
      _TabPills(controller: controller),
      const SizedBox(height: 14),
      ...switch (controller.selectedTab.value) {
        OutreachTab.today => _todayTab(context, data),
        OutreachTab.history => _historyTab(),
        OutreachTab.message => [_MessageTab(controller: controller)],
      },
    ];
  }

  // ------------------------------------------------------------------ today

  List<Widget> _todayTab(BuildContext context, AlumniDailyOutreachDataModel data) {
    if (data.students.isEmpty) {
      return const [
        _MessageBox(
          icon: Icons.groups_2_outlined,
          color: _C.muted,
          title: 'No alumni for today',
          message: 'This group has no alumni with a phone number yet.',
        ),
      ];
    }
    return [
      if (data.isAllCompleted) ...[_DoneBanner(target: data.targetDailyCount), const SizedBox(height: 12)],
      if (controller.isLeader.value) ...[
        _LeaderAutoConnectCard(controller: controller),
        const SizedBox(height: 12),
      ],
      if (!controller.isLeader.value || controller.personalWhatsAppConnected.value) ...[
        _SendAllRow(controller: controller, data: data),
        const SizedBox(height: 12),
      ],
      for (final s in controller.orderedStudents) ...[
        _AlumnusCard(controller: controller, student: s),
        const SizedBox(height: 8),
      ],
    ];
  }

  // ---------------------------------------------------------------- history

  List<Widget> _historyTab() {
    if (controller.isHistoryLoading.value && controller.historyList.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: _C.accent)),
        ),
      ];
    }
    if (controller.historyError.value.isNotEmpty && controller.historyList.isEmpty) {
      return [
        _MessageBox(
          icon: Icons.cloud_off_rounded,
          color: _C.danger,
          title: 'Could not load the history',
          message: controller.historyError.value,
          actionLabel: 'Try again',
          onAction: controller.loadHistory,
        ),
      ];
    }
    if (controller.historyList.isEmpty) {
      return const [
        _MessageBox(
          icon: Icons.history_rounded,
          color: _C.muted,
          title: 'No connects yet',
          message: 'Alumni you message appear here, day by day.',
        ),
      ];
    }
    final hasActiveFilters = controller.reachabilityFilter.value != 'all' ||
        (!controller.isLeader.value && controller.historyScopeFilter.value != 'all') ||
        controller.historySearchQuery.value.trim().isNotEmpty;

    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Contact history',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.ink),
            ),
          ),
          if (hasActiveFilters)
            TextButton(
              onPressed: () {
                controller.reachabilityFilter.value = 'all';
                controller.historyScopeFilter.value = 'all';
                controller.historySearchController.clear();
                controller.historySearchQuery.value = '';
              },
              child: const Text('Reset', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text(
          'Tap any entry to read the message or update its WhatsApp contact.',
          style: TextStyle(fontSize: 12, color: _C.muted),
        ),
      ),
      TextField(
        controller: controller.historySearchController,
        onChanged: (v) => controller.historySearchQuery.value = v,
        decoration: InputDecoration(
          hintText: 'Search name, room, phone, or sender...',
          hintStyle: const TextStyle(fontSize: 13, color: _C.muted),
          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: _C.muted),
          suffixIcon: controller.historySearchQuery.value.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: _C.muted),
                  onPressed: () {
                    controller.historySearchController.clear();
                    controller.historySearchQuery.value = '';
                  },
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.border),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (!controller.isLeader.value) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in const [
                ('all', 'All senders'),
                ('leader', 'By Leaders'),
                ('admin', 'By Admin'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(entry.$2, style: const TextStyle(fontSize: 12)),
                    selected: controller.historyScopeFilter.value == entry.$1,
                    onSelected: (_) => controller.historyScopeFilter.value = entry.$1,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in const ['all', 'reachable', 'not_reachable'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      filter == 'all' ? 'All statuses' : _reachabilityLabel(filter),
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: controller.reachabilityFilter.value == filter,
                    onSelected: (_) => controller.reachabilityFilter.value = filter,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
      ),
      if (controller.historyByDay.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No matching connects found.',
              style: TextStyle(fontSize: 13, color: _C.muted),
            ),
          ),
        ),
      for (final day in controller.historyByDay) ...[
        _DayHeading(date: day.key, count: day.value.length),
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < day.value.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: _C.soft),
                _HistoryRow(item: day.value[i], controller: controller),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    ];
  }
}

// ======================================================================
// Progress
// ======================================================================

class _ProgressCard extends StatelessWidget {
  final AlumniDailyOutreachDataModel data;
  final bool isAdmin;
  const _ProgressCard({required this.data, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    final done = data.isAllCompleted;
    final left = (data.targetDailyCount - data.contactedTodayCount).clamp(0, data.targetDailyCount);
    final stillToReach = (data.totalAlumniInGroup - data.totalMessagedAlumni).clamp(0, data.totalAlumniInGroup);
    final color = done ? _C.done : _C.accent;

    final titleText = isAdmin
        ? (done ? 'Admin outreach done' : 'Admin connects today')
        : (done ? 'All done for today' : 'Today\'s connects');
    final subtitleText = isAdmin
        ? (done
            ? 'Separate from group leaders\' daily batch.'
            : '$left left in your admin quota (leader count stays separate)')
        : (done ? 'New alumni will be ready tomorrow.' : '$left left · tap Send to greet them on WhatsApp');

    return Container(
      decoration: _cardDecoration(border: done ? _C.doneBorder : _C.border),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: data.progressRatio,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: _C.soft,
                      color: color,
                    ),
                    Center(
                      child: Text(
                        '${data.contactedTodayCount}/${data.targetDailyCount}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleText,
                      style: const TextStyle(fontSize: 12.5, color: _C.muted, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _C.soft),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(value: '${data.totalAlumniInGroup}', label: 'Group alumni'),
              _Stat(value: '${data.totalMessagedAlumni}', label: 'Messaged so far'),
              _Stat(value: '$stillToReach', label: 'Still to reach'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.ink),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.muted),
          ),
        ],
      ),
    );
  }
}

class _DoneBanner extends StatelessWidget {
  final int target;
  const _DoneBanner({required this.target});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.doneSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.doneBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration_rounded, color: _C.done),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Great work! All $target alumni are contacted today.',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Group picker (admin) and tabs
// ======================================================================

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? count;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({required this.label, this.icon, this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
          decoration: BoxDecoration(
            color: selected ? _C.accent : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _C.accent : _C.border, width: 1.2),
            boxShadow: selected
                ? [BoxShadow(color: _C.accent.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? Colors.white : _C.muted),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : _C.body,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: 0.25) : _C.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : const Color(0xFF475569),
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
}

class _GroupPicker extends StatelessWidget {
  final AlumniDailyOutreachController controller;
  const _GroupPicker({required this.controller});

  @override
  Widget build(BuildContext context) => Obx(() => _picker());

  Widget _picker() {
    final selected = controller.adminSelectedGroup.value.toLowerCase();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text(
              'GROUP',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _C.muted, letterSpacing: 0.6),
            ),
          ),
          for (final g in controller.availableGroups)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Pill(
                label: g,
                icon: Icons.groups_rounded,
                selected: g.toLowerCase() == selected,
                onTap: () => controller.switchAdminGroup(g),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabPills extends StatelessWidget {
  final AlumniDailyOutreachController controller;
  const _TabPills({required this.controller});

  @override
  Widget build(BuildContext context) => Obx(() => _pills());

  Widget _pills() {
    final tab = controller.selectedTab.value;
    final left = controller.pendingCount;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Pill(
            label: 'Today',
            icon: Icons.today_rounded,
            count: left > 0 ? '$left left' : 'done',
            selected: tab == OutreachTab.today,
            onTap: () => controller.selectTab(OutreachTab.today),
          ),
          const SizedBox(width: 8),
          _Pill(
            label: 'History',
            icon: Icons.history_rounded,
            count: controller.historyLoaded.value ? '${controller.historyList.length}' : null,
            selected: tab == OutreachTab.history,
            onTap: () => controller.selectTab(OutreachTab.history),
          ),
          const SizedBox(width: 8),
          _Pill(
            label: controller.isLeader.value ? 'Message' : 'Template',
            icon: Icons.chat_bubble_outline_rounded,
            selected: tab == OutreachTab.message,
            onTap: () => controller.selectTab(OutreachTab.message),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// One alumnus
// ======================================================================

enum _MoreAction { contactStatus, profile, editMessage, copy, markDone, skip }

/// Title row of today's list with the admin-only Send All button, placed like
/// the one in Birthday Wishes.
class _SendAllRow extends StatelessWidget {
  final AlumniDailyOutreachController controller;
  final AlumniDailyOutreachDataModel data;

  const _SendAllRow({required this.controller, required this.data});

  @override
  Widget build(BuildContext context) {
    final sending = controller.isSendingAll.value;
    final allDone = controller.pendingCount == 0;
    return Row(
      children: [
        Expanded(
          child: Text(
            "Today's alumni (${data.students.length})",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _C.ink),
          ),
        ),
        ElevatedButton(
          onPressed: sending || allDone ? null : controller.sendAllToday,
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _C.soft,
            disabledForegroundColor: _C.muted,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _C.accent),
                )
              : Text(
                  allDone ? 'Sent Today ✓' : 'Send All',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
        ),
      ],
    );
  }
}

class _LeaderAutoConnectCard extends StatelessWidget {
  final AlumniDailyOutreachController controller;
  const _LeaderAutoConnectCard({required this.controller});

  Future<void> _pickTime(BuildContext context) async {
    final parts = controller.autoSendTimeIst.value.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59)),
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await controller.saveAutoSettings(timeIst: formatted);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final connected = controller.personalWhatsAppConnected.value;
      final phone = controller.personalWhatsAppPhone.value;
      final autoOn = controller.autoSendEnabled.value;
      final time = controller.autoSendTimeIst.value;
      final note = controller.lastAutoRunNote.value;
      final saving = controller.isSavingAutoSettings.value;

      if (!connected) {
        return Container(
          decoration: _cardDecoration(border: const Color(0xFFBAE6FD)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: _C.accentSoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.chat_rounded, color: _C.accent, size: 19),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link WhatsApp for Auto Connect',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.ink),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Add your number to send automatically or schedule daily connect.',
                      style: TextStyle(fontSize: 11.5, color: _C.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await Get.toNamed(Routes.whatsappNumbers);
                  await controller.loadAutoSettings();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.accent,
                  side: const BorderSide(color: _C.accent),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('My WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }

      return Container(
        decoration: _cardDecoration(border: autoOn ? _C.doneBorder : _C.border),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: autoOn ? _C.doneSoft : _C.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.schedule_send_rounded,
                    color: autoOn ? _C.done : _C.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auto Alumni Connect',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink),
                      ),
                      Text(
                        phone != null && phone.isNotEmpty
                            ? 'Sending from +$phone'
                            : 'Personal WhatsApp connected',
                        style: const TextStyle(fontSize: 11.5, color: _C.done, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: autoOn,
                  activeTrackColor: _C.done,
                  onChanged: saving ? null : (v) => controller.saveAutoSettings(enabled: v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    autoOn
                        ? 'Auto-sends daily batch at $time IST'
                        : 'Turn on to auto-send today\'s batch daily',
                    style: const TextStyle(fontSize: 12, color: _C.body),
                  ),
                ),
                InkWell(
                  onTap: saving ? null : () => _pickTime(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _C.soft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _C.border),
                    ),
                    child: Text(
                      '$time IST',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.accent),
                    ),
                  ),
                ),
              ],
            ),
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                note,
                style: const TextStyle(fontSize: 11.5, color: _C.muted),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// One alumnus of today's list, kept small: who they are, whether they are
/// messaged, and the quick actions. Tapping it opens their details.
class _AlumnusCard extends StatelessWidget {
  final AlumniDailyOutreachController controller;
  final AlumniOutreachStudentModel student;

  const _AlumnusCard({required this.controller, required this.student});

  Future<void> _confirmSkip(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Skip ${student.name}?'),
        content: Text(
          "Use this when the number is wrong or they can't be reached. Another alumnus of the "
          '${controller.currentGroup.value} group takes their place today.',
          style: const TextStyle(fontSize: 13.5, color: _C.body, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _C.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Skip and replace'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.skipAlumnus(student);
  }

  /// The phonebook's student screen when the alumnus is in the synced
  /// phonebook, otherwise a short details sheet.
  Future<void> _openDetails(BuildContext context) async {
    final match = await controller.findInPhonebook(student);
    if (!context.mounted) return;
    if (match == null) {
      await _AlumnusDetailsSheet.show(controller, student);
      return;
    }
    // The phonebook screen needs its controller; drop it again afterwards.
    final created = !Get.isRegistered<PhonebookController>();
    if (created) Get.put(PhonebookController());
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StudentDetailScreen(student: match, studentId: student.studentId > 0 ? student.studentId : null)));
    } finally {
      if (created && Get.isRegistered<PhonebookController>()) Get.delete<PhonebookController>();
    }
  }

  /// Own [Obx]: the busy state changes without the list being rebuilt.
  @override
  Widget build(BuildContext context) => Obx(() => _card(context));

  Widget _card(BuildContext context) {
    final s = student;
    final done = s.isMessaged;
    final busy = controller.busyIds.contains(s.studentId);
    final hasPhone = s.targetWhatsAppPhone.isNotEmpty || s.phone.trim().isNotEmpty;
    final sentAt = _timeOf(s.contactedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetails(context),
        child: Container(
          decoration: _cardDecoration(
            border: done ? _C.doneBorder : _C.border,
          ).copyWith(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
          child: Row(
            children: [
              StudentAvatar(
                name: s.name,
                bankCode: s.studentCode,
                size: 36,
                background: done ? _C.doneSoft : _C.accentSoft,
                child: done
                    ? const Icon(Icons.check_rounded, size: 18, color: _C.done)
                    : Text(
                        s.initials,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _C.accent),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      done && sentAt != null ? 'Messaged at $sentAt' : 'Room ${s.pastRoom} · ${s.batchLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: done ? _C.done : _C.muted,
                        fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (_reachabilityLabel(s.whatsappReachability).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _OutreachStatusBadges(
                        reachability: s.whatsappReachability,
                        response: s.outreachResponse,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _RoundIconButton(
                icon: Icons.call_rounded,
                tooltip: 'Call',
                size: 36,
                onTap: busy || !hasPhone
                    ? null
                    : () => controller.callPhone(s.phone.isNotEmpty ? s.phone : s.targetWhatsAppPhone),
              ),
              const SizedBox(width: 6),
              _RoundIconButton(
                icon: Icons.send_rounded,
                tooltip: done ? 'Send again' : 'Send on WhatsApp',
                size: 36,
                background: done ? _C.doneSoft : _C.whatsapp,
                foreground: done ? _C.done : Colors.white,
                busy: busy,
                onTap: busy
                    ? null
                    : () => (controller.isLeader.value && controller.personalWhatsAppConnected.value && !done)
                        ? controller.sendViaGateway(s)
                        : controller.openWhatsApp(s),
              ),
              PopupMenuButton<_MoreAction>(
                tooltip: 'More',
                enabled: !busy,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert_rounded, color: _C.muted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (a) {
                  switch (a) {
                    case _MoreAction.contactStatus:
                      showOutreachStatusSheet(
                        context,
                        controller: controller,
                        studentId: s.studentId,
                        name: s.name,
                        currentReachability: s.whatsappReachability,
                        currentResponse: s.outreachResponse,
                        currentNote: s.outreachResponseNote,
                      );
                    case _MoreAction.profile:
                      showAdminFullProfileEditorSheet(
                        context,
                        controller: controller,
                        studentId: s.studentId,
                        fallbackName: s.name,
                      );
                    case _MoreAction.editMessage:
                      _EditMessageSheet.show(controller, s);
                    case _MoreAction.copy:
                      controller.copyMessage(s);
                    case _MoreAction.markDone:
                      controller.markContacted(s);
                    case _MoreAction.skip:
                      _confirmSkip(context);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _MoreAction.contactStatus,
                    child: ListTile(
                      leading: Icon(Icons.fact_check_outlined, color: _C.accent),
                      title: Text('Reachable / Response'),
                      subtitle: Text('Mark reachable or not reachable'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (controller.canEditProfile)
                    const PopupMenuItem(
                      value: _MoreAction.profile,
                      child: ListTile(
                        leading: Icon(Icons.person_outline_rounded, color: _C.ink),
                        title: Text('Profile & Edit Info'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (!done)
                    const PopupMenuItem(
                      value: _MoreAction.editMessage,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit message'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: _MoreAction.copy,
                    child: ListTile(
                      leading: Icon(Icons.copy_rounded),
                      title: Text('Copy message'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (!done) ...[
                    const PopupMenuItem(
                      value: _MoreAction.markDone,
                      child: ListTile(
                        leading: Icon(Icons.task_alt_rounded),
                        title: Text('Mark as done'),
                        subtitle: Text('Contacted another way'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: _MoreAction.skip,
                      child: ListTile(
                        leading: Icon(Icons.skip_next_rounded, color: _C.danger),
                        title: Text('Skip and replace', style: TextStyle(color: _C.danger)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fallback details of an alumnus who isn't in the synced phonebook, from
/// what today's list already carries.
class _AlumnusDetailsSheet extends StatelessWidget {
  final AlumniDailyOutreachController controller;
  final AlumniOutreachStudentModel student;

  const _AlumnusDetailsSheet({required this.controller, required this.student});

  static Future<void> show(AlumniDailyOutreachController controller, AlumniOutreachStudentModel student) =>
      Get.bottomSheet(
        _AlumnusDetailsSheet(controller: controller, student: student),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );

  @override
  Widget build(BuildContext context) {
    final s = student;
    final phone = s.phone.trim().isNotEmpty ? s.phone.trim() : s.targetWhatsAppPhone;
    final rows = <(IconData, String, String)>[
      (Icons.meeting_room_outlined, 'Past room', s.pastRoom),
      (Icons.school_outlined, 'Batch', s.batchLabel),
      if (s.groupName.isNotEmpty) (Icons.groups_2_outlined, 'Group', s.groupName),
      if ((s.currentCompany ?? '').isNotEmpty || (s.currentDesignation ?? '').isNotEmpty)
        (Icons.work_outline_rounded, 'Work', s.currentRoleLine),
      if ((s.currentCity ?? '').isNotEmpty) (Icons.location_city_rounded, 'City', s.currentCity!),
      if (phone.isNotEmpty) (Icons.phone_outlined, 'Phone', phone),
    ];
    return SheetScaffold(
      title: s.name,
      subtitle: 'Not in the phonebook on this phone',
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(r.$1, size: 18, color: _C.accent),
                const SizedBox(width: 10),
                SizedBox(
                  width: 78,
                  child: Text(
                    r.$2,
                    style: const TextStyle(fontSize: 12.5, color: _C.muted, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.$3,
                    style: const TextStyle(fontSize: 13.5, color: _C.ink, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _C.accent,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => controller.callPhone(phone),
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('Call'),
          ),
        ],
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? foreground;
  final bool busy;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 44,
    this.background,
    this.foreground,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = foreground ?? (enabled ? _C.accent : _C.muted);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: (busy || enabled) ? (background ?? _C.accentSoft) : _C.soft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: busy
                ? Padding(
                    padding: EdgeInsets.all(size * 0.3),
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Icon(icon, size: size * 0.46, color: fg),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// History
// ======================================================================

/// "10:32 AM" IST from an API (UTC) or local timestamp; null when there is none.
String? _timeOf(String? raw) {
  final t = DateTime.tryParse(raw ?? '');
  if (t == null) return null;
  return DateFormatting.time(t);
}

class _DayHeading extends StatelessWidget {
  final String date;
  final int count;
  const _DayHeading({required this.date, required this.count});

  static String label(String date, {DateTime? now}) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final diff = today.difference(DateUtils.dateOnly(d)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
      child: Row(
        children: [
          Text(
            label(date).toUpperCase(),
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _C.muted, letterSpacing: 0.6),
          ),
          const Spacer(),
          Text('$count ${count == 1 ? 'alumnus' : 'alumni'}', style: const TextStyle(fontSize: 11.5, color: _C.muted)),
        ],
      ),
    );
  }
}

String _reachabilityLabel(String status) => switch (status) {
  'reachable' => 'Reachable',
  'not_reachable' => 'Not Reachable',
  _ => '',
};

Color _reachabilityColor(String status) => switch (status) {
  'reachable' => _C.done,
  'not_reachable' => _C.danger,
  _ => _C.muted,
};

String _responseLabel(String? response) => switch (response) {
  'positive' => 'Positive',
  'neutral' => 'Neutral',
  'negative' => 'Negative',
  _ => '',
};

Color _responseColor(String? response) => switch (response) {
  'positive' => _C.done,
  'neutral' => const Color(0xFFD97706),
  'negative' => _C.danger,
  _ => _C.muted,
};

class _OutreachStatusBadges extends StatelessWidget {
  final String reachability;
  final String? response;
  const _OutreachStatusBadges({required this.reachability, this.response});

  @override
  Widget build(BuildContext context) {
    final reachLabel = _reachabilityLabel(reachability);
    final respLabel = reachability == 'reachable' ? _responseLabel(response) : '';
    if (reachLabel.isEmpty && respLabel.isEmpty) return const SizedBox.shrink();

    final reachColor = _reachabilityColor(reachability);
    final respColor = _responseColor(response);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (reachLabel.isNotEmpty)
          _statusPill(reachLabel, reachColor),
        if (respLabel.isNotEmpty)
          _statusPill(respLabel, respColor),
      ],
    );
  }

  Widget _statusPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 7, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      );
}

class _HistoryRow extends StatelessWidget {
  final AlumniOutreachHistoryModel item;
  final AlumniDailyOutreachController controller;
  const _HistoryRow({required this.item, required this.controller});

  Future<void> _edit(BuildContext context) async {
    final form = GlobalKey<FormState>();
    var editedNumber = item.whatsappNumber;
    final number = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: _C.accentSoft, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.chat_outlined, color: _C.accent),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Update WhatsApp contact',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _C.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(item.name, style: const TextStyle(fontSize: 14, color: _C.muted)),
                  if (item.phone.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _C.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _C.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 16, color: _C.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Primary Mobile (unchanged): ${item.phone}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _C.body),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextFormField(
                    initialValue: item.whatsappNumber,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) => editedNumber = value,
                    decoration: InputDecoration(
                      labelText: 'WhatsApp number',
                      hintText: '10 digit number or include country code',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: _C.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (value) {
                      final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                      return digits.length < 10 || digits.length > 15 ? 'Enter a valid 10–15 digit number' : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Color(0xFFB45309)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Only the WhatsApp number will change. The alumnus\'s previous primary mobile stays safe and unchanged, and the new number starts as Not Verified.',
                            style: TextStyle(fontSize: 12, color: _C.body),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: _C.accent),
                          onPressed: () {
                            if (form.currentState!.validate()) Navigator.of(ctx).pop(editedNumber.trim());
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Save number'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (number != null && number != item.whatsappNumber) {
      await controller.updateContact(item, number: number);
    }
  }

  Future<void> _showChanges(BuildContext context) async {
    try {
      final changes = await controller.contactChanges(item.studentId);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${item.name} · number changes'),
          content: SizedBox(
            width: double.maxFinite,
            child: changes.isEmpty
                ? const Text('No number changes recorded.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final row in changes)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${row['previousNumber'] ?? 'None'} → ${row['updatedNumber'] ?? ''}'),
                          subtitle: Text('${row['modifiedAt'] ?? ''} · ${row['administratorName'] ?? ''}'),
                        ),
                    ],
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load number changes: $e')));
      }
    }
  }

  Future<void> _openStatusSheet(BuildContext context) => showOutreachStatusSheet(
        context,
        controller: controller,
        studentId: item.studentId,
        name: item.name,
        currentReachability: item.whatsappReachability,
        currentResponse: item.outreachResponse,
        currentNote: item.outreachResponseNote,
      );

  String _senderSummary() {
    final rolePrefix = item.isSentByAdmin ? 'Admin' : 'Leader';
    if (item.leaderName.isEmpty) return rolePrefix;
    return '$rolePrefix: ${item.leaderName}';
  }

  Future<void> _showDetails(BuildContext context) async {
    final time = _timeOf(item.contactedAt);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + MediaQuery.paddingOf(ctx).bottom),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: item.isSentByAdmin ? _C.accentSoft : _C.doneSoft,
                  child: Icon(
                    item.isSentByAdmin ? Icons.admin_panel_settings_outlined : Icons.check_rounded,
                    size: 20,
                    color: item.isSentByAdmin ? _C.accent : _C.done,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Room ${item.pastRoom}${item.groupName.isNotEmpty ? ' · ${item.groupName}' : ''}',
                        style: const TextStyle(fontSize: 12.5, color: _C.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: item.isSentByAdmin ? _C.accentSoft : _C.doneSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _senderSummary(),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: item.isSentByAdmin ? _C.accent : _C.done,
                    ),
                  ),
                ),
                if (time != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${_DayHeading.label(item.outreachDate)} · $time',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _C.body),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'WhatsApp number',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _C.muted),
                      ),
                      const Spacer(),
                      _OutreachStatusBadges(
                        reachability: item.whatsappReachability,
                        response: item.outreachResponse,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.whatsappNumber.isEmpty ? 'No WhatsApp number' : item.whatsappNumber,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.ink),
                        ),
                      ),
                      if (item.whatsappNumber.isNotEmpty)
                        IconButton(
                          tooltip: 'Copy WhatsApp number',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded, size: 18, color: _C.muted),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: item.whatsappNumber));
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('WhatsApp number copied')),
                            );
                          },
                        ),
                    ],
                  ),
                  if (item.phone.isNotEmpty && item.phone != item.whatsappNumber) ...[
                    const Divider(height: 16, color: _C.border),
                    const Text(
                      'Primary mobile (preserved separately)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _C.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.phone,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _C.body),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (controller.canEditProfile) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _edit(context);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Edit WhatsApp'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _openStatusSheet(context);
                    },
                    icon: const Icon(Icons.verified_outlined, size: 17),
                    label: const Text('Set status'),
                  ),
                ),
              ],
            ),
            if (controller.canEditProfile) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        showAdminFullProfileEditorSheet(
                          context,
                          controller: controller,
                          studentId: item.studentId,
                          fallbackName: item.name,
                        );
                      },
                      icon: const Icon(Icons.person_outline_rounded, size: 17),
                      label: const Text('Edit Profile'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showChanges(context);
                      },
                      icon: const Icon(Icons.history_rounded, size: 17),
                      label: const Text('Number log'),
                    ),
                  ),
                ],
              ),
            ],
            if (item.outreachResponseNote != null && item.outreachResponseNote!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _C.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Note: ${item.outreachResponseNote}',
                  style: const TextStyle(fontSize: 12.5, color: _C.body),
                ),
              ),
            ],
            if (item.message.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Sent message',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: item.message));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Message copied')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: const Text('Copy', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _C.soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  item.message,
                  style: const TextStyle(fontSize: 13, color: _C.body, height: 1.45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final time = _timeOf(item.contactedAt);
    final avatarBg = item.isSentByAdmin ? _C.accentSoft : _C.doneSoft;
    final avatarFg = item.isSentByAdmin ? _C.accent : _C.done;
    final targetPhone = item.phone.trim().isNotEmpty ? item.phone : item.whatsappNumber;
    final hasPhone = targetPhone.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty;

    return InkWell(
      onTap: () => _showDetails(context),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: avatarBg,
              child: Icon(
                item.isSentByAdmin ? Icons.admin_panel_settings_outlined : Icons.check_rounded,
                size: 17,
                color: avatarFg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.whatsappNumber.isEmpty ? 'No WhatsApp' : item.whatsappNumber} · Rm ${item.pastRoom}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _C.body),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          time != null ? '${_senderSummary()} · $time' : _senderSummary(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.isSentByAdmin ? _C.accent : _C.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_reachabilityLabel(item.whatsappReachability).isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _OutreachStatusBadges(
                      reachability: item.whatsappReachability,
                      response: item.outreachResponse,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            _RoundIconButton(
              icon: Icons.call_rounded,
              tooltip: 'Call',
              size: 32,
              onTap: !hasPhone ? null : () => controller.callPhone(targetPhone),
            ),
            const SizedBox(width: 4),
            _RoundIconButton(
              icon: Icons.send_rounded,
              tooltip: 'Open WhatsApp',
              size: 32,
              background: _C.whatsapp.withValues(alpha: 0.14),
              foreground: _C.done,
              onTap: !hasPhone ? null : () => controller.openHistoryWhatsApp(item),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded, color: _C.muted, size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                switch (v) {
                  case 'status':
                    _openStatusSheet(context);
                  case 'profile':
                    showAdminFullProfileEditorSheet(
                      context,
                      controller: controller,
                      studentId: item.studentId,
                      fallbackName: item.name,
                    );
                  case 'edit_wa':
                    _edit(context);
                  case 'changes':
                    _showChanges(context);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'status',
                  child: ListTile(
                    leading: Icon(Icons.fact_check_outlined, color: _C.accent),
                    title: Text('Reachable / Response'),
                    subtitle: Text('Mark reachable or not reachable'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (controller.canEditProfile) ...[
                  const PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(Icons.person_outline_rounded, color: _C.ink),
                      title: Text('Profile & Edit Info'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit_wa',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit WhatsApp'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'changes',
                    child: ListTile(
                      leading: Icon(Icons.history_rounded),
                      title: Text('Number change log'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Message / template
// ======================================================================

class _MessageTab extends StatelessWidget {
  final AlumniDailyOutreachController controller;
  const _MessageTab({required this.controller});

  static const _placeholders = {
    '{first_name}': 'First name',
    '{name}': 'Full name',
    '{room}': 'Past room',
    '{group_name}': 'Group',
    '{leader_name}': 'Your name',
  };

  void _insert(String tag) {
    final c = controller.templateController;
    final sel = c.selection;
    final text = c.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    c.value = TextEditingValue(
      text: text.replaceRange(start, end, tag),
      selection: TextSelection.collapsed(offset: start + tag.length),
    );
  }

  @override
  Widget build(BuildContext context) => Obx(() => _tab());

  Widget _tab() {
    final leader = controller.isLeader.value;
    final students = controller.outreachData.value?.students ?? const <AlumniOutreachStudentModel>[];
    final sample = students.isEmpty ? null : students.first;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            leader ? 'The greeting alumni get' : 'Greeting template',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _C.ink),
          ),
          const SizedBox(height: 4),
          Text(
            leader
                ? 'Set by the hostel office. Each alumnus gets it with their own name filled in. '
                      'To change the words for one person, tap Edit on their card.'
                : 'Every leader\'s WhatsApp message starts from this. The highlighted words are filled in for each alumnus.',
            style: const TextStyle(fontSize: 12.5, color: _C.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (leader)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border),
              ),
              child: SelectableText(
                controller.templateController.text,
                style: const TextStyle(fontSize: 13, color: _C.body, height: 1.45),
              ),
            )
          else
            TextField(
              controller: controller.templateController,
              minLines: 4,
              maxLines: 8,
              style: const TextStyle(fontSize: 13.5, color: _C.ink, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Write the greeting…',
                filled: true,
                fillColor: _C.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.accent, width: 1.5),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            leader ? 'FILLED IN FOR EACH ALUMNUS' : 'TAP TO INSERT',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _C.muted, letterSpacing: 0.6),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in _placeholders.entries)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _C.accentSoft,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  label: Text(
                    '${p.key} · ${p.value}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _C.accent),
                  ),
                  onPressed: leader ? null : () => _insert(p.key),
                ),
            ],
          ),
          if (sample != null) ...[
            const SizedBox(height: 16),
            Text(
              'PREVIEW FOR ${sample.name.toUpperCase()}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _C.muted, letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller.templateController,
              builder: (_, _, _) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCF8C6), // WhatsApp sent-bubble green
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.templateMessageFor(sample),
                  style: const TextStyle(fontSize: 13, color: _C.ink, height: 1.4),
                ),
              ),
            ),
          ],
          if (!leader) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _C.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: controller.isSaving.value ? null : controller.saveTemplate,
                icon: controller.isSaving.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save template', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================================
// Sheets and boxes
// ======================================================================

/// Changes the words for one alumnus; empty goes back to the template.
class _EditMessageSheet extends StatefulWidget {
  final AlumniDailyOutreachController controller;
  final AlumniOutreachStudentModel student;

  const _EditMessageSheet({required this.controller, required this.student});

  static Future<void> show(AlumniDailyOutreachController controller, AlumniOutreachStudentModel student) =>
      Get.bottomSheet(
        _EditMessageSheet(controller: controller, student: student),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );

  @override
  State<_EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends State<_EditMessageSheet> {
  late final _text = TextEditingController(text: widget.controller.getFormattedMessage(widget.student));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save(String text) {
    widget.controller.setCustomMessage(widget.student.studentId, text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final edited = widget.controller.hasCustomMessage(widget.student.studentId);
    return SheetScaffold(
      title: 'Message for ${widget.student.name}',
      subtitle: 'Only this alumnus gets these words today.',
      children: [
        TextField(
          controller: _text,
          minLines: 5,
          maxLines: 10,
          autofocus: true,
          style: const TextStyle(fontSize: 14, color: _C.ink, height: 1.4),
          decoration: InputDecoration(
            filled: true,
            fillColor: _C.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (edited)
              TextButton(onPressed: () => _save(''), child: const Text('Use the template'))
            else
              const SizedBox.shrink(),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _C.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _save(_text.text),
              child: const Text('Save message'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HowItWorksSheet extends StatelessWidget {
  final int target;
  const _HowItWorksSheet({required this.target});

  static Future<void> show(int target) =>
      Get.bottomSheet(_HowItWorksSheet(target: target), isScrollControlled: true, backgroundColor: Colors.transparent);

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Every day you get $target alumni of your group. Over the days, everyone in the group is reached.',
      'Tap Send on WhatsApp. The greeting opens in WhatsApp with their name filled in; send it there.',
      'Called them instead? Use ⋯ → Mark as done.',
      'Wrong number or can\'t reach them? Use ⋯ → Skip and replace to get someone else.',
    ];
    return SheetScaffold(
      title: 'How it works',
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: _C.accentSoft,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _C.accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(steps[i], style: const TextStyle(fontSize: 13.5, color: _C.body, height: 1.4)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// An empty or error state inside the list.
class _MessageBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageBox({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _C.ink),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: _C.muted, height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _C.accent),
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
