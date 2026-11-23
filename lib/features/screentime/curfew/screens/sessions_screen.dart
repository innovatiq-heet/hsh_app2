import 'package:flutter/material.dart';

import '../../../shared/widgets/navy_sliver_header.dart';
import '../curfew_schedule.dart';
import '../models.dart';
import '../screen_time_api.dart';
import '../widgets/common.dart';
import 'assign_students_sheet.dart';
import 'session_editor_sheet.dart';
import 'student_summary_screen.dart';

/// What the admin screens need from the host app.
class ScreenTimeAdminConfig {
  const ScreenTimeAdminConfig({
    required this.api,
    this.floorOptions = const [],
    this.groupOptions = const [],
    this.tagOptions = const {},
    this.pickStudents,
  });

  final ScreenTimeApi api;

  /// Choices for bulk assignment (from the app's floor / group / tag lists).
  final List<int> floorOptions;
  final List<String> groupOptions;
  final Map<int, String> tagOptions;

  /// The app's student picker (numeric `students.id` only).
  final StudentPicker? pickStudents;

  void openStudent(BuildContext context, int studentId) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => StudentSummaryScreen(config: this, studentId: studentId)),
      );
}

Future<bool?> _confirm(BuildContext context, {required String title, required String message, required String action}) =>
    showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(message, style: const TextStyle(height: 1.4, color: StPalette.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StPalette.accent),
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    );

/// Screen Time → Curfew sessions: every session with an on/off switch.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, required this.config});

  final ScreenTimeAdminConfig config;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  Key _listKey = UniqueKey();

  ScreenTimeApi get _api => widget.config.api;

  void _reload() => setState(() => _listKey = UniqueKey());

  Future<void> _create() async {
    final draft = await showSessionEditor(context);
    if (draft == null || !mounted) return;
    CurfewSession? created;
    final ok = await runWithFeedback(context, () async => created = await _api.createSession(draft));
    if (!ok || !mounted) return;
    _reload();
    // Straight into "who gets it".
    final added = await showAssignStudentsSheet(
      context,
      api: _api,
      session: created!,
      floorOptions: widget.config.floorOptions,
      groupOptions: widget.config.groupOptions,
      tagOptions: widget.config.tagOptions,
      pickStudents: widget.config.pickStudents,
    );
    if (added != null && mounted) {
      await runWithFeedback(context, () async {}, success: '${created!.name}: $added students added');
      _reload();
    }
  }

  Future<void> _toggle(CurfewSession s, bool on) async {
    if (!on) {
      final sure = await _confirm(
        context,
        title: 'Switch off ${s.name}?',
        message: '${s.studentCount} phones stop enforcing it right away. Students stay assigned, '
            'so you can switch it back on later.',
        action: 'Switch off',
      );
      if (sure != true || !mounted) return;
    }
    await runWithFeedback(context, () => _api.setSessionActive(s.id, on), success: '${s.name} switched ${on ? 'on' : 'off'}');
    _reload();
  }

  Future<void> _open(CurfewSession s) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => SessionDetailScreen(config: widget.config, sessionId: s.id)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return CurfewPage(
      title: 'Curfew Sessions',
      subtitle: 'When phones block apps, and for whom',
      actions: [
        NavyHeaderAction(
          icon: Icons.history_rounded,
          tooltip: 'Change history',
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SessionHistoryScreen(api: _api))),
        ),
      ],
      floatingActionButton: CurfewFab(icon: Icons.add_rounded, label: 'New session', onPressed: _create),
      body: AsyncView<List<CurfewSession>>(
        key: _listKey,
        load: _api.listSessions,
        builder: (context, sessions, reload) {
          if (sessions.isEmpty) {
            return EmptyBlock(
              icon: Icons.nightlight_outlined,
              title: 'No curfew sessions yet',
              message: 'Create one, like "Night Curfew" 22:00–06:00 every day, then add students to it.',
              actionLabel: 'New session',
              onAction: _create,
            );
          }
          final running = sessions.where((s) => s.isActive && s.runningNow).length;
          final on = sessions.where((s) => s.isActive).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _SessionsSummary(total: sessions.length, on: on, running: running),
              const SectionHeader('All sessions', icon: Icons.nightlight_outlined),
              for (final s in sessions) ...[
                _SessionCard(session: s, onTap: () => _open(s), onToggle: (v) => _toggle(s, v)),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SessionsSummary extends StatelessWidget {
  const _SessionsSummary({required this.total, required this.on, required this.running});

  final int total;
  final int on;
  final int running;

  @override
  Widget build(BuildContext context) {
    Widget cell(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        );
    Widget divider() => Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.2));
    return SurfaceCard(
      gradient: StPalette.heroGradient,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(children: [
        cell('$total', 'Sessions'),
        divider(),
        cell('$on', 'Switched on'),
        divider(),
        cell('$running', 'Running now'),
      ]),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap, required this.onToggle});

  final CurfewSession session;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final running = s.isActive && s.runningNow;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(
          icon: running ? Icons.nightlight_round : Icons.nightlight_outlined,
          color: s.isActive ? StPalette.accent : StPalette.textMuted,
          background: running ? null : (s.isActive ? StPalette.accentSoft : StPalette.muted),
          size: 44,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: s.isActive ? StPalette.ink : StPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.schedule_rounded, size: 14, color: StPalette.textMuted),
              const SizedBox(width: 4),
              Text('${s.startTime} – ${s.endTime}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StPalette.ink)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  describeDays(s.days),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: StPalette.textSecondary),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              SessionStateBadge(isActive: s.isActive, runningNow: s.runningNow, nextStartAt: s.nextStartAt),
              StPill(text: '${s.studentCount} students', color: StPalette.textSecondary, icon: Icons.people_alt_outlined),
              if (s.pausedCount > 0)
                StPill(text: '${s.pausedCount} paused', color: StPalette.amber, icon: Icons.pause_circle_outline),
            ]),
          ]),
        ),
        Switch(
          value: s.isActive,
          activeThumbColor: Colors.white,
          activeTrackColor: StPalette.accent,
          onChanged: onToggle,
        ),
      ]),
    );
  }
}

