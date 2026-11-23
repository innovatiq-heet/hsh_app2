import 'package:flutter/material.dart';

import '../models.dart';
import '../screen_time_api.dart';
import '../widgets/common.dart';

/// Picks students from the app's own picker (e.g. a search over
/// `GET /screen-time/students?search=`). Must return numeric `students.id`s.
typedef StudentPicker = Future<List<StudentRef>?> Function(BuildContext context);

/// Bulk "Add students" sheet: pick students, floors, groups, tags or all
/// residents, see the preview ("312 will be added, 8 already in, 5 have no
/// phone"), then confirm. Returns the number added, or null when cancelled.
Future<int?> showAssignStudentsSheet(
  BuildContext context, {
  required ScreenTimeApi api,
  required CurfewSession session,
  List<int> floorOptions = const [],
  List<String> groupOptions = const [],
  Map<int, String> tagOptions = const {},
  StudentPicker? pickStudents,
}) {
  return showStSheet<int>(
    context,
    _AssignSheet(
      api: api,
      session: session,
      floorOptions: floorOptions,
      groupOptions: groupOptions,
      tagOptions: tagOptions,
      pickStudents: pickStudents,
    ),
  );
}

class _AssignSheet extends StatefulWidget {
  const _AssignSheet({
    required this.api,
    required this.session,
    required this.floorOptions,
    required this.groupOptions,
    required this.tagOptions,
    required this.pickStudents,
  });

  final ScreenTimeApi api;
  final CurfewSession session;
  final List<int> floorOptions;
  final List<String> groupOptions;
  final Map<int, String> tagOptions;
  final StudentPicker? pickStudents;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  final List<StudentRef> _picked = [];
  final Set<int> _floors = {};
  final Set<String> _groups = {};
  final Set<int> _tags = {};
  bool _all = false;

  SelectionPreview? _preview;
  String? _error;
  bool _busy = false;

  StudentSelection get _selection => StudentSelection(
        studentIds: _picked.map((s) => s.id).toList(),
        floorIds: _floors.toList(),
        groups: _groups.toList(),
        tagIds: _tags.toList(),
        allActive: _all,
      );

