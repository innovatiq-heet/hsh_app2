import 'package:flutter/material.dart';

import '../../../shared/widgets/navy_sliver_header.dart';
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

  final ScreenTimeAdminConfig config;
  final int? floor;
  final String? group;

  /// The moon icon (curfew sessions): wardens and admins only, not leaders.
  final bool showSessions;

  /// Opens the students behind a tile (`online`, `offline`,
  /// `using_in_session`, `over_limit`, ...).
  final void Function(BuildContext context, String filter)? onOpenStudentList;

  @override
  State<ScreenTimeOverviewScreen> createState() => _ScreenTimeOverviewScreenState();
}

class _ScreenTimeOverviewScreenState extends State<ScreenTimeOverviewScreen> {
  Key _key = UniqueKey();

  void _filter(String f) => widget.onOpenStudentList?.call(context, f);

  Future<void> _openSessions() async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SessionsScreen(config: widget.config)));
    if (mounted) setState(() => _key = UniqueKey());
  }

  void _openAttention() => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AttentionScreen(config: widget.config, floor: widget.floor, group: widget.group),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final api = widget.config.api;
    return CurfewPage(
      title: 'Screen Time Overview',
      subtitle: widget.group == null ? 'Right now, today and this week' : '${widget.group} group',
      actions: [
        if (widget.showSessions)
          NavyHeaderAction(icon: Icons.nightlight_outlined, tooltip: 'Curfew sessions', onTap: _openSessions),
      ],
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
          final blockAttempts = o.blockAttempts.values.fold<int>(0, (a, b) => a + b);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
            // ---- right now ----
            _RightNowHero(
              overview: o,
              onUsing: () => _filter('using_in_session'),
              onSession: (id) => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => SessionDetailScreen(config: widget.config, sessionId: id)),
              ),
            ),
            const SizedBox(height: 10),
            TileGrid([
              StatTile(
                icon: Icons.nightlight_round,
                value: '${o.inSession}',
                label: 'In curfew now',
                onTap: () => _filter('in_curfew_now'),
              ),
              StatTile(
                icon: Icons.lock_outline_rounded,
                value: '${o.locked}',
                label: 'Phones locked',
                onTap: () => _filter('locked'),
              ),
              StatTile(
                icon: Icons.shield_outlined,
                value: '${o.protectionRemoved}',
                label: 'Protection removed',
                color: o.protectionRemoved > 0 ? StPalette.red : null,
                help: 'The phone reports that HSH removal protection (device admin) is off. '
                    'The student could uninstall the app.',
                onTap: () => _filter('protection_removed'),
              ),
              StatTile(
                icon: Icons.timer_off_outlined,
                value: '${o.overDailyLimit}',
                label: 'Over daily limit',
                color: o.overDailyLimit > 0 ? StPalette.amber : null,
                onTap: () => _filter('over_limit'),
              ),
            ]),

            // ---- phones ----
            const SectionHeader('Phones', icon: Icons.smartphone_rounded),
            _ConnectionCard(overview: o, onTap: _filter),

            // ---- needs attention ----
            SectionHeader(
              'Needs attention · ${o.attentionCount}',
              icon: Icons.flag_outlined,
              action: SectionAction(label: 'See all', onTap: _openAttention),
            ),
            if (attention.items.isEmpty)
              const SurfaceCard(
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, color: StPalette.green),
                  SizedBox(width: 10),
                  Expanded(child: Text('Nothing needs attention.', style: TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
            for (final item in attention.items) ...[
              AttentionTile(item: item, onTap: () => widget.config.openStudent(context, item.student.id)),
              const SizedBox(height: 8),
            ],
            if (o.pendingAppRequests > 0 || o.unreadAlerts > 0) ...[
              const SizedBox(height: 2),
              Row(children: [
                Expanded(child: _MiniCount(icon: Icons.apps_rounded, value: o.pendingAppRequests, label: 'App requests waiting')),
                const SizedBox(width: 10),
                Expanded(child: _MiniCount(icon: Icons.notifications_none_rounded, value: o.unreadAlerts, label: 'Unread alerts')),
              ]),
            ],

            // ---- today ----
            const SectionHeader('Today', icon: Icons.today_outlined),
            TileGrid([
              StatTile(icon: Icons.hourglass_bottom_rounded, value: formatMinutes(o.avgScreenTimeToday), label: 'Average screen time'),
              StatTile(
                icon: Icons.bedtime_outlined,
                value: formatMinutes(o.totalSessionUseToday),
                label: 'Total use during curfew',
                color: o.totalSessionUseToday > 0 ? StPalette.amber : null,
              ),
              StatTile(
                icon: Icons.block_rounded,
                value: '$blockAttempts',
                label: 'Block attempts',
                help: 'Times a phone stopped a blocked app, a curfew app or an install today.',
              ),
              StatTile(
                icon: Icons.wifi_rounded,
                value: '${o.online}',
                label: 'Online now',
                color: StPalette.green,
                onTap: () => _filter('online'),
              ),
            ]),
            if (o.topApps.isNotEmpty) ...[
              const SectionHeader('Top apps today', icon: Icons.apps_rounded),
              _TopAppsCard(apps: o.topApps),
            ],

            // ---- week ----
            const SectionHeader('Last 7 days', icon: Icons.insights_rounded),
            _WeekCard(overview: o),
          ]);
        },
      ),
    );
  }
}