/// One session: live view, its students (pause / remove) and its history.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.config, required this.sessionId});

  final ScreenTimeAdminConfig config;
  final int sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  Key _key = UniqueKey();
  CurfewSession? _session;

  ScreenTimeApi get _api => widget.config.api;

  void _reload() => setState(() => _key = UniqueKey());

  Future<void> _edit() async {
    final s = _session;
    if (s == null) return;
    final draft = await showSessionEditor(context, existing: s);
    if (draft == null || draft.toJson().isEmpty || !mounted) return;
    await runWithFeedback(context, () => _api.updateSession(s.id, draft), success: 'Saved. Phones update in a few seconds.');
    _reload();
  }

  Future<void> _delete() async {
    final s = _session;
    if (s == null) return;
    final sure = await _confirm(
      context,
      title: 'Delete ${s.name}?',
      message: 'It is removed from ${s.studentCount} students. To stop it for a while, switch it off instead.',
      action: 'Delete',
    );
    if (sure != true || !mounted) return;
    final ok = await runWithFeedback(context, () => _api.deleteSession(s.id), success: '${s.name} deleted');
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _add() async {
    final s = _session;
    if (s == null) return;
    final added = await showAssignStudentsSheet(
      context,
      api: _api,
      session: s,
      floorOptions: widget.config.floorOptions,
      groupOptions: widget.config.groupOptions,
      tagOptions: widget.config.tagOptions,
      pickStudents: widget.config.pickStudents,
    );
    if (added != null && mounted) {
      await runWithFeedback(context, () async {}, success: '$added students added');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return DefaultTabController(
      length: 3,
      child: CurfewPage(
        title: s?.name ?? 'Session',
        subtitle: s == null ? 'Curfew session' : '${s.startTime} – ${s.endTime} · ${describeDays(s.days)}',
        actions: [
          NavyHeaderAction(icon: Icons.edit_outlined, tooltip: 'Edit', onTap: _edit),
          NavyHeaderAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete', onTap: _delete),
        ],
        tabBar: curfewTabBar(const ['Live', 'Students', 'History']),
        floatingActionButton: CurfewFab(icon: Icons.group_add_outlined, label: 'Add students', onPressed: _add),
        body: TabBarView(key: _key, children: [
          _LiveTab(api: _api, sessionId: widget.sessionId, onLoaded: _setSession, config: widget.config),
          _StudentsTab(config: widget.config, sessionId: widget.sessionId, onChanged: _reload),
          _HistoryList(api: _api, sessionId: widget.sessionId),
        ]),
      ),
    );
  }

  void _setSession(CurfewSession s) {
    if (_session?.updatedAt != s.updatedAt || _session?.name != s.name || _session?.isActive != s.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _session = s);
      });
    }
  }
}

