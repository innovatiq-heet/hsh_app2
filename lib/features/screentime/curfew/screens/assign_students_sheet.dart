import 'package:flutter/material.dart';

import '../models.dart';
import '../screen_time_api.dart';

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
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (c, scroll) => _AssignSheet(
        api: api,
        session: session,
        floorOptions: floorOptions,
        groupOptions: groupOptions,
        tagOptions: tagOptions,
        pickStudents: pickStudents,
        scroll: scroll,
      ),
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
    required this.scroll,
  });

  final ScreenTimeApi api;
  final CurfewSession session;
  final List<int> floorOptions;
  final List<String> groupOptions;
  final Map<int, String> tagOptions;
  final StudentPicker? pickStudents;
  final ScrollController scroll;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _preview;
    return Column(children: [
      Expanded(
        child: ListView(controller: widget.scroll, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
          Text('Add students to ${widget.session.name}', style: theme.textTheme.titleLarge),
          Text(widget.session.scheduleText, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('All residents'),
            subtitle: const Text('Every current hostel resident'),
            value: _all,
            onChanged: (v) {
              setState(() => _all = v);
              _refreshPreview();
            },
          ),
          if (!_all) ...[
            if (widget.pickStudents != null) ...[
              const _Heading('Students'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in _picked)
                  InputChip(
                    label: Text(s.name ?? '#${s.id}'),
                    onDeleted: () {
                      setState(() => _picked.remove(s));
                      _refreshPreview();
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Pick students'),
                  onPressed: () async {
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
            ],
            if (widget.floorOptions.isNotEmpty) ...[
              const _Heading('Floors'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final f in widget.floorOptions)
                  FilterChip(label: Text(f == 0 ? 'Ground' : 'Floor $f'), selected: _floors.contains(f), onSelected: (on) => _toggle(_floors, f, on)),
              ]),
            ],
            if (widget.groupOptions.isNotEmpty) ...[
              const _Heading('Groups'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final g in widget.groupOptions)
                  FilterChip(label: Text(g), selected: _groups.contains(g), onSelected: (on) => _toggle(_groups, g, on)),
              ]),
            ],
            if (widget.tagOptions.isNotEmpty) ...[
              const _Heading('Tags'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in widget.tagOptions.entries)
                  FilterChip(label: Text(t.value), selected: _tags.contains(t.key), onSelected: (on) => _toggle(_tags, t.key, on)),
              ]),
            ],
          ],
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          if (p != null && !_busy) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p.toAddCount} will be added', style: theme.textTheme.titleMedium),
                  if (p.alreadyAssignedCount > 0) Text('${p.alreadyAssignedCount} already in this session'),
                  if (p.noDeviceCount > 0) Text('${p.noDeviceCount} have no phone linked yet (it applies once they log in)'),
                  if (p.invalidStudentIds.isNotEmpty)
                    Text('${p.invalidStudentIds.length} picked student(s) have left or are inactive',
                        style: TextStyle(color: theme.colorScheme.error)),
                  if (p.sample.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('For example:', style: theme.textTheme.bodySmall),
                    for (final s in p.sample) Text('• ${s.name ?? '#${s.id}'}  ${s.subtitle}'),
                  ],
                ]),
              ),
            ),
          ],
        ]),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy || p == null || p.toAddCount == 0 || p.invalidStudentIds.isNotEmpty ? null : _confirm,
              child: Text(p == null ? 'Choose students' : 'Add ${p.toAddCount} students'),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}
