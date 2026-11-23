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
    return Scaffold(
      appBar: AppBar(title: const Text('Student screen time')),
      body: AsyncView<StudentSummary>(
        key: _key,
        load: () => api.studentSummary(widget.studentId, range: _range),
        builder: (context, s, reload) {
          final theme = Theme.of(context);
          final student = s.student;
          return ListView(padding: const EdgeInsets.all(12), children: [
            // ---- 1. status now ----
            Card(
              child: ListTile(
                leading: ConnectionDot(status: s.connectionStatus),
                title: Text(student.name ?? '#${student.id}', style: theme.textTheme.titleMedium),
                subtitle: Text([
                  student.subtitle,
                  '${ConnectionDot.labelOf(s.connectionStatus)}'
                      '${s.isScreenOn && s.currentApp != null ? ' · using ${s.currentApp}' : ''}'
                      '${s.batteryLevel != null ? ' · battery ${s.batteryLevel}%' : ''}',
                  if (s.inCurfewNow) 'In curfew now',
                ].where((t) => t.isNotEmpty).join('\n')),
                isThreeLine: true,
              ),
            ),
            if (s.protectionRemoved)
              Card(
                color: theme.colorScheme.errorContainer,
                child: const ListTile(
                  leading: Icon(Icons.warning_amber),
                  title: Text('Removal protection is off'),
                  subtitle: Text('The student could uninstall the HSH app.'),
                ),
              ),

            // ---- 2. rules in force ----
            const _Title('Rules in force'),
            Card(
              child: Column(children: [
                for (final r in s.rules)
                  ListTile(
                    dense: true,
                    leading: Icon(switch (r.state) {
                      'on' => Icons.check_circle,
                      'paused' => Icons.pause_circle,
                      _ => Icons.remove_circle_outline,
                    }, color: switch (r.state) {
                      'on' => Colors.green,
                      'paused' => Colors.orange,
                      _ => Colors.grey,
                    }),
                    title: Text(r.text),
                    subtitle: Text([
                      switch (r.state) { 'on' => 'On', 'paused' => 'Paused for this student', _ => 'Off' },
                      if (r.runningNow && r.state == 'on') 'running now',
                    ].join(' · ')),
                    trailing: r.kind == 'session' && r.sessionId != null
                        ? Switch(
                            value: r.state != 'paused',
                            onChanged: r.state == 'off'
                                ? null
                                : (enforce) async {
                                    await runWithFeedback(context, () => api.setStudentPaused(r.sessionId!, student.id, !enforce));
                                    await reload();
                                  },
                          )
                        : null,
                  ),
              ]),
            ),

            // ---- 3. usage ----
            _Title('Usage', action: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '7d', label: Text('7 d')),
                ButtonSegment(value: '14d', label: Text('14 d')),
                ButtonSegment(value: '30d', label: Text('30 d')),
              ],
              selected: {_range},
              onSelectionChanged: (v) => setState(() {
                _range = v.first;
                _key = UniqueKey();
              }),
            )),
            Row(children: [
              Expanded(child: StatTile(value: formatMinutes(s.todayMinutes), label: 'Today')),
              Expanded(
                child: StatTile(
                  value: formatMinutes(s.dailyAvg),
                  label: s.changePct == null ? 'Daily average' : 'Daily avg (${s.changePct! >= 0 ? '+' : ''}${s.changePct}%)',
                  help: 'Compared with the ${_range.replaceAll('d', '')} days before.',
                ),
              ),
              Expanded(
                child: StatTile(
                  value: formatMinutes(s.rangeSessionUse),
                  label: 'During curfew',
                  color: s.rangeSessionUse > 0 ? Colors.red : null,
                ),
              ),
            ]),
            if (s.topApps.isNotEmpty)
              Card(
                child: Column(children: [
                  for (final a in s.topApps) ListTile(dense: true, title: Text(a.appName), trailing: Text(formatMinutes(a.minutes))),
                ]),
              ),

            // ---- 4. problems ----
            const _Title('Problems'),
            if (s.problems.isEmpty && s.blockAttemptsByReason.isEmpty && s.recentAlerts.isEmpty)
              const Card(child: ListTile(title: Text('No problems. 👍'))),
            for (final p in s.problems)
              Card(child: ListTile(leading: SeverityChip(severity: p.severity), title: Text(p.message))),
            if (s.blockAttemptsByReason.isNotEmpty)
              Card(
                child: Column(children: [
                  const ListTile(dense: true, title: Text('Block attempts in this period')),
                  for (final e in s.blockAttemptsByReason.entries)
                    ListTile(dense: true, title: Text(_blockReasons[e.key] ?? e.key), trailing: Text('${e.value}')),
                ]),
              ),
            for (final a in s.recentAlerts)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notification_important_outlined),
                  title: Text('${a['message']}'),
                  subtitle: a['created_at'] == null ? null : Text(shortDateTime(DateTime.parse('${a['created_at']}'))),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          ?action,
        ]),
      );
}
