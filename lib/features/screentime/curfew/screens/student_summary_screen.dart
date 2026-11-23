import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';
import 'sessions_screen.dart';

/// One page per student: status now, rules in plain words, this week, problems.
class StudentSummaryScreen extends StatefulWidget {
  const StudentSummaryScreen({super.key, required this.config, required this.studentId});

  final ScreenTimeAdminConfig config;
  final int studentId;

  @override
  State<StudentSummaryScreen> createState() => _StudentSummaryScreenState();
}

class _StudentSummaryScreenState extends State<StudentSummaryScreen> {
  String _range = '7d';
  Key _key = UniqueKey();

  static const _blockReasons = {
    'app_blocked': 'Blocked app',
    'bedtime': 'App during curfew',
    'daily_limit': 'Daily limit reached',
    'app_limit': 'App limit reached',
    'installer_blocked': 'Tried to install an app',
    'device_locked': 'Phone locked',
    'admin_protected': 'Tried to remove protection',
  };

  @override
  Widget build(BuildContext context) {
    final api = widget.config.api;
    return CurfewPage(
      title: 'Student Screen Time',
      subtitle: 'Status, rules and usage',
      body: AsyncView<StudentSummary>(
        key: _key,
        load: () => api.studentSummary(widget.studentId, range: _range),
        builder: (context, s, reload) {
          final student = s.student;
          final name = student.name ?? '#${student.id}';
          final statusLine = [
            ConnectionDot.labelOf(s.connectionStatus),
            if (s.isScreenOn && s.currentApp != null) 'using ${s.currentApp}',
            if (s.batteryLevel != null) 'battery ${s.batteryLevel}%',
          ].join(' · ');
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
            // ---- 1. status now ----
            SurfaceCard(
              child: Row(children: [
                InitialsAvatar(name: name, status: s.connectionStatus, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StPalette.ink)),
                    if (student.subtitle.isNotEmpty)
                      Text(student.subtitle, style: const TextStyle(fontSize: 12.5, color: StPalette.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      StPill(text: statusLine, color: ConnectionDot.colorOf(s.connectionStatus)),
                      if (s.inCurfewNow)
                        const StPill(text: 'In curfew now', color: StPalette.accent, icon: Icons.nightlight_round),
                    ]),
                  ]),
                ),
              ]),
            ),
            if (s.protectionRemoved) ...[
              const SizedBox(height: 10),
              const SurfaceCard(
                color: StPalette.redSoft,
                borderColor: Color(0xFFFCA5A5),
                child: Row(children: [
                  Icon(Icons.gpp_bad_outlined, color: StPalette.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Removal protection is off',
                          style: TextStyle(fontWeight: FontWeight.w800, color: StPalette.red, fontSize: 14)),
                      Text('The student could uninstall the HSH app.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF991B1B))),
                    ]),
                  ),
                ]),
              ),
            ],

            // ---- 2. rules in force ----
            const SectionHeader('Rules in force', icon: Icons.rule_rounded),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                if (s.rules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No rules set.', style: TextStyle(color: StPalette.textSecondary)),
                  ),
                for (var i = 0; i < s.rules.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: StPalette.divider, indent: 56),
                  _RuleRow(
                    rule: s.rules[i],
                    onEnforce: s.rules[i].kind == 'session' && s.rules[i].sessionId != null && s.rules[i].state != 'off'
                        ? (enforce) async {
                            await runWithFeedback(
                                context, () => api.setStudentPaused(s.rules[i].sessionId!, student.id, !enforce));
                            await reload();
                          }
                        : null,
                  ),
                ],
              ]),
            ),

            // ---- 3. usage ----
            SectionHeader(
              'Usage',
              icon: Icons.insights_rounded,
              action: _RangeChips(
                value: _range,
                onChanged: (v) => setState(() {
                  _range = v;
                  _key = UniqueKey();
                }),
              ),
            ),
            TileGrid(columns: 3, [
              StatTile(icon: Icons.today_outlined, value: formatMinutes(s.todayMinutes), label: 'Today'),
              StatTile(
                icon: Icons.hourglass_bottom_rounded,
                value: formatMinutes(s.dailyAvg),
                label: s.changePct == null ? 'Daily average' : 'Daily avg ${s.changePct! >= 0 ? '+' : ''}${s.changePct}%',
                help: 'Compared with the ${_range.replaceAll('d', '')} days before.',
              ),
              StatTile(
                icon: Icons.bedtime_outlined,
                value: formatMinutes(s.rangeSessionUse),
                label: 'During curfew',
                color: s.rangeSessionUse > 0 ? StPalette.red : null,
              ),
            ]),
            if (s.topApps.isNotEmpty) ...[
              const SizedBox(height: 10),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (var i = 0; i < s.topApps.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: StPalette.divider, indent: 14, endIndent: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Expanded(
                          child: Text(s.topApps[i].appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: StPalette.ink)),
                        ),
                        Text(formatMinutes(s.topApps[i].minutes),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StPalette.accent)),
                      ]),
                    ),
                  ],
                ]),
              ),
            ],

            // ---- 4. problems ----
            const SectionHeader('Problems', icon: Icons.flag_outlined),
            if (s.problems.isEmpty && s.blockAttemptsByReason.isEmpty && s.recentAlerts.isEmpty)
              const SurfaceCard(
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, color: StPalette.green),
                  SizedBox(width: 10),
                  Text('No problems.', style: TextStyle(fontWeight: FontWeight.w600, color: StPalette.ink)),
                ]),
              ),
            for (final p in s.problems) ...[
              SurfaceCard(
                child: Row(children: [
                  SeverityChip(severity: p.severity),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.message, style: const TextStyle(fontSize: 13.5, color: StPalette.ink))),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            if (s.blockAttemptsByReason.isNotEmpty) ...[
              SurfaceCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Block attempts in this period',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StPalette.textSecondary)),
                  const SizedBox(height: 6),
                  for (final e in s.blockAttemptsByReason.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        const Icon(Icons.block_rounded, size: 16, color: StPalette.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_blockReasons[e.key] ?? e.key,
                              style: const TextStyle(fontSize: 13.5, color: StPalette.ink)),
                        ),
                        Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800, color: StPalette.ink)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            for (final a in s.recentAlerts) ...[
              SurfaceCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconBadge(icon: Icons.notification_important_outlined, color: StPalette.amber, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${a['message']}', style: const TextStyle(fontSize: 13.5, color: StPalette.ink)),
                      if (a['created_at'] != null)
                        Text(shortDateTime(DateTime.parse('${a['created_at']}')),
                            style: const TextStyle(fontSize: 12, color: StPalette.textMuted)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ]);
        },
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, this.onEnforce});

  final RuleLine rule;
  final ValueChanged<bool>? onEnforce;

  @override
  Widget build(BuildContext context) {
    final r = rule;
    final (icon, color) = switch (r.state) {
      'on' => (Icons.check_circle_rounded, StPalette.green),
      'paused' => (Icons.pause_circle_rounded, StPalette.amber),
      _ => (Icons.remove_circle_outline_rounded, StPalette.textMuted),
    };
    final running = r.runningNow && r.state == 'on';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(children: [
        IconBadge(icon: icon, color: color, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: StPalette.ink)),
            const SizedBox(height: 2),
            Text(
              [
                switch (r.state) { 'on' => 'On', 'paused' => 'Paused for this student', _ => 'Off' },
                if (running) 'running now',
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: running ? StPalette.accent : StPalette.textSecondary),
            ),
          ]),
        ),
        if (onEnforce != null)
          Switch(
            value: r.state != 'paused',
            activeThumbColor: Colors.white,
            activeTrackColor: StPalette.accent,
            onChanged: onEnforce,
          ),
      ]),
    );
  }
}

/// 7 d / 14 d / 30 d in the module's segmented style.
class _RangeChips extends StatelessWidget {
  const _RangeChips({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: StPalette.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: StPalette.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final r in const ['7d', '14d', '30d'])
            GestureDetector(
              onTap: () => onChanged(r),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: r == value ? StPalette.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.replaceAll('d', ' d'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: r == value ? Colors.white : StPalette.textSecondary,
                  ),
                ),
              ),
            ),
        ]),
      );
}