class _LiveTab extends StatelessWidget {
  const _LiveTab({required this.api, required this.sessionId, required this.onLoaded, required this.config});

  final ScreenTimeApi api;
  final int sessionId;
  final void Function(CurfewSession) onLoaded;
  final ScreenTimeAdminConfig config;

  @override
  Widget build(BuildContext context) {
    return AsyncView<SessionLive>(
      load: () => api.sessionLive(sessionId),
      builder: (context, live, reload) {
        onLoaded(live.session);
        final s = live.session;
        final running = s.isActive && live.runningNow;
        final (title, detail) = !s.isActive
            ? ('Switched off', 'No phone enforces it. Students stay assigned.')
            : running
                ? (
                    'Running now',
                    'For ${live.effectiveCount} students'
                        '${live.endsAt != null ? ' · ends ${shortWhen(live.endsAt!)}' : ''}',
                  )
                : ('Not running', 'Next start ${live.nextStartAt != null ? shortWhen(live.nextStartAt!) : '—'}');
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          SurfaceCard(
            gradient: running ? StPalette.heroGradient : null,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              IconBadge(
                icon: running ? Icons.nightlight_round : (s.isActive ? Icons.schedule_rounded : Icons.power_settings_new_rounded),
                color: running ? Colors.white : (s.isActive ? StPalette.accent : StPalette.textMuted),
                background: running ? Colors.white.withValues(alpha: 0.18) : null,
                size: 46,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: running ? Colors.white : StPalette.ink,
                      )),
                  const SizedBox(height: 3),
                  Text(detail,
                      style: TextStyle(
                        fontSize: 13,
                        color: running ? Colors.white.withValues(alpha: 0.85) : StPalette.textSecondary,
                      )),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          TileGrid(columns: 3, [
            StatTile(
              icon: Icons.verified_user_outlined,
              value: '${live.effectiveCount}',
              label: 'Enforced on',
              help: 'Students in this session who are not paused.',
            ),
            StatTile(icon: Icons.wifi_rounded, value: '${live.onlineCount}', label: 'Phones online', color: StPalette.green),
            StatTile(
              icon: Icons.phone_android_rounded,
              value: '${live.usingPhone.length}',
              label: 'Using phone',
              color: live.usingPhone.isEmpty ? null : StPalette.red,
              help: 'Online with the screen on while this session is running.',
            ),
          ]),
          if (running) ...[
            SectionHeader('Using the phone now', icon: Icons.phone_android_rounded),
            if (live.usingPhone.isEmpty)
              const SurfaceCard(
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, color: StPalette.green),
                  SizedBox(width: 10),
                  Text('Nobody is using their phone.', style: TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            for (final u in live.usingPhone) ...[
              _StudentRow(
                name: u.student.name ?? '#${u.student.id}',
                status: 'online',
                subtitle: '${u.currentApp ?? 'Unknown app'} · ${formatMinutes(u.sessionUseTodayMinutes)} in curfew today',
                onTap: () => config.openStudent(context, u.student.id),
                trailing: const Icon(Icons.chevron_right_rounded, color: StPalette.textLight),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ]);
      },
    );
  }
}

/// A student in a card: initials, name, subtitle, optional pills and trailing.
class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.name, required this.subtitle, this.status, this.pills = const [], this.trailing, this.onTap});

  final String name;
  final String subtitle;
  final String? status;
  final List<Widget> pills;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(children: [
          InitialsAvatar(name: name, status: status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: StPalette.ink)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: StPalette.textSecondary)),
              ],
              if (pills.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: pills),
              ],
            ]),
          ),
          ?trailing,
        ]),
      );
}

class _StudentsTab extends StatelessWidget {
  const _StudentsTab({required this.config, required this.sessionId, required this.onChanged});

