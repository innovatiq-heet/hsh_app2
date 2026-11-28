import 'package:flutter/material.dart';

import '../curfew_admin_entry.dart';
import '../curfew_schedule.dart';
import '../models.dart';
import '../screens/sessions_screen.dart';
import 'common.dart';

/// Screen Time page → "Night Curfew": every curfew (session) with its times,
/// days, state and an on/off switch, plus "Add curfew". Phones block apps
/// while any switched-on curfew they are in is running. Same flows as the
/// Curfew sessions screen ([createCurfewSession], [toggleCurfewSession]).
///
/// [footer] sits under the list (the campus geofence window, which only
/// reports leaving the campus and never locks phones).
class NightCurfewCard extends StatefulWidget {
  const NightCurfewCard({super.key, this.footer});

  final Widget? footer;

  @override
  State<NightCurfewCard> createState() => _NightCurfewCardState();
}

class _NightCurfewCardState extends State<NightCurfewCard> {
  ScreenTimeAdminConfig? _config;
  List<CurfewSession>? _sessions;
  String? _error;
  bool _loading = true;
  bool _expanded = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = _config ??= await CurfewAdminEntry.adminConfig();
      final sessions = await config.api.listSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final config = _config ??= await CurfewAdminEntry.adminConfig();
    if (!mounted) return;
    if (await createCurfewSession(context, config)) {
      if (mounted) setState(() => _expanded = true);
      await _load();
    }
  }

  Future<void> _toggle(CurfewSession s, bool on) async {
    final config = _config;
    if (config == null || _busy.contains(s.id)) return;
    setState(() => _busy.add(s.id));
    final ok = await toggleCurfewSession(context, config.api, s, on);
    if (!mounted) return;
    setState(() => _busy.remove(s.id));
    if (ok) await _load();
  }

  Future<void> _open(CurfewSession s) async {
    final config = _config;
    if (config == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => SessionDetailScreen(config: config, sessionId: s.id)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions ?? const <CurfewSession>[];
    final on = sessions.where((s) => s.isActive).length;
    final running = sessions.where((s) => s.isActive && s.runningNow).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: running > 0 ? const Color(0xFFF0FDF4) : StPalette.accentSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            running > 0 ? Icons.nightlight_round : Icons.nightlight_outlined,
                            color: running > 0 ? const Color(0xFF16A34A) : StPalette.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Night Curfew',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _loading && _sessions == null
                                    ? 'Loading curfews…'
                                    : '${sessions.length} curfew${sessions.length == 1 ? '' : 's'} · $on on · $running running',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: StPalette.accent,
                  backgroundColor: StPalette.accentSoft,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOutCubic,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        if (_loading && _sessions == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                          )
                        else if (_error != null && _sessions == null)
                          Row(
                            children: [
                              Expanded(
                                child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                              ),
                              TextButton(onPressed: _load, child: const Text('Retry')),
                            ],
                          )
                        else if (sessions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'No curfews yet. Add one, like "Night Curfew" 22:00–06:00 every day, then choose its students.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                            ),
                          )
                        else
                          for (final s in sessions)
                            _CurfewRow(
                              session: s,
                              busy: _busy.contains(s.id),
                              onTap: () => _open(s),
                              onToggle: (v) => _toggle(s, v),
                            ),
                      ],
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
          if (widget.footer != null) ...[
            const Divider(height: 14, color: Color(0xFFF1F5F9)),
            widget.footer!,
          ],
        ],
      ),
    );
  }
}

class _CurfewRow extends StatelessWidget {
  const _CurfewRow({required this.session, required this.busy, required this.onTap, required this.onToggle});

  final CurfewSession session;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: s.isActive ? StPalette.ink : StPalette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.startTime} – ${s.endTime} · ${describeDays(s.days)} · ${s.studentCount} students',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: StPalette.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  SessionStateBadge(isActive: s.isActive, runningNow: s.runningNow, nextStartAt: s.nextStartAt),
                ],
              ),
            ),
            SizedBox(
              width: 56,
              child: busy
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : Switch(
                      value: s.isActive,
                      activeThumbColor: Colors.white,
                      activeTrackColor: StPalette.accent,
                      onChanged: onToggle,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
