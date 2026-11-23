import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';
import 'sessions_screen.dart';

/// Screen Time home for wardens: "is everything OK right now?" plus the
/// "needs attention" list. Leaders automatically see only their group.
class ScreenTimeOverviewScreen extends StatefulWidget {
  const ScreenTimeOverviewScreen({
    super.key,
    required this.config,
    this.floor,
    this.group,
    this.onOpenStudentList,
    this.showSessions = true,
  });

  /// The moon icon (curfew sessions): wardens and admins only, not leaders.
  final bool showSessions;

  final ScreenTimeAdminConfig config;
  final int? floor;
  final String? group;

  /// Opens the app's existing student list with a quick filter
  /// (`online`, `offline`, `using_in_session`, `over_limit`, ...).
  final void Function(BuildContext context, String filter)? onOpenStudentList;

  @override
  State<ScreenTimeOverviewScreen> createState() => _ScreenTimeOverviewScreenState();
}

class _ScreenTimeOverviewScreenState extends State<ScreenTimeOverviewScreen> {
  Key _key = UniqueKey();

  void _filter(String f) => widget.onOpenStudentList?.call(context, f);

  @override
  Widget build(BuildContext context) {
    final api = widget.config.api;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Time'),
        actions: [
          if (widget.showSessions)
          IconButton(
            tooltip: 'Curfew sessions',
            icon: const Icon(Icons.nightlight_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SessionsScreen(config: widget.config)));
              setState(() => _key = UniqueKey());
            },
          ),
        ],
      ),
      body: AsyncView<(ScreenTimeOverview, AttentionPage)>(
        key: _key,
        load: () async {
          final results = await Future.wait([
            api.overview(floor: widget.floor, group: widget.group),
            api.attention(floor: widget.floor, group: widget.group, limit: 5),
          ]);
          return (results[0] as ScreenTimeOverview, results[1] as AttentionPage);
        },
        builder: (context, data, reload) {
          final (o, attention) = data;
          final theme = Theme.of(context);
          return ListView(padding: const EdgeInsets.all(12), children: [
            // ---- right now ----
            for (final r in o.sessionsRunning)
              Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.nightlight_round),
                  title: Text('${r.name} running now: ${r.studentCount} students'),
                  subtitle: Text(r.usingPhoneCount == 0 ? 'Nobody is using their phone' : '${r.usingPhoneCount} using their phone'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => SessionDetailScreen(config: widget.config, sessionId: r.id)),
                  ),
                ),
              ),
            const _Section('Right now'),
            _Grid([
              StatTile(
                value: '${o.usingPhoneInSession}',
                label: 'Using phone in curfew',
                color: o.usingPhoneInSession > 0 ? Colors.red : null,
                help: 'Inside a curfew session right now, online, with the screen on.',
                onTap: () => _filter('using_in_session'),
              ),
              StatTile(value: '${o.inSession}', label: 'In curfew now', onTap: () => _filter('in_curfew_now')),
              StatTile(
                value: '${o.protectionRemoved}',
                label: 'Protection removed',
                color: o.protectionRemoved > 0 ? Colors.red : null,
                help: 'The phone reports that HSH removal protection (device admin) is off. '
                    'The student could uninstall the app.',
                onTap: () => _filter('protection_removed'),
              ),
              StatTile(value: '${o.locked}', label: 'Locked', onTap: () => _filter('locked')),
            ]),
            const _Section('Phones'),
            _Grid([
              StatTile(value: '${o.online}', label: 'Online', color: Colors.green,
                  help: 'Checked in within the last 10 minutes.', onTap: () => _filter('online')),
              StatTile(value: '${o.quiet}', label: 'Quiet', color: Colors.amber.shade800,
                  help: 'Last check-in 10–60 minutes ago. Usually the phone is idle or on poor network.',
                  onTap: () => _filter('quiet')),
              StatTile(value: '${o.offline}', label: 'Offline', color: Colors.red,
                  help: 'No check-in for more than 60 minutes.', onTap: () => _filter('offline')),
              StatTile(value: '${o.neverConnected}', label: 'Never connected',
                  help: 'Students whose phone has not sent any data in the last 30 days.'),
            ]),

            // ---- needs attention ----
            _Section('Needs attention (${o.attentionCount})',
                action: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AttentionScreen(config: widget.config, floor: widget.floor, group: widget.group),
                    ),
                  ),
                  child: const Text('See all'),
                )),
            if (attention.items.isEmpty) const Card(child: ListTile(title: Text('Nothing needs attention. 👍'))),
            for (final item in attention.items) AttentionTile(item: item, onTap: () => widget.config.openStudent(context, item.student.id)),
            _Grid([
              StatTile(value: '${o.pendingAppRequests}', label: 'App requests waiting'),
              StatTile(value: '${o.unreadAlerts}', label: 'Unread alerts'),
            ]),

            // ---- today ----
            const _Section('Today'),
            _Grid([
              StatTile(value: formatMinutes(o.avgScreenTimeToday), label: 'Average screen time'),
              StatTile(value: formatMinutes(o.totalSessionUseToday), label: 'Total use during curfew'),
              StatTile(value: '${o.overDailyLimit}', label: 'Over daily limit', onTap: () => _filter('over_limit')),
              StatTile(value: '${o.blockAttempts.values.fold<int>(0, (a, b) => a + b)}', label: 'Block attempts',
                  help: 'Times a phone stopped a blocked app, a curfew app or an install today.'),
            ]),
            if (o.topApps.isNotEmpty) ...[
              const _Section('Top apps today'),
              Card(
                child: Column(children: [
                  for (final a in o.topApps)
                    ListTile(dense: true, title: Text(a.appName), trailing: Text('${formatMinutes(a.minutes)} · ${a.students} students')),
                ]),
              ),
            ],

            // ---- week ----
            const _Section('Last 7 days'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Average ${formatMinutes(o.weekAvgScreenTime)} per student per day'
                      '${o.weekChangePct == null ? '' : ' (${o.weekChangePct! >= 0 ? '+' : ''}${o.weekChangePct}% vs last week)'}'),
                  const SizedBox(height: 12),
                  _WeekBars(days: o.trendDays),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class AttentionTile extends StatelessWidget {
  const AttentionTile({super.key, required this.item, this.onTap});

  final AttentionItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          leading: ConnectionDot(status: item.connectionStatus),
          title: Row(children: [
            Flexible(child: Text(item.student.name ?? '#${item.student.id}', overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            SeverityChip(severity: item.severity),
          ]),
          subtitle: Text([item.student.subtitle, ...item.reasons.map((r) => r.message)].where((t) => t.isNotEmpty).join('\n')),
          isThreeLine: item.reasons.length > 1,
        ),
      );
}

