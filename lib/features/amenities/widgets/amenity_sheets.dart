import 'package:flutter/material.dart';

import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/network/repository/students/student_picker_source.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../utils/amenity_format.dart';

// Every sheet owns its text controllers in a State, so they live until the
// sheet has finished closing.

/// Opens a bottom sheet; true when it saved something.
Future<bool> _openSheet(BuildContext context, Widget sheet) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => sheet,
  );
  return saved == true;
}

/// Runs [action]; on success shows [success] and closes the sheet with true,
/// on failure shows the server's message and keeps the sheet open.
Future<void> _save(BuildContext context, Future<String?> Function() action, String success, void Function(bool) busy) async {
  busy(true);
  try {
    final warning = await action();
    if (!context.mounted) return;
    AppSnackbar.success('Saved', warning == null ? success : '$success\n$warning');
    Navigator.of(context).pop(true);
  } on ApiException catch (e) {
    AppSnackbar.error('Not Saved', e.message);
  } catch (_) {
    AppSnackbar.error('Not Saved', 'Something went wrong, try again.');
  } finally {
    if (context.mounted) busy(false);
  }
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String action;
  final bool busy;
  final VoidCallback? onSave;
  final Color color;

  const _SheetFrame({
    required this.title,
    this.subtitle,
    required this.children,
    required this.action,
    required this.busy,
    required this.onSave,
    this.color = PhonebookTheme.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2.5)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: PhonebookTheme.ink),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: PhonebookTheme.muted),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.muted, fontWeight: FontWeight.w500)),
            ],
            const Divider(height: 20, color: PhonebookTheme.border),
            ...children,
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: busy ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(action, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _field(TextEditingController c, String label,
        {String? hint, TextInputType? keyboard, int lines = 1, IconData? icon, int? max}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        minLines: lines,
        maxLines: lines,
        maxLength: max,
        decoration: phonebookInputDecoration(
          label: label,
          hint: hint,
          prefixIcon: icon == null ? null : Icon(icon, size: 20),
        ).copyWith(counterText: ''),
      ),
    );

class _ConditionPicker extends StatelessWidget {
  final AssetCondition? value;
  final ValueChanged<AssetCondition?> onChanged;
  final String label;

