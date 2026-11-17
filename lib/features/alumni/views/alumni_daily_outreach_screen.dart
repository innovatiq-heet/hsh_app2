import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/models/alumni/alumni_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/navy_sliver_header.dart';
import '../../shared/widgets/sheet_scaffold.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/alumni_daily_outreach_controller.dart';

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
  static const pending = Color(0xFFD97706);
  static const pendingSoft = Color(0xFFFEF3C7);
  static const danger = Color(0xFFE11D48);
  static const whatsapp = Color(0xFF25D366);
}

BoxDecoration _cardDecoration({Color border = _C.border}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(color: _C.ink.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
      ],
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
      _ProgressCard(data: data),
      if (!controller.isLeader.value) ...[
        const SizedBox(height: 14),
        _GroupPicker(controller: controller),
      ],
      const SizedBox(height: 16),
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
      if (data.isAllCompleted) ...[
        _DoneBanner(target: data.targetDailyCount),
        const SizedBox(height: 12),
      ],
      for (final s in controller.orderedStudents) ...[
        _AlumnusCard(controller: controller, student: s),
        const SizedBox(height: 12),
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
    return [
      for (final day in controller.historyByDay) ...[
        _DayHeading(date: day.key, count: day.value.length),
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < day.value.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: _C.soft),
                _HistoryRow(item: day.value[i]),
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
  const _ProgressCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final done = data.isAllCompleted;
    final left = (data.targetDailyCount - data.contactedTodayCount).clamp(0, data.targetDailyCount);
    final stillToReach = (data.totalAlumniInGroup - data.totalMessagedAlumni).clamp(0, data.totalAlumniInGroup);
    final color = done ? _C.done : _C.accent;

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
                      done ? 'All done for today' : 'Today\'s connects',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      done
                          ? 'New alumni will be ready tomorrow.'
                          : '$left left · tap Send to greet them on WhatsApp',
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
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.ink)),
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
            child: Text('GROUP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _C.muted, letterSpacing: 0.6)),
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

enum _MoreAction { copy, markDone, skip }

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
          'Use this when the number is wrong or they can\'t be reached. Another alumnus of the '
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

  /// Own [Obx]: the busy state and the alumnus's own message change without
  /// the list being rebuilt.
  @override
  Widget build(BuildContext context) => Obx(() => _card(context));

  Widget _card(BuildContext context) {
    final s = student;
    final done = s.isMessaged;
    final busy = controller.busyIds.contains(s.studentId);
    final hasPhone = s.targetWhatsAppPhone.isNotEmpty || s.phone.trim().isNotEmpty;
    final edited = controller.hasCustomMessage(s.studentId);
    final sentAt = _timeOf(s.contactedAt);

    return Container(
      decoration: _cardDecoration(border: done ? _C.doneBorder : _C.border),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: done ? _C.doneSoft : _C.accentSoft,
                child: done
                    ? const Icon(Icons.check_rounded, color: _C.done)
                    : Text(
                        s.initials,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _C.accent),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Room ${s.pastRoom} · ${s.batchLabel}',
                      style: const TextStyle(fontSize: 12, color: _C.muted, fontWeight: FontWeight.w500),
                    ),
                    if (s.hasWorkInfo) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.work_outline_rounded, size: 13, color: _C.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              s.currentRoleLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(done: done),
            ],
          ),
          const SizedBox(height: 12),
          // The message they get.
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 10),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: _C.accent),
                    const SizedBox(width: 6),
                    Text(
                      edited ? 'Your message' : 'Message',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.accent),
                    ),
                    const Spacer(),
                    if (!done)
                      TextButton.icon(
                        onPressed: busy ? null : () => _EditMessageSheet.show(controller, s),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: _C.accent,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Edit'),
                      )
                    else
                      const SizedBox(height: 36),
                  ],
                ),
                Text(
                  done && (s.message ?? '').isNotEmpty ? s.message! : controller.getFormattedMessage(s),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: _C.body, height: 1.4),
                ),
              ],
            ),
          ),
          if (done && sentAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.done_all_rounded, size: 15, color: _C.done),
                const SizedBox(width: 6),
                Text('Messaged at $sentAt', style: const TextStyle(fontSize: 12, color: _C.done, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.call_rounded,
                tooltip: 'Call',
                onTap: busy || !hasPhone ? null : () => controller.callPhone(s.phone.isNotEmpty ? s.phone : s.targetWhatsAppPhone),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: done ? Colors.white : _C.whatsapp,
                      foregroundColor: done ? _C.done : Colors.white,
                      side: done ? const BorderSide(color: _C.doneBorder) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: busy ? null : () => controller.openWhatsApp(s),
                    icon: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 17),
                    label: Text(done ? 'Send again' : 'Send on WhatsApp', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<_MoreAction>(
                tooltip: 'More',
                enabled: !busy,
                icon: const Icon(Icons.more_vert_rounded, color: _C.muted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (a) {
                  switch (a) {
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
                    value: _MoreAction.copy,
                    child: ListTile(leading: Icon(Icons.copy_rounded), title: Text('Copy message'), contentPadding: EdgeInsets.zero),
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
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool done;
  const _StatusPill({required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done ? _C.done : _C.pending;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: done ? _C.doneSoft : _C.pendingSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.schedule_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            done ? 'Messaged' : 'Pending',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _RoundIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: onTap == null ? _C.soft : _C.accentSoft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: onTap == null ? _C.muted : _C.accent),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// History
// ======================================================================

/// "10:32 AM" from an API or local timestamp; null when there is none.
String? _timeOf(String? raw) {
  final t = DateTime.tryParse(raw ?? '');
  if (t == null) return null;
  return t.isUtc ? DateFormatting.time(t) : DateFormat('hh:mm a').format(t);
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

class _HistoryRow extends StatelessWidget {
  final AlumniOutreachHistoryModel item;
  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final time = _timeOf(item.contactedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: _C.doneSoft,
            child: Icon(Icons.check_rounded, size: 17, color: _C.done),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink),
                      ),
                    ),
                    if (time != null) Text(time, style: const TextStyle(fontSize: 11.5, color: _C.muted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Room ${item.pastRoom} · by ${item.leaderName}',
                  style: const TextStyle(fontSize: 12, color: _C.muted),
                ),
                if (item.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border)),
                enabledBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border)),
                focusedBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.accent, width: 1.5)),
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
                  label: Text('${p.key} · ${p.value}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _C.accent)),
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
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
            focusedBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.accent, width: 1.5)),
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

  static Future<void> show(int target) => Get.bottomSheet(
        _HowItWorksSheet(target: target),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );

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
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _C.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i], style: const TextStyle(fontSize: 13.5, color: _C.body, height: 1.4))),
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
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _C.ink)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: _C.muted, height: 1.4)),
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
