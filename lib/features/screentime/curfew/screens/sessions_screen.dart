import 'package:flutter/material.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${created!.name}: $added students added')));
      _reload();
    }
  }

  Future<void> _toggle(CurfewSession s, bool on) async {
    if (!on) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Switch off ${s.name}?'),
          content: Text('${s.studentCount} phones stop enforcing it right away. Students stay assigned, '
              'so you can switch it back on later.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Switch off')),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    await runWithFeedback(context, () => _api.setSessionActive(s.id, on), success: '${s.name} switched ${on ? 'on' : 'off'}');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Curfew sessions'),
        actions: [
          IconButton(
            tooltip: 'Change history',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => SessionHistoryScreen(api: _api)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New session'),
      ),
      body: AsyncView<List<CurfewSession>>(
        key: _listKey,
        load: _api.listSessions,
        builder: (context, sessions, reload) {
          if (sessions.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              Center(child: Text('No curfew sessions yet.\nTap "New session" to create one.', textAlign: TextAlign.center)),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = sessions[i];
              return ListTile(
                title: Row(children: [
                  Flexible(child: Text(s.name, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  SessionStateBadge(isActive: s.isActive, runningNow: s.runningNow, nextStartAt: s.nextStartAt),
                ]),
                subtitle: Text('${s.scheduleText}\n${s.studentCount} students'
                    '${s.pausedCount > 0 ? ' · ${s.pausedCount} paused' : ''}'),
                isThreeLine: true,
                trailing: Switch(value: s.isActive, onChanged: (on) => _toggle(s, on)),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => SessionDetailScreen(config: widget.config, sessionId: s.id)),
                  );
                  _reload();
                },
              );
            },
          );
        },
      ),
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
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${s.name}?'),
        content: Text('It is removed from ${s.studentCount} students. To stop it for a while, switch it off instead.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$added students added')));
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_session?.name ?? 'Session'),
          actions: [
            IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Live'), Tab(text: 'Students'), Tab(text: 'History')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Add students'),
        ),
        body: TabBarView(key: _key, children: [
          _LiveTab(api: _api, sessionId: widget.sessionId, onLoaded: (s) => _setSession(s), config: widget.config),
          _StudentsTab(config: widget.config, sessionId: widget.sessionId, onChanged: _reload),
          _HistoryList(api: _api, sessionId: widget.sessionId),
        ]),
      ),
    );
  }

  void _setSession(CurfewSession s) {
    if (_session?.updatedAt != s.updatedAt || _session?.name != s.name) {
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
        final theme = Theme.of(context);
        final s = live.session;
        final banner = !s.isActive
            ? 'Switched off: no phone enforces it.'
            : live.runningNow
                ? 'Running now for ${live.effectiveCount} students'
                    '${live.endsAt != null ? ' · ends ${shortWhen(live.endsAt!)}' : ''}'
                : 'Not running · next start ${live.nextStartAt != null ? shortWhen(live.nextStartAt!) : '—'}';
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            color: live.runningNow ? theme.colorScheme.primaryContainer : null,
            child: ListTile(
              leading: Icon(live.runningNow ? Icons.nightlight_round : Icons.schedule),
              title: Text(banner),
              subtitle: Text(s.scheduleText),
            ),
          ),
          Row(children: [
            Expanded(child: StatTile(value: '${live.effectiveCount}', label: 'Enforced on', help: 'Students in this session who are not paused.')),
            Expanded(child: StatTile(value: '${live.onlineCount}', label: 'Phones online')),
            Expanded(
              child: StatTile(
                value: '${live.usingPhone.length}',
                label: 'Using phone now',
                color: live.usingPhone.isEmpty ? null : Colors.red,
                help: 'Online with the screen on while this session is running.',
              ),
            ),
          ]),
          if (live.runningNow) ...[
            const SizedBox(height: 12),
            Text('Using the phone during ${s.name}', style: theme.textTheme.titleMedium),
            if (live.usingPhone.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Nobody. 👍')),
            for (final u in live.usingPhone)
              ListTile(
                leading: const ConnectionDot(status: 'online'),
                title: Text(u.student.name ?? '#${u.student.id}'),
                subtitle: Text('${u.currentApp ?? 'Unknown app'} · ${formatMinutes(u.sessionUseTodayMinutes)} in curfew today'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => config.openStudent(context, u.student.id),
              ),
          ],
        ]);
      },
    );
  }
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
          return ListView(children: const [SizedBox(height: 80), Center(child: Text('No students yet. Tap "Add students".'))]);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: detail.students.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Expanded(child: Text('${detail.total} students · switch off "Enforce" to pause for one student')),
                  const HelpIcon(text: 'Paused: the session is not enforced on this student\'s phone, '
                      'but stays on for everyone else. Turn it back on any time.'),
                ]),
              );
            }
            final st = detail.students[i - 1];
            return ListTile(
              title: Text(st.student.name ?? '#${st.student.id}'),
              subtitle: Text([
                st.student.subtitle,
                if (st.isPaused) 'Paused${st.pausedAt != null ? ' since ${shortDateTime(st.pausedAt!)}' : ''}',
                if (!st.isResident) 'No longer a resident',
              ].where((t) => t.isNotEmpty).join(' · ')),
              onTap: () => config.openStudent(context, st.student.id),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Tooltip(
                  message: 'Enforce on this phone',
                  child: Switch(
                    value: !st.isPaused,
                    onChanged: (enforce) async {
                      await runWithFeedback(context, () => api.setStudentPaused(sessionId, st.student.id, !enforce),
                          success: enforce ? 'Resumed for ${st.student.name}' : 'Paused for ${st.student.name}');
                      await reload();
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (_) async {
                    await runWithFeedback(
                      context,
                      () => api.removeStudents(sessionId, StudentSelection(studentIds: [st.student.id])),
                      success: '${st.student.name} removed',
                    );
                    onChanged();
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove from session'))],
                ),
              ]),
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

  static IconData _icon(String action) => switch (action) {
        'created' || 'migrated' => Icons.add_circle_outline,
        'edited' => Icons.edit_outlined,
        'switched_on' => Icons.toggle_on_outlined,
        'switched_off' => Icons.toggle_off_outlined,
        'deleted' => Icons.delete_outline,
        'students_added' => Icons.group_add_outlined,
        'students_removed' => Icons.group_remove_outlined,
        'student_paused' => Icons.pause_circle_outline,
        _ => Icons.play_circle_outline,
      };

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<SessionLogEntry>>(
      load: () => api.sessionHistory(sessionId: sessionId, limit: 200),
      builder: (context, entries, reload) {
        if (entries.isEmpty) return ListView(children: const [SizedBox(height: 80), Center(child: Text('No changes yet.'))]);
        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = entries[i];
            return ListTile(
              leading: Icon(_icon(e.action)),
              title: Text(e.message),
              subtitle: e.createdAt == null ? null : Text(shortDateTime(e.createdAt!)),
            );
          },
        );
      },
    );
  }
}

/// Every session's changes (opened from the sessions list).
class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key, required this.api});

  final ScreenTimeApi api;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Session history')),
        body: _HistoryList(api: api),
      );
}