  const _ConditionPicker({required this.value, required this.onChanged, this.label = 'Condition'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: PhonebookTheme.slate)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in AssetCondition.values)
                PhonebookTintChip(
                  label: AmenityFormat.condition(c),
                  selected: value == c,
                  onTap: () => onChanged(value == c ? null : c),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A calendar date field ("YYYY-MM-DD" out), with a date picker.
class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DateField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final now = DateTime.now();
          final initial = DateTime.tryParse(value ?? '') ?? now;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(1990),
            lastDate: DateTime(now.year + 20),
          );
          if (picked != null) {
            onChanged('${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
          }
        },
        child: InputDecorator(
          decoration: phonebookInputDecoration(
            label: label,
            prefixIcon: const Icon(Icons.event_rounded, size: 20),
            suffixIcon: value == null
                ? null
                : IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => onChanged(null)),
          ),
          child: Text(value == null ? 'Not set' : AmenityFormat.date(value),
              style: TextStyle(color: value == null ? PhonebookTheme.muted : PhonebookTheme.ink)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- pickers

/// One student, from the shared directory (numeric `students.id` only;
/// residents and alumni).
Future<PickableStudent?> pickStudent(BuildContext context) => showModalBottomSheet<PickableStudent>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _StudentPicker(),
    );

class _StudentPicker extends StatefulWidget {
  const _StudentPicker();

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  final _search = TextEditingController();
  late final Future<List<PickableStudent>> _students = StudentPickerSource().load(includeAlumni: true);

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 8),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2.5)),
              ),
            ),
            TextField(
              controller: _search,
              autofocus: true,
              decoration: phonebookInputDecoration(hint: 'Search student name or room', prefixIcon: const Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<PickableStudent>>(
                future: _students,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  if (snap.hasError) return const Center(child: Text("Couldn't load students."));
                  final q = _search.text.trim().toLowerCase();
                  final list = (snap.data ?? const <PickableStudent>[])
                      .where((s) => q.isEmpty || s.name.toLowerCase().contains(q) || s.room.toLowerCase().contains(q))
                      .take(100)
                      .toList();
                  if (list.isEmpty) return const Center(child: Text('No students match.'));
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: PhonebookTheme.border),
                    itemBuilder: (_, i) {
                      final s = list[i];
                      return ListTile(
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(s.isAlumni ? 'Alumni' : 'Room ${s.room}'),
                        onTap: () => Navigator.of(context).pop(s),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A location from the tree (shown flat with its path).
Future<AmenityLocation?> pickLocation(BuildContext context, List<AmenityLocation> tree) => showModalBottomSheet<AmenityLocation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _LocationPicker(tree: tree),
    );

class _LocationPicker extends StatefulWidget {
  final List<AmenityLocation> tree;

  const _LocationPicker({required this.tree});

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final all = [
      for (final root in widget.tree)
        for (final l in root.flatten())
          if (l.isActive && (q.isEmpty || l.path.toLowerCase().contains(q))) l,
    ];
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 8),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2.5)),
              ),
            ),
            TextField(
              controller: _search,
              decoration: phonebookInputDecoration(hint: 'Search location or room', prefixIcon: const Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: all.isEmpty
                  ? const Center(child: Text('No locations. Add them under Locations.'))
                  : ListView.separated(
                      itemCount: all.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: PhonebookTheme.border),
                      itemBuilder: (_, i) => ListTile(
                        leading: Icon(_kindIcon(all[i].kind), color: PhonebookTheme.slate),
                        title: Text(all[i].path, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(AmenityFormat.locationKind(all[i].kind)),
                        onTap: () => Navigator.of(context).pop(all[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _kindIcon(LocationKind k) => switch (k) {
      LocationKind.building => Icons.apartment_rounded,
      LocationKind.wing => Icons.account_tree_outlined,
      LocationKind.floor => Icons.layers_outlined,
      LocationKind.room => Icons.meeting_room_outlined,
      LocationKind.area => Icons.place_outlined,
    };

IconData locationKindIcon(LocationKind k) => _kindIcon(k);

// ---------------------------------------------------------------- assign

/// Assign (or [transfer]) an asset, or a quantity of a bulk [type], to a
/// student or a location. True when saved.
Future<bool> showAssignSheet(
  BuildContext context, {
  required AmenitiesRepository repo,
  required List<AmenityLocation> locations,
  AmenityAsset? asset,
  AmenityType? type,
  bool transfer = false,
  bool studentsAllowed = true,
  PickableStudent? student,
}) =>
    _openSheet(
      context,
      _AssignSheet(
        repo: repo,
        locations: locations,
        asset: asset,
        type: type,
        transfer: transfer,
        studentsAllowed: studentsAllowed,
        student: student,
      ),
    );

class _AssignSheet extends StatefulWidget {
  final AmenitiesRepository repo;
  final List<AmenityLocation> locations;
  final AmenityAsset? asset;
  final AmenityType? type;
  final bool transfer;
  final bool studentsAllowed;
  final PickableStudent? student;

  const _AssignSheet({
    required this.repo,
    required this.locations,
    this.asset,
    this.type,
    required this.transfer,
    required this.studentsAllowed,
    this.student,
  });

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  late bool _toStudent = widget.studentsAllowed;
  late PickableStudent? _student = widget.student;
  AmenityLocation? _location;
  AssetCondition? _condition;
  String? _returnBy;
  final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _available => widget.type?.inventory['available'] ?? 0;

  Future<void> _submit() async {
    final AssignTarget target;
    if (_toStudent) {
      final s = _student;
      if (s == null) return AppSnackbar.warning('Choose a Student', 'Pick who gets it.');
      target = AssignTarget.student(s.id);
    } else {
      final l = _location;
      if (l == null) return AppSnackbar.warning('Choose a Location', 'Pick where it is installed.');
      target = AssignTarget.location(l.id);
    }
    final asset = widget.asset;
    final type = widget.type;
    int? qty;
    if (asset == null) {
      qty = int.tryParse(_quantity.text.trim());
      if (qty == null || qty < 1) return AppSnackbar.warning('Quantity', 'Enter how many.');
      if (qty > _available) {
        return AppSnackbar.warning('Not Enough', 'Only $_available ${type?.unit ?? ''} available.');
      }
    }
    final note = _note.text;
    await _save(
      context,
      () async {
        final AssignResult r;
        if (asset != null) {
          r = widget.transfer
              ? await widget.repo.transferAsset(asset.id, target, condition: _condition, note: note)
              : await widget.repo.assignAsset(asset.id, target, condition: _condition, expectedReturnDate: _returnBy, note: note);
        } else {
          r = await widget.repo.assignBulk(type!.id, target,
              quantity: qty!, condition: _condition, expectedReturnDate: _returnBy, note: note);
        }
        return r.warning;
      },
      widget.transfer ? 'Moved.' : 'Assigned.',
      (b) => setState(() => _busy = b),
    );
  }

  @override
  Widget build(BuildContext context) {
    final what = widget.asset != null ? '${widget.asset!.typeName} · ${widget.asset!.assetCode}' : (widget.type?.name ?? '');
    return _SheetFrame(
      title: widget.transfer ? 'Move $what' : 'Assign $what',
      subtitle: widget.asset == null ? '$_available ${widget.type?.unit ?? ''} available' : null,
      action: widget.transfer ? 'Move' : 'Assign',
      busy: _busy,
      onSave: _submit,
      children: [
        if (widget.studentsAllowed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: PhonebookTintChip(label: 'Student', icon: Icons.person_rounded, selected: _toStudent, onTap: () => setState(() => _toStudent = true))),
                const SizedBox(width: 8),
                Expanded(child: PhonebookTintChip(label: 'Location', icon: Icons.place_rounded, selected: !_toStudent, onTap: () => setState(() => _toStudent = false))),
              ],
            ),
          ),
        if (_toStudent)
          _PickTile(
            icon: Icons.person_search_rounded,
            text: _student == null ? 'Choose a student' : '${_student!.name} · ${_student!.isAlumni ? 'Alumni' : 'Room ${_student!.room}'}',
            onTap: () async {
              final s = await pickStudent(context);
              if (s != null) setState(() => _student = s);
            },
          )
        else
          _PickTile(
            icon: Icons.place_outlined,
            text: _location?.path ?? 'Choose a location',
            onTap: () async {
              final l = await pickLocation(context, widget.locations);
              if (l != null) setState(() => _location = l);
            },
          ),
        if (widget.asset == null) _field(_quantity, 'Quantity', keyboard: TextInputType.number, icon: Icons.numbers_rounded),
        _ConditionPicker(value: _condition, onChanged: (c) => setState(() => _condition = c)),
        if (!widget.transfer) _DateField(label: 'Expected return (optional)', value: _returnBy, onChanged: (v) => setState(() => _returnBy = v)),
        _field(_note, 'Note (optional)', lines: 2, max: 1000),
      ],
    );
  }
}

class _PickTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _PickTile({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: phonebookInputDecoration(prefixIcon: Icon(icon, size: 20), suffixIcon: const Icon(Icons.chevron_right_rounded)),
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- return

/// Return (close) an assignment. For bulk, part of the quantity can come back
/// and go to available, damaged or lost.
Future<bool> showReturnSheet(BuildContext context, {required AmenitiesRepository repo, required AmenityAssignment assignment}) =>
    _openSheet(context, _ReturnSheet(repo: repo, assignment: assignment));

class _ReturnSheet extends StatefulWidget {
  final AmenitiesRepository repo;
  final AmenityAssignment assignment;

  const _ReturnSheet({required this.repo, required this.assignment});

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  late final _quantity = TextEditingController(text: '${widget.assignment.outstanding}');
  final _note = TextEditingController();
  AssetCondition? _condition;
  BulkState _toState = BulkState.available;
  bool _busy = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final a = widget.assignment;
    int? qty;
    if (a.isBulk) {
      qty = int.tryParse(_quantity.text.trim());
      if (qty == null || qty < 1 || qty > a.outstanding) {
        return AppSnackbar.warning('Quantity', 'Between 1 and ${a.outstanding}.');
      }
    }
    await _save(
      context,
      () async {
        await widget.repo.returnAssignment(a.id,
            quantity: qty, condition: _condition, note: _note.text, toState: a.isBulk ? _toState : null);
        return null;
      },
      'Returned.',
      (b) => setState(() => _busy = b),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return _SheetFrame(
      title: 'Return ${a.title}',
      subtitle: a.student != null ? 'From ${a.student!.name}' : (a.location != null ? 'From ${a.location!.path}' : null),
      action: 'Return',
      busy: _busy,
      onSave: _submit,
      color: PhonebookTheme.green,
      children: [
        if (a.isBulk) ...[
          _field(_quantity, 'Quantity (of ${a.outstanding})', keyboard: TextInputType.number, icon: Icons.numbers_rounded),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 6,
              children: [
                for (final s in const [BulkState.available, BulkState.damaged, BulkState.lost])
                  PhonebookTintChip(label: 'To ${AmenityFormat.bulkState(s).toLowerCase()}', selected: _toState == s, onTap: () => setState(() => _toState = s)),
              ],
            ),
          ),
        ],
        _ConditionPicker(label: 'Condition now', value: _condition, onChanged: (c) => setState(() => _condition = c)),
        _field(_note, 'Note (optional)', lines: 2, max: 1000),
      ],
    );
  }
}

// ---------------------------------------------------------------- status

/// Change an asset's status (issue, repair, damaged, lost, active, retire).
Future<bool> showStatusSheet(BuildContext context, {required AmenitiesRepository repo, required AmenityAsset asset}) =>
    _openSheet(context, _StatusSheet(repo: repo, asset: asset));

class _StatusSheet extends StatefulWidget {
  final AmenitiesRepository repo;
  final AmenityAsset asset;

  const _StatusSheet({required this.repo, required this.asset});

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late AssetStatus _status = widget.asset.status;
  AssetCondition? _condition;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_status == widget.asset.status && _condition == null) {
      Navigator.of(context).pop(false);
      return;
    }
    if (_status == AssetStatus.retired) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Retire this item?'),
          content: const Text('It leaves the active register for good. Its whole history is kept.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Retire')),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    await _save(
      context,
      () async {
        await widget.repo.setStatus(widget.asset.id, _status, condition: _condition, note: _note.text);
        return null;
      },
      'Status updated.',
      (b) => setState(() => _busy = b),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Status of ${widget.asset.assetCode}',
      action: 'Save',
      busy: _busy,
      onSave: _submit,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in AssetStatus.values)
              PhonebookTintChip(
                label: AmenityFormat.status(s),
                color: AmenityFormat.statusColor(s),
                selected: _status == s,
                onTap: () => setState(() => _status = s),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _ConditionPicker(label: 'Condition (optional)', value: _condition, onChanged: (c) => setState(() => _condition = c)),
        _field(_note, 'What happened (optional)', lines: 2, max: 1000),
      ],
    );
  }
}