/// Navy hero: who is using the phone inside a curfew right now, and the
/// sessions running.
class _RightNowHero extends StatelessWidget {
  const _RightNowHero({required this.overview, required this.onUsing, required this.onSession});

  final ScreenTimeOverview overview;
  final VoidCallback onUsing;
  final void Function(int id) onSession;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final using = o.usingPhoneInSession;
    final running = o.sessionsRunning;
    return SurfaceCard(
      gradient: StPalette.heroGradient,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('RIGHT NOW',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              )),
          const Spacer(),
          if (running.isNotEmpty)
            StPill(
              text: '${running.length} running',
              color: Colors.white,
              background: Colors.white.withValues(alpha: 0.18),
              icon: Icons.nightlight_round,
            ),
        ]),
        const SizedBox(height: 10),
        InkWell(
          onTap: onUsing,
          borderRadius: BorderRadius.circular(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$using',
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, height: 1, letterSpacing: -1)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  using == 1 ? 'student using the phone in curfew' : 'students using the phone in curfew',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.7)),
          ]),
        ),
        if (running.isEmpty) ...[
          const SizedBox(height: 10),
          Text('No curfew session is running.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
        ],
        for (final r in running) ...[
          const SizedBox(height: 10),
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSession(r.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.nightlight_round, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(
                        '${r.studentCount} students · '
                        '${r.usingPhoneCount == 0 ? 'nobody on the phone' : '${r.usingPhoneCount} on the phone'}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                      ),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.7)),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Online / quiet / offline as one stacked bar with a tappable legend.
class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.overview, required this.onTap});

  final ScreenTimeOverview overview;
  final void Function(String filter) onTap;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final parts = [
      ('online', 'Online', o.online, 'Checked in within the last 10 minutes.'),
      ('quiet', 'Quiet', o.quiet, 'Last check-in 10–60 minutes ago. Usually idle or on poor network.'),
      ('offline', 'Offline', o.offline, 'No check-in for more than 60 minutes.'),
    ];
    final total = parts.fold<int>(0, (a, p) => a + p.$3);
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${o.totalStudents}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: StPalette.ink)),
          const SizedBox(width: 6),
          const Text('students', style: TextStyle(fontSize: 13, color: StPalette.textSecondary)),
          const Spacer(),
          if (o.neverConnected > 0)
            StPill(text: '${o.neverConnected} never connected', color: StPalette.textSecondary),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: total == 0
                ? Container(color: StPalette.divider)
                : Row(children: [
                    for (final p in parts)
                      if (p.$3 > 0) Expanded(flex: p.$3, child: Container(color: ConnectionDot.colorOf(p.$1))),
                  ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          for (final p in parts)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onTap(p.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      ConnectionDot(status: p.$1),
                      const SizedBox(width: 6),
                      Text(p.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: StPalette.textSecondary)),
                      HelpIcon(text: p.$4),
                    ]),
                    const SizedBox(height: 2),
                    Text('${p.$3}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: StPalette.ink)),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _MiniCount extends StatelessWidget {
  const _MiniCount({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          IconBadge(icon: icon, size: 32, color: value > 0 ? StPalette.amber : StPalette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StPalette.ink)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: StPalette.textSecondary)),
            ]),
          ),
        ]),
      );
}

class _TopAppsCard extends StatelessWidget {
  const _TopAppsCard({required this.apps});

  final List<TopApp> apps;