/// Full "needs attention" list with a type filter.
class AttentionScreen extends StatefulWidget {
  const AttentionScreen({super.key, required this.config, this.floor, this.group});

  final ScreenTimeAdminConfig config;
  final int? floor;
  final String? group;

  @override
  State<AttentionScreen> createState() => _AttentionScreenState();
}

class _AttentionScreenState extends State<AttentionScreen> {
  String? _type;

  static const _types = {
    'protection_removed': 'Protection removed',
    'session_use': 'Used phone in curfew',
    'offline': 'Offline',
    'over_limit': 'Over limit',
    'block_attempts': 'Many block attempts',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Needs attention')),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            ChoiceChip(label: const Text('All'), selected: _type == null, onSelected: (_) => setState(() => _type = null)),
            for (final t in _types.entries)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(label: Text(t.value), selected: _type == t.key, onSelected: (_) => setState(() => _type = t.key)),
              ),
          ]),
        ),
        Expanded(
          child: AsyncView<AttentionPage>(
            key: ValueKey(_type),
            load: () => widget.config.api.attention(floor: widget.floor, group: widget.group, type: _type, limit: 500),
            builder: (context, page, reload) => page.items.isEmpty
                ? ListView(children: const [SizedBox(height: 80), Center(child: Text('Nothing here. 👍'))])
                : ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                    for (final item in page.items)
                      AttentionTile(item: item, onTap: () => widget.config.openStudent(context, item.student.id)),
                  ]),
          ),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ?action,
        ]),
      );
}

class _Grid extends StatelessWidget {
  const _Grid(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final columns = c.maxWidth > 600 ? 4 : 2;
        final width = (c.maxWidth - (columns - 1) * 4) / columns;
        return Wrap(spacing: 4, runSpacing: 4, children: [for (final w in children) SizedBox(width: width, child: w)]);
      });
}

/// Simple bar per day (average minutes per student), no chart package needed.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});

  final List<TrendDay> days;

  @override
  Widget build(BuildContext context) {
    final max = days.fold<int>(1, (m, d) => d.avgScreenTimeMinutes > m ? d.avgScreenTimeMinutes : m);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 120,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final d in days)
          Expanded(
            child: Tooltip(
              message: '${d.date}: ${formatMinutes(d.avgScreenTimeMinutes)} avg, ${formatMinutes(d.avgSessionUseMinutes)} in curfew',
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(
                  height: 80 * d.avgScreenTimeMinutes / max,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 4),
                Text(labels[(DateTime.tryParse(d.date)?.weekday ?? 1) - 1], style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
      ]),
    );
  }
}