  final ScreenTimeAdminConfig config;
  final int sessionId;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final api = config.api;
    return AsyncView<SessionDetail>(
      load: () => api.getSession(sessionId, limit: 1000),
      builder: (context, detail, reload) {
        if (detail.students.isEmpty) {
          return const EmptyBlock(
            icon: Icons.group_add_outlined,
            title: 'No students yet',
            message: 'Tap "Add students" to pick students, floors, groups or tags.',
          );
        }
        final paused = detail.students.where((s) => s.isPaused).length;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: detail.students.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  color: StPalette.accentSoft,
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(children: [
                    const Icon(Icons.people_alt_rounded, color: StPalette.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${detail.total} students${paused > 0 ? ' · $paused paused' : ''}\n'
                        'Turn the switch off to pause for one student.',
                        style: const TextStyle(fontSize: 12.5, color: StPalette.ink, height: 1.35),
                      ),
                    ),
                    const HelpIcon(
                      color: StPalette.accent,
                      text: 'Paused: the session is not enforced on this student\'s phone, '
                          'but stays on for everyone else. Turn it back on any time.',
                    ),
                  ]),
                ),
              );
            }
            final st = detail.students[i - 1];
            final name = st.student.name ?? '#${st.student.id}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StudentRow(
                name: name,
                subtitle: st.student.subtitle,
                onTap: () => config.openStudent(context, st.student.id),
                pills: [
                  if (st.isPaused)
                    StPill(
                      text: 'Paused${st.pausedAt != null ? ' since ${shortDateTime(st.pausedAt!)}' : ''}',
                      color: StPalette.amber,
                      icon: Icons.pause_circle_outline,
                    ),
                  if (!st.isResident) const StPill(text: 'Left hostel', color: StPalette.red, icon: Icons.logout_rounded),
                ],
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Tooltip(
                    message: 'Enforce on this phone',
                    child: Switch(
                      value: !st.isPaused,
                      activeThumbColor: Colors.white,
                      activeTrackColor: StPalette.accent,
                      onChanged: (enforce) async {
                        await runWithFeedback(context, () => api.setStudentPaused(sessionId, st.student.id, !enforce),
                            success: enforce ? 'Resumed for $name' : 'Paused for $name');
                        await reload();
                      },
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: StPalette.textMuted),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (_) async {
                      await runWithFeedback(
                        context,
                        () => api.removeStudents(sessionId, StudentSelection(studentIds: [st.student.id])),
                        success: '$name removed',
                      );
                      onChanged();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(children: [
                          Icon(Icons.person_remove_outlined, size: 18, color: StPalette.red),
                          SizedBox(width: 10),
                          Text('Remove from session'),
                        ]),
                      ),
                    ],
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.api, this.sessionId});

  final ScreenTimeApi api;
  final int? sessionId;

  static (IconData, Color) _look(String action) => switch (action) {
        'created' || 'migrated' => (Icons.add_circle_outline_rounded, StPalette.green),
        'edited' => (Icons.edit_outlined, StPalette.accent),
        'switched_on' => (Icons.toggle_on_outlined, StPalette.green),
        'switched_off' => (Icons.toggle_off_outlined, StPalette.textMuted),
        'deleted' => (Icons.delete_outline_rounded, StPalette.red),
        'students_added' => (Icons.group_add_outlined, StPalette.accent),
        'students_removed' => (Icons.group_remove_outlined, StPalette.amber),
        'student_paused' => (Icons.pause_circle_outline_rounded, StPalette.amber),
        _ => (Icons.play_circle_outline_rounded, StPalette.green),
      };

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<SessionLogEntry>>(
      load: () => api.sessionHistory(sessionId: sessionId, limit: 200),
      builder: (context, entries, reload) {
        if (entries.isEmpty) {
          return const EmptyBlock(icon: Icons.history_rounded, title: 'No changes yet');
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(children: [
                for (var i = 0; i < entries.length; i++)
                  _HistoryEntry(
                    entry: entries[i],
                    look: _look(entries[i].action),
                    isLast: i == entries.length - 1,
                    showSession: sessionId == null,
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry, required this.look, required this.isLast, required this.showSession});

  final SessionLogEntry entry;
  final (IconData, Color) look;
  final bool isLast;
  final bool showSession;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = look;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 34,
          child: Column(children: [
            const SizedBox(height: 10),
            IconBadge(icon: icon, color: color, size: 30),
            if (!isLast) Expanded(child: Container(width: 2, color: StPalette.divider)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.message,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: StPalette.ink, height: 1.3)),
              const SizedBox(height: 3),
              Text(
                [
                  if (showSession && entry.sessionName.isNotEmpty) entry.sessionName,
                  if (entry.createdAt != null) shortDateTime(entry.createdAt!),
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: StPalette.textMuted),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Every session's changes (opened from the sessions list).
class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key, required this.api});

  final ScreenTimeApi api;

  @override
  Widget build(BuildContext context) => CurfewPage(
        title: 'Session History',
        subtitle: 'Every change, with who made it',
        body: _HistoryList(api: api),
      );
}
