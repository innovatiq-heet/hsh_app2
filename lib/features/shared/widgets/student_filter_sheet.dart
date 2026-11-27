import 'package:flutter/material.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/models/tags/student_tag_model.dart';
import 'phonebook_style_widgets.dart';

/// What the student picker is narrowed to. Choices in one section widen it
/// (floor 1 or 2); sections narrow each other (floor 1 and group Param).
class StudentFilter {
  final Set<int> floors;
  final Set<String> groups;
  final Set<int> tagIds;

  const StudentFilter({this.floors = const {}, this.groups = const {}, this.tagIds = const {}});

  static const none = StudentFilter();

  int get count => floors.length + groups.length + tagIds.length;
  bool get isEmpty => count == 0;

  bool matches(PickableStudent s) =>
      (floors.isEmpty || floors.contains(s.floor)) &&
      (groups.isEmpty || groups.contains(s.group)) &&
      (tagIds.isEmpty || s.tags.any((t) => tagIds.contains(t.id)));

  static String floorLabel(int floor) => floor == 0 ? 'Ground' : 'Floor $floor';
}

/// Group, floor and tag choices, laid out like the Phonebook's filter sheet.
/// They are built from the students that were loaded (a section with nothing to
/// offer is left out).
class StudentFilterSheet extends StatefulWidget {
  final List<PickableStudent> students;
  final StudentFilter initial;

  /// How many students the list would show with a filter.
  final int Function(StudentFilter) countFor;

  const StudentFilterSheet({super.key, required this.students, required this.initial, required this.countFor});

  /// The chosen filter, or null when the sheet is dismissed.
  static Future<StudentFilter?> show(
    BuildContext context, {
    required List<PickableStudent> students,
    required StudentFilter initial,
    required int Function(StudentFilter) countFor,
  }) {
    return showModalBottomSheet<StudentFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // The sheet draws its own handle.
      showDragHandle: false,
      builder: (_) => StudentFilterSheet(students: students, initial: initial, countFor: countFor),
    );
  }

  @override
  State<StudentFilterSheet> createState() => _StudentFilterSheetState();
}

class _StudentFilterSheetState extends State<StudentFilterSheet> {
  static const _tagColor = Color(0xFF6366F1);
  static const _chipText = Color(0xFF334155);

  late final Set<int> _floors = {...widget.initial.floors};
  late final Set<String> _groups = {...widget.initial.groups};
  late final Set<int> _tagIds = {...widget.initial.tagIds};

  late final List<int> _floorOptions = {for (final s in widget.students) ?s.floor}.toList()..sort();
  late final List<String> _groupOptions = {
    for (final s in widget.students)
      if (s.group.isNotEmpty) s.group,
  }.toList()
    ..sort();
  late final List<StudentTag> _tagOptions = {
    for (final s in widget.students)
      for (final t in s.tags) t.id: t,
  }.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  StudentFilter get _draft => StudentFilter(floors: {..._floors}, groups: {..._groups}, tagIds: {..._tagIds});

  void _toggle<T>(Set<T> set, T value) => setState(() {
        if (!set.remove(value)) set.add(value);
      });

  void _reset() => setState(() {
        _floors.clear();
        _groups.clear();
        _tagIds.clear();
      });

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final nothing = _floorOptions.isEmpty && _groupOptions.isEmpty && _tagOptions.isEmpty;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(draft),
          const Divider(height: 1, color: PhonebookTheme.border),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nothing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Text(
                        'There is nothing to filter these students by.',
                        style: TextStyle(fontSize: 13, color: PhonebookTheme.muted),
                      ),
                    ),
                  if (_groupOptions.isNotEmpty)
                    _section('HOSTEL WING / GROUP', Icons.apartment_rounded, [
                      for (final g in _groupOptions)
                        _chip(
                          key: ValueKey('group-$g'),
                          label: g,
                          selected: _groups.contains(g),
                          onTap: () => _toggle(_groups, g),
                        ),
                    ]),
                  if (_floorOptions.isNotEmpty)
                    _section('HOSTEL FLOOR', Icons.layers_rounded, [
                      for (final f in _floorOptions)
                        _chip(
                          key: ValueKey('floor-$f'),
                          label: StudentFilter.floorLabel(f),
                          selected: _floors.contains(f),
                          onTap: () => _toggle(_floors, f),
                        ),
                    ]),
                  if (_tagOptions.isNotEmpty)
                    _section('STUDENT TAGS & ROLES', Icons.label_rounded, [
                      for (final t in _tagOptions)
                        _chip(
                          key: ValueKey('tag-${t.id}'),
                          label: t.name,
                          color: _tagColor,
                          selected: _tagIds.contains(t.id),
                          onTap: () => _toggle(_tagIds, t.id),
                        ),
                    ]),
                ],
              ),
            ),
          ),
          _buildApplyBar(draft),
        ],
      ),
    );
  }

  Widget _buildHeader(StudentFilter draft) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PhonebookTheme.blueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: PhonebookTheme.blue, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Students',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: PhonebookTheme.ink),
                    ),
                    Text(
                      'Refine by wings, floors and tags',
                      style: TextStyle(fontSize: 11.5, color: PhonebookTheme.muted),
                    ),
                  ],
                ),
              ),
              if (!draft.isEmpty)
                TextButton(
                  onPressed: _reset,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: const Text('Reset All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: PhonebookTheme.muted, size: 22),
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: PhonebookTheme.blue),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: PhonebookTheme.slate,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  Widget _chip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color color = PhonebookTheme.blue,
  }) {
    return FilterChip(
      key: key,
      label: Text(label),
      selected: selected,
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : _chipText,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        fontSize: 12.5,
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? color : PhonebookTheme.border),
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildApplyBar(StudentFilter draft) {
    final n = widget.countFor(draft);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: PhonebookTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(draft),
            style: ElevatedButton.styleFrom(
              backgroundColor: PhonebookTheme.blue,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(
              'Apply Filters & Show ($n ${n == 1 ? 'Student' : 'Students'})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}