  @override
  Widget build(BuildContext context) {
    final max = apps.fold<int>(1, (m, a) => a.minutes > m ? a.minutes : m);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(children: [
        for (var i = 0; i < apps.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(children: [
            SizedBox(
              width: 22,
              child: Text('${i + 1}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: StPalette.textMuted)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(apps[i].appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: StPalette.ink)),
                  ),
                  Text(formatMinutes(apps[i].minutes),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: StPalette.accent)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: apps[i].minutes / max,
                    minHeight: 6,
                    backgroundColor: StPalette.accentSoft,
                    color: StPalette.accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text('${apps[i].students} students',
                    style: const TextStyle(fontSize: 11.5, color: StPalette.textMuted)),
              ]),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// Average screen time per day (bar) with the curfew share on top.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.overview});

  final ScreenTimeOverview overview;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final days = o.trendDays;
    final change = o.weekChangePct;
    final max = days.fold<int>(1, (m, d) => d.avgScreenTimeMinutes > m ? d.avgScreenTimeMinutes : m);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Wraps: on a narrow phone the change pill goes under the average.
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: formatMinutes(o.weekAvgScreenTime),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: StPalette.ink),
                ),
                const TextSpan(
                  text: '  per student per day',
                  style: TextStyle(fontSize: 12.5, color: StPalette.textSecondary),
                ),
              ]),
            ),
            if (change != null)
              StPill(
                text: '${change >= 0 ? '+' : ''}$change% vs last week',
                color: change > 0 ? StPalette.red : StPalette.green,
                icon: change > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 130,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final d in days)
              Expanded(
                child: Tooltip(
                  message: '${d.date}: ${formatMinutes(d.avgScreenTimeMinutes)} avg, '
                      '${formatMinutes(d.avgSessionUseMinutes)} in curfew',
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(
                      d.avgScreenTimeMinutes == 0 ? '' : '${(d.avgScreenTimeMinutes / 60).toStringAsFixed(1)}h',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: StPalette.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 84 * d.avgScreenTimeMinutes / max + 2,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [StPalette.accent, StPalette.accentDark],
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
                      ),
                      alignment: Alignment.topCenter,
                      child: d.avgSessionUseMinutes > 0 && d.avgScreenTimeMinutes > 0
                          ? FractionallySizedBox(
                              heightFactor: (d.avgSessionUseMinutes / d.avgScreenTimeMinutes).clamp(0.0, 1.0),
                              widthFactor: 1,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: StPalette.amberBright,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(labels[(DateTime.tryParse(d.date)?.weekday ?? 1) - 1],
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: StPalette.textSecondary)),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        const Row(children: [
          _Legend(color: StPalette.accent, label: 'Screen time'),
          SizedBox(width: 16),
          _Legend(color: StPalette.amberBright, label: 'During curfew'),
        ]),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, color: StPalette.textSecondary)),
      ]);
}

class AttentionTile extends StatelessWidget {
  const AttentionTile({super.key, required this.item, this.onTap});

  final AttentionItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = SeverityChip.colorOf(item.severity);
    final name = item.student.name ?? '#${item.student.id}';
    return SurfaceCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InitialsAvatar(name: name, status: item.connectionStatus, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: StPalette.ink)),
                      ),
                      const SizedBox(width: 8),
                      SeverityChip(severity: item.severity),
                    ]),
                    if (item.student.subtitle.isNotEmpty)
                      Text(item.student.subtitle, style: const TextStyle(fontSize: 12, color: StPalette.textMuted)),
                    const SizedBox(height: 4),
                    for (final r in item.reasons)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(color: SeverityChip.colorOf(r.severity), shape: BoxShape.circle),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(r.message,
                                style: const TextStyle(fontSize: 12.5, color: StPalette.textSecondary, height: 1.3)),
                          ),
                        ]),
                      ),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: StPalette.textLight),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
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

  Widget _chip(String label, String? type) {
    final selected = _type == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _type = type),
        selectedColor: StPalette.accent,
        backgroundColor: StPalette.card,
        side: BorderSide(color: selected ? StPalette.accent : StPalette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : StPalette.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CurfewPage(
      title: 'Needs Attention',
      subtitle: 'Students to check on, most urgent first',
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            _chip('All', null),
            for (final t in _types.entries) _chip(t.value, t.key),
          ]),
        ),
        Expanded(
          child: AsyncView<AttentionPage>(
            key: ValueKey(_type),
            load: () => widget.config.api.attention(floor: widget.floor, group: widget.group, type: _type, limit: 500),
            builder: (context, page, reload) => page.items.isEmpty
                ? const EmptyBlock(icon: Icons.check_circle_outline_rounded, title: 'Nothing here', message: 'No student needs attention.')
                : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                    for (final item in page.items) ...[
                      AttentionTile(item: item, onTap: () => widget.config.openStudent(context, item.student.id)),
                      const SizedBox(height: 8),
                    ],
                  ]),
          ),
        ),
      ]),
    );
  }
}