  /// Re-runs the preview after every change of the selection.
  Future<void> _refreshPreview() async {
    if (_selection.isEmpty) return setState(() => _preview = null);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await widget.api.previewStudents(_selection, sessionId: widget.session.id);
      if (mounted) setState(() => _preview = p);
    } on ScreenTimeApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle<T>(Set<T> set, T value, bool on) {
    setState(() => on ? set.add(value) : set.remove(value));
    _refreshPreview();
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final added = await widget.api.addStudents(widget.session.id, _selection);
      if (mounted) Navigator.pop(context, added);
    } on ScreenTimeApiException catch (e) {
      final invalid = (e.data?['invalid_student_ids'] as List?)?.length ?? 0;
      if (mounted) {
        setState(() {
          _busy = false;
          _error = invalid > 0 ? '${e.message}. Remove them from the picked list and try again.' : e.message;
        });
      }
    }
  }

  Widget _chipGroup(String label, List<Widget> chips) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: [
            SheetTitle(
              icon: Icons.group_add_outlined,
              title: 'Add students',
              subtitle: '${widget.session.name} · ${widget.session.scheduleText}',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: _all ? StPalette.accentSoft : StPalette.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _all ? StPalette.accentBorder : StPalette.border),
              ),
              child: Row(children: [
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('All residents', style: TextStyle(fontWeight: FontWeight.w700, color: StPalette.ink)),
                    Text('Every current hostel resident', style: TextStyle(fontSize: 12, color: StPalette.textSecondary)),
                  ]),
                ),
                Switch(
                  value: _all,
                  activeThumbColor: Colors.white,
                  activeTrackColor: StPalette.accent,
                  onChanged: (v) {
                    setState(() => _all = v);
                    _refreshPreview();
                  },
                ),
              ]),
            ),
            if (!_all) ...[
              if (widget.pickStudents != null)
                _chipGroup('Students', [
                  for (final s in _picked)
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: StPalette.accentSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: StPalette.accentBorder),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(s.name ?? '#${s.id}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: StPalette.accentDark)),
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            setState(() => _picked.remove(s));
                            _refreshPreview();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.close_rounded, size: 15, color: StPalette.accentDark),
                          ),
                        ),
                      ]),
                    ),
                  StChoice(
                    label: 'Pick students',
                    icon: Icons.person_add_alt_rounded,
                    selected: false,
                    onTap: () async {
                      final more = await widget.pickStudents!(context);
                      if (more == null || !mounted) return;
                      setState(() {
                        for (final s in more) {
                          if (!_picked.any((x) => x.id == s.id)) _picked.add(s);
                        }
                      });
                      _refreshPreview();
                    },
                  ),
                ]),
              if (widget.floorOptions.isNotEmpty)
                _chipGroup('Floors', [
                  for (final f in widget.floorOptions)
                    StChoice(
                      label: f == 0 ? 'Ground' : 'Floor $f',
                      selected: _floors.contains(f),
                      onTap: () => _toggle(_floors, f, !_floors.contains(f)),
                    ),
                ]),
              if (widget.groupOptions.isNotEmpty)
                _chipGroup('Groups', [
                  for (final g in widget.groupOptions)
                    StChoice(label: g, selected: _groups.contains(g), onTap: () => _toggle(_groups, g, !_groups.contains(g))),
                ]),
              if (widget.tagOptions.isNotEmpty)
                _chipGroup('Tags', [
                  for (final t in widget.tagOptions.entries)
                    StChoice(
                      label: t.value,
                      selected: _tags.contains(t.key),
                      onTap: () => _toggle(_tags, t.key, !_tags.contains(t.key)),
                    ),
                ]),
            ],
            const SizedBox(height: 18),
            if (_busy)
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                child: LinearProgressIndicator(minHeight: 4, color: StPalette.accent, backgroundColor: StPalette.accentSoft),
              ),
            if (_error != null) NoteBox(text: _error!, icon: Icons.error_outline_rounded, color: StPalette.red),
            if (p != null && !_busy) _PreviewCard(preview: p),
          ]),
        ),
        Container(
          decoration: const BoxDecoration(
            color: StPalette.card,
            border: Border(top: BorderSide(color: StPalette.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: StPrimaryButton(
                label: p == null ? 'Choose students above' : 'Add ${p.toAddCount} students',
                busy: _busy && p != null,
                onPressed: p == null || p.toAddCount == 0 || p.invalidStudentIds.isNotEmpty ? null : _confirm,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final SelectionPreview preview;

  @override
  Widget build(BuildContext context) {
    final p = preview;
    Widget line(IconData icon, String text, Color color) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: StPalette.text))),
          ]),
        );
    return SurfaceCard(
      color: StPalette.bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${p.toAddCount}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: StPalette.accent, height: 1)),
          const SizedBox(width: 8),
          const Text('will be added', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: StPalette.ink)),
        ]),
        if (p.alreadyAssignedCount > 0)
          line(Icons.check_circle_outline_rounded, '${p.alreadyAssignedCount} already in this session', StPalette.green),
        if (p.noDeviceCount > 0)
          line(Icons.phonelink_off_rounded, '${p.noDeviceCount} have no phone linked yet (it applies once they log in)',
              StPalette.amber),
        if (p.invalidStudentIds.isNotEmpty)
          line(Icons.error_outline_rounded, '${p.invalidStudentIds.length} picked student(s) have left or are inactive',
              StPalette.red),
        if (p.sample.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('For example', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: StPalette.textMuted)),
          for (final s in p.sample)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${s.name ?? '#${s.id}'}${s.subtitle.isEmpty ? '' : '  ·  ${s.subtitle}'}',
                  style: const TextStyle(fontSize: 12.5, color: StPalette.text)),
            ),
        ],
      ]),
    );
  }
}