// ------------------------------------------------------------ add assets

/// Add [type] assets (individual) or stock (bulk).
Future<bool> showAddSheet(BuildContext context,
        {required AmenitiesRepository repo,
        required AmenityType type,
        required List<AmenityLocation> locations,
        AmenityLocation? home}) =>
    _openSheet(context, _AddSheet(repo: repo, type: type, locations: locations, home: home));

class _AddSheet extends StatefulWidget {
  final AmenitiesRepository repo;
  final AmenityType type;
  final List<AmenityLocation> locations;

  /// Where they belong (e.g. the room whose keys these are).
  final AmenityLocation? home;

  const _AddSheet({required this.repo, required this.type, required this.locations, this.home});

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _count = TextEditingController(text: '1');
  final _label = TextEditingController();
  final _serial = TextEditingController();
  final _cost = TextEditingController();
  final _vendor = TextEditingController();
  final _life = TextEditingController();
  final _notes = TextEditingController();
  String? _purchase;
  String? _installed;
  String? _warranty;
  AssetCondition? _condition = AssetCondition.newItem;
  late AmenityLocation? _home = widget.home;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_count, _label, _serial, _cost, _vendor, _life, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    final count = int.tryParse(_count.text.trim());
    final bulk = widget.type.isBulk;
    if (count == null || count < 1 || (!bulk && count > 200)) {
      return AppSnackbar.warning('How Many', bulk ? 'Enter a quantity of at least 1.' : 'Between 1 and 200 at a time.');
    }
    final cost = _t(_cost);
    if (cost != null && double.tryParse(cost) == null) return AppSnackbar.warning('Cost', 'Enter the cost as a number.');
    await _save(
      context,
      () async {
        if (bulk) {
          await widget.repo.addStock(widget.type.id,
              quantity: count, unitCost: cost, purchaseDate: _purchase, vendor: _t(_vendor), note: _t(_notes));
        } else {
          await widget.repo.createAssets({
            'type_id': widget.type.id,
            'count': count,
            'label': ?_t(_label),
            'serial_number': ?_t(_serial),
            'purchase_date': ?_purchase,
            'installation_date': ?_installed,
            'purchase_cost': ?cost,
            'vendor': ?_t(_vendor),
            'warranty_expiry': ?_warranty,
            if (int.tryParse(_life.text.trim()) != null) 'expected_life_months': int.parse(_life.text.trim()),
            if (_condition != null) 'condition': _condition!.api,
            'notes': ?_t(_notes),
            'home_location_id': ?_home?.id,
          });
        }
        return null;
      },
      bulk ? 'Stock added.' : '$count ${widget.type.name} added.',
      (b) => setState(() => _busy = b),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bulk = widget.type.isBulk;
    return _SheetFrame(
      title: bulk ? 'Add ${widget.type.name} stock' : 'Add ${widget.type.name}',
      subtitle: bulk ? 'Counted by quantity (${widget.type.unit})' : 'Each gets its own Asset ID (HSH-${widget.type.codePrefix}-…)',
      action: 'Add',
      busy: _busy,
      onSave: _submit,
      children: [
        _field(_count, bulk ? 'Quantity' : 'How many (1–200)', keyboard: TextInputType.number, icon: Icons.numbers_rounded),
        if (!bulk) ...[
          _field(_label, 'Label (optional)', hint: 'e.g. Copy 1', max: 120),
          _field(_serial, 'Serial number (optional)', max: 80),
        ],
        _DateField(label: 'Purchase date', value: _purchase, onChanged: (v) => setState(() => _purchase = v)),
        _field(_cost, bulk ? 'Cost per ${widget.type.unit} (₹)' : 'Purchase cost each (₹)', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.currency_rupee_rounded),
        _field(_vendor, 'Vendor / supplier', max: 120),
        if (!bulk) ...[
          _DateField(label: 'Installation date', value: _installed, onChanged: (v) => setState(() => _installed = v)),
          _DateField(label: 'Warranty until', value: _warranty, onChanged: (v) => setState(() => _warranty = v)),
          _field(_life, 'Expected life (months)', keyboard: TextInputType.number,
              hint: widget.type.defaultExpectedLifeMonths == null ? null : 'Default ${widget.type.defaultExpectedLifeMonths}'),
          _ConditionPicker(value: _condition, onChanged: (c) => setState(() => _condition = c)),
          _PickTile(
            icon: Icons.home_work_outlined,
            text: _home?.path ?? 'Home location (optional)',
            onTap: () async {
              final l = await pickLocation(context, widget.locations);
              if (l != null) setState(() => _home = l);
            },
          ),
        ],
        _field(_notes, 'Notes (optional)', lines: 2, max: 1000),
      ],
    );
  }
}

// ------------------------------------------------------------- move units

/// Move bulk units between states (e.g. 10 available → under repair).
Future<bool> showMoveUnitsSheet(BuildContext context, {required AmenitiesRepository repo, required AmenityType type}) =>
    _openSheet(context, _MoveSheet(repo: repo, type: type));

class _MoveSheet extends StatefulWidget {
  final AmenitiesRepository repo;
  final AmenityType type;

  const _MoveSheet({required this.repo, required this.type});

  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  static const _movable = [BulkState.available, BulkState.underRepair, BulkState.damaged, BulkState.lost, BulkState.retired];
  BulkState _from = BulkState.available;
  BulkState _to = BulkState.underRepair;
  final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  int _count(BulkState s) => widget.type.inventory[s.api];

  Future<void> _submit() async {
    final qty = int.tryParse(_quantity.text.trim());
    if (_from == _to) return AppSnackbar.warning('Same State', 'Choose a different "to".');
    if (qty == null || qty < 1 || qty > _count(_from)) {
      return AppSnackbar.warning('Quantity', 'Between 1 and ${_count(_from)}.');
    }
    await _save(
      context,
      () async {
        await widget.repo.moveBulk(widget.type.id, quantity: qty, from: _from, to: _to, note: _note.text);
        return null;
      },
      'Moved.',
      (b) => setState(() => _busy = b),
    );
  }

  Widget _states(String label, BulkState value, ValueChanged<BulkState> on) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: PhonebookTheme.slate)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _movable)
                  PhonebookTintChip(label: '${AmenityFormat.bulkState(s)} · ${_count(s)}', selected: value == s, onTap: () => on(s)),
              ],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Move ${widget.type.name} units',
      subtitle: 'Assigned units come back through their assignment (Return).',
      action: 'Move',
      busy: _busy,
      onSave: _submit,
      children: [
        _states('From', _from, (s) => setState(() => _from = s)),
        _states('To', _to, (s) => setState(() => _to = s)),
        _field(_quantity, 'Quantity', keyboard: TextInputType.number, icon: Icons.numbers_rounded),
        _field(_note, 'Note (optional)', lines: 2, max: 1000),
      ],
    );
  }
}
