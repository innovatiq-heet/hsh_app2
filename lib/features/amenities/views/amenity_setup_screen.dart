import 'package:flutter/material.dart';

import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../utils/amenity_format.dart';
import 'amenity_type_screen.dart';

/// Categories & types: everything per kind of asset is set up here, so a
/// new kind (e.g. "Solar Panel") needs no app change.
class AmenitySetupScreen extends StatefulWidget {
  final AmenitiesRepository? repository;

  const AmenitySetupScreen({super.key, this.repository});

  @override
  State<AmenitySetupScreen> createState() => _AmenitySetupScreenState();
}

class _AmenitySetupScreenState extends State<AmenitySetupScreen> {
  late final AmenitiesRepository _repo = widget.repository ?? AmenitiesRepository();
  List<AmenityCategory> _categories = const [];
  List<AmenityType> _types = const [];
  bool _loading = true;
  String? _error;

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
      final r = await Future.wait([_repo.categories(includeInactive: true), _repo.types(includeInactive: true)]);
      if (!mounted) return;
      setState(() {
        _categories = (r[0] as List<AmenityCategory>)..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _types = r[1] as List<AmenityType>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    } catch (_) {
      if (mounted) setState(() => (_error = "Couldn't load the setup.", _loading = false));
    }
  }

  Future<void> _editCategory([AmenityCategory? c]) async {
    if (await showCategoryForm(context, repo: _repo, existing: c)) await _load();
  }

  Future<void> _editType({AmenityType? t, int? categoryId}) async {
    if (await showTypeForm(context, repo: _repo, categories: _categories, existing: t, categoryId: categoryId)) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF032B4F),
        foregroundColor: Colors.white,
        title: const Text('Categories & types', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'amenity_setup_add',
        backgroundColor: PhonebookTheme.blue,
        foregroundColor: Colors.white,
        onPressed: () => _editCategory(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Category'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: PhonebookTheme.slate)),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    children: [
                      if (_categories.isEmpty)
                        const Text('No categories yet. Add one, e.g. Electrical, Plumbing, Furniture or Security / Keys.',
                            style: TextStyle(color: PhonebookTheme.muted)),
                      for (final c in _categories) ...[
                        _CategoryCard(
                          category: c,
                          types: _types.where((t) => t.categoryId == c.id).toList(),
                          onEdit: () => _editCategory(c),
                          onAddType: () => _editType(categoryId: c.id),
                          onEditType: (t) => _editType(t: t),
                          onOpenType: (t) async {
                            await AmenityTypeScreen.open(context, t.id);
                            if (mounted) await _load();
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final AmenityCategory category;
  final List<AmenityType> types;
  final VoidCallback onEdit;
  final VoidCallback onAddType;
  final ValueChanged<AmenityType> onEditType;
  final ValueChanged<AmenityType> onOpenType;

  const _CategoryCard({
    required this.category,
    required this.types,
    required this.onEdit,
    required this.onAddType,
    required this.onEditType,
    required this.onOpenType,
  });

  @override
  Widget build(BuildContext context) {
    final color = AmenityFormat.color(category.color);
    return Opacity(
      opacity: category.isActive ? 1 : 0.55,
      child: PhonebookCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(AmenityFormat.icon(category.icon), color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(category.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: PhonebookTheme.ink)),
                Text('${types.length} types${category.isActive ? '' : ' · inactive'}',
                    style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted)),
              ]),
            ),
            IconButton(tooltip: 'Edit category', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)),
          ]),
          for (final t in types)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 46),
              title: Text(t.name, style: TextStyle(fontWeight: FontWeight.w700, color: t.isActive ? PhonebookTheme.ink : PhonebookTheme.muted)),
              subtitle: Text(
                '${t.isBulk ? 'By quantity · ${t.unit}' : 'HSH-${t.codePrefix}-…'}${t.isActive ? '' : ' · inactive'}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => onOpenType(t),
              trailing: IconButton(tooltip: 'Edit type', onPressed: () => onEditType(t), icon: const Icon(Icons.tune_rounded, size: 20)),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: TextButton.icon(onPressed: onAddType, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add type')),
          ),
        ]),
      ),
    );
  }
}

// ----------------------------------------------------------------- forms

Future<bool> _sheet(BuildContext context, Widget child) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => child,
    ) ==
    true;

Widget _frame(BuildContext context, {required String title, required List<Widget> children, required bool busy, required VoidCallback onSave}) =>
    Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
          const SizedBox(height: 16),
          ...children,
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: busy ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: PhonebookTheme.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );

Widget _text(TextEditingController c, String label, {String? hint, TextInputType? keyboard, int lines = 1, bool enabled = true, int? max}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        enabled: enabled,
        keyboardType: keyboard,
        minLines: lines,
        maxLines: lines,
        maxLength: max,
        decoration: phonebookInputDecoration(label: label, hint: hint).copyWith(counterText: ''),
      ),
    );

/// Runs a save; true closes the sheet. Shows the server's message otherwise.
Future<void> _run(BuildContext context, Future<void> Function() action, void Function(bool) busy) async {
  busy(true);
  try {
    await action();
    if (!context.mounted) return;
    AppSnackbar.success('Saved', 'Changes saved.');
    Navigator.of(context).pop(true);
  } on ApiException catch (e) {
    AppSnackbar.error('Not Saved', e.message);
  } catch (_) {
    AppSnackbar.error('Not Saved', 'Something went wrong, try again.');
  } finally {
    if (context.mounted) busy(false);
  }
}

Future<bool> showCategoryForm(BuildContext context, {required AmenitiesRepository repo, AmenityCategory? existing}) =>
    _sheet(context, _CategoryForm(repo: repo, existing: existing));

class _CategoryForm extends StatefulWidget {
  final AmenitiesRepository repo;
  final AmenityCategory? existing;

  const _CategoryForm({required this.repo, this.existing});

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  static const _palette = ['#F59E0B', '#0284C7', '#059669', '#DC2626', '#9333EA', '#DB2777', '#0D9488', '#475569'];
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _order = TextEditingController(text: '${widget.existing?.sortOrder ?? 0}');
  late String? _icon = widget.existing?.icon ?? 'inventory';
  late String? _color = widget.existing?.color ?? _palette.first;
  late bool _active = widget.existing?.isActive ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return AppSnackbar.warning('Name', 'Give the category a name.');
    final body = <String, dynamic>{
      'name': name,
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'icon': _icon,
      'color': _color,
      'sort_order': int.tryParse(_order.text.trim()) ?? 0,
      'is_active': _active,
    };
    final e = widget.existing;
    // Partial update: only what changed.
    final changes = e == null
        ? body
        : {
            if (name != e.name) 'name': name,
            if (body['description'] != e.description) 'description': body['description'],
            if (_icon != e.icon) 'icon': _icon,
            if (_color != e.color) 'color': _color,
            if (body['sort_order'] != e.sortOrder) 'sort_order': body['sort_order'],
            if (_active != e.isActive) 'is_active': _active,
          };
    if (e != null && changes.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    await _run(context, () async {
      if (e == null) {
        await widget.repo.createCategory(changes);
      } else {
        await widget.repo.updateCategory(e.id, changes);
      }
    }, (b) => setState(() => _busy = b));
  }

  @override
  Widget build(BuildContext context) {
    return _frame(
      context,
      title: widget.existing == null ? 'New category' : 'Edit category',
      busy: _busy,
      onSave: _save,
      children: [
        _text(_name, 'Name', hint: 'e.g. Electrical', max: 120),
        _text(_desc, 'Description (optional)', lines: 2, max: 1000),
        const Text('Icon', style: TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.slate)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in AmenityFormat.icons.entries)
            InkWell(
              onTap: () => setState(() => _icon = e.key),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _icon == e.key ? PhonebookTheme.blueSoft : PhonebookTheme.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _icon == e.key ? PhonebookTheme.blue : PhonebookTheme.border),
                ),
                child: Icon(e.value, size: 20, color: PhonebookTheme.slate),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        const Text('Colour', style: TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.slate)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final hex in _palette)
            InkWell(
              onTap: () => setState(() => _color = hex),
              customBorder: const CircleBorder(),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AmenityFormat.color(hex),
                  shape: BoxShape.circle,
                  border: Border.all(color: _color == hex ? PhonebookTheme.ink : Colors.white, width: 2.5),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        _text(_order, 'Order in lists', keyboard: TextInputType.number),
        if (widget.existing != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Active'),
            subtitle: const Text('Inactive categories are hidden from new items. History is kept.'),
          ),
      ],
    );
  }
}

Future<bool> showTypeForm(BuildContext context,
        {required AmenitiesRepository repo, required List<AmenityCategory> categories, AmenityType? existing, int? categoryId}) =>
    _sheet(context, _TypeForm(repo: repo, categories: categories, existing: existing, categoryId: categoryId));

class _TypeForm extends StatefulWidget {
  final AmenitiesRepository repo;
  final List<AmenityCategory> categories;
  final AmenityType? existing;
  final int? categoryId;

  const _TypeForm({required this.repo, required this.categories, this.existing, this.categoryId});

  @override
  State<_TypeForm> createState() => _TypeFormState();
}

class _TypeFormState extends State<_TypeForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _prefix = TextEditingController(text: widget.existing?.codePrefix ?? '');
  late final _unit = TextEditingController(text: widget.existing?.unit ?? 'pcs');
  late final _life = TextEditingController(text: '${widget.existing?.defaultExpectedLifeMonths ?? ''}');
  late final _interval = TextEditingController(text: '${widget.existing?.maintenanceIntervalDays ?? ''}');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late int? _category = widget.existing?.categoryId ?? widget.categoryId ?? widget.categories.firstOrNull?.id;
  late TrackingMode _tracking = widget.existing?.tracking ?? TrackingMode.individual;
  late bool _students = widget.existing?.assignableToStudents ?? false;
  late bool _active = widget.existing?.isActive ?? true;
  bool _busy = false;

  /// The prefix is fixed once the type has items (codes must never change).
  bool get _prefixLocked => (widget.existing?.inventory['total'] ?? 0) > 0 || (widget.existing?.inventory['retired'] ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _prefix.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _prefix, _unit, _life, _interval, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  static final _prefixPattern = RegExp(r'^[A-Z0-9]{2,6}$');

  Future<void> _save() async {
    final name = _name.text.trim();
    final prefix = _prefix.text.trim().toUpperCase();
    if (_category == null) return AppSnackbar.warning('Category', 'Choose a category.');
    if (name.isEmpty) return AppSnackbar.warning('Name', 'Give the type a name.');
    if (!_prefixPattern.hasMatch(prefix)) return AppSnackbar.warning('Asset ID prefix', '2–6 letters or digits, e.g. FAN.');
    final body = <String, dynamic>{
      'category_id': _category,
      'name': name,
      'code_prefix': prefix,
      'unit': _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'default_expected_life_months': int.tryParse(_life.text.trim()),
      'maintenance_interval_days': int.tryParse(_interval.text.trim()),
      'assignable_to_students': _students,
    };
    final e = widget.existing;
    final Map<String, dynamic> payload;
    if (e == null) {
      payload = {...body, 'tracking': _tracking.name};
    } else {
      payload = {
        if (_category != e.categoryId) 'category_id': _category,
        if (name != e.name) 'name': name,
        if (prefix != e.codePrefix && !_prefixLocked) 'code_prefix': prefix,
        if (body['unit'] != e.unit) 'unit': body['unit'],
        if (body['description'] != e.description) 'description': body['description'],
        if (body['default_expected_life_months'] != e.defaultExpectedLifeMonths) 'default_expected_life_months': body['default_expected_life_months'],
        if (body['maintenance_interval_days'] != e.maintenanceIntervalDays) 'maintenance_interval_days': body['maintenance_interval_days'],
        if (_students != e.assignableToStudents) 'assignable_to_students': _students,
        if (_active != e.isActive) 'is_active': _active,
      };
      if (payload.isEmpty) {
        Navigator.of(context).pop(false);
        return;
      }
    }
    await _run(context, () async {
      if (e == null) {
        await widget.repo.createType(payload);
      } else {
        await widget.repo.updateType(e.id, payload);
      }
    }, (b) => setState(() => _busy = b));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.existing;
    final prefix = _prefix.text.trim().toUpperCase();
    return _frame(
      context,
      title: e == null ? 'New amenity type' : 'Edit ${e.name}',
      busy: _busy,
      onSave: _save,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<int>(
            initialValue: _category,
            isExpanded: true,
            decoration: phonebookInputDecoration(label: 'Category'),
            items: [for (final c in widget.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() => _category = v),
          ),
        ),
        _text(_name, 'Name', hint: 'e.g. Ceiling Fan, Plastic Chair, Solar Panel', max: 120),
        if (e == null) ...[
          const Text('How is it counted?', style: TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.slate)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: PhonebookTintChip(
                label: 'Each item (ID + QR)',
                selected: _tracking == TrackingMode.individual,
                onTap: () => setState(() => _tracking = TrackingMode.individual),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PhonebookTintChip(
                label: 'By quantity',
                selected: _tracking == TrackingMode.bulk,
                onTap: () => setState(() => _tracking = TrackingMode.bulk),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('This cannot change later.', style: TextStyle(fontSize: 11.5, color: PhonebookTheme.muted)),
          const SizedBox(height: 12),
        ],
        _text(_prefix, 'Asset ID prefix', hint: 'e.g. FAN', enabled: !_prefixLocked, max: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _prefixLocked ? 'Fixed: this type already has items.' : 'Asset IDs look like HSH-${prefix.isEmpty ? 'FAN' : prefix}-00001',
            style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted),
          ),
        ),
        _text(_unit, 'Unit', hint: 'pcs, set, pair…', max: 20),
        _text(_life, 'Expected life (months, optional)', keyboard: TextInputType.number),
        _text(_interval, 'Service every (days, optional)', keyboard: TextInputType.number),
        _text(_desc, 'Description (optional)', lines: 2, max: 1000),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _students,
          onChanged: (v) => setState(() => _students = v),
          title: const Text('Can be given to students'),
          subtitle: const Text('e.g. keys, mattresses, chairs'),
        ),
        if (e != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Active'),
            subtitle: const Text('Inactive types take no new items. History is kept.'),
          ),
      ],
    );
  }
}

Future<bool> showLocationForm(BuildContext context,
        {required AmenitiesRepository repo, AmenityLocation? existing, AmenityLocation? parent}) =>
    _sheet(context, _LocationForm(repo: repo, existing: existing, parent: parent));

class _LocationForm extends StatefulWidget {
  final AmenitiesRepository repo;
  final AmenityLocation? existing;
  final AmenityLocation? parent;

  const _LocationForm({required this.repo, this.existing, this.parent});

  @override
  State<_LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends State<_LocationForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _room = TextEditingController(text: widget.existing?.roomNumber ?? '');
  late LocationKind _kind = widget.existing?.kind ?? _defaultKind(widget.parent?.kind);
  late bool _active = widget.existing?.isActive ?? true;
  bool _busy = false;

  static LocationKind _defaultKind(LocationKind? parent) => switch (parent) {
        null => LocationKind.building,
        LocationKind.building => LocationKind.floor,
        LocationKind.wing => LocationKind.floor,
        _ => LocationKind.room,
      };

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final room = _room.text.trim().toUpperCase();
    final name = _name.text.trim().isEmpty && _kind == LocationKind.room ? room : _name.text.trim();
    if (name.isEmpty) return AppSnackbar.warning('Name', 'Give it a name.');
    if (_kind == LocationKind.room && room.isEmpty) return AppSnackbar.warning('Room number', 'Enter the room number.');
    final e = widget.existing;
    final payload = e == null
        ? {
            'parent_id': ?widget.parent?.id,
            'kind': _kind.name,
            'name': name,
            if (_kind == LocationKind.room) 'room_number': room,
          }
        : {
            if (name != e.name) 'name': name,
            if (_kind == LocationKind.room && room != (e.roomNumber ?? '')) 'room_number': room,
            if (_active != e.isActive) 'is_active': _active,
          };
    if (e != null && payload.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    await _run(context, () async {
      if (e == null) {
        await widget.repo.createLocation(payload);
      } else {
        await widget.repo.updateLocation(e.id, payload);
      }
    }, (b) => setState(() => _busy = b));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.existing;
    return _frame(
      context,
      title: e == null ? (widget.parent == null ? 'New building or area' : 'Add inside ${widget.parent!.name}') : 'Edit ${e.name}',
      busy: _busy,
      onSave: _save,
      children: [
        if (e == null) ...[
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in LocationKind.values)
              PhonebookTintChip(label: AmenityFormat.locationKind(k), selected: _kind == k, onTap: () => setState(() => _kind = k)),
          ]),
          const SizedBox(height: 12),
        ],
        if (_kind == LocationKind.room) _text(_room, 'Room number', hint: 'e.g. 204', max: 20),
        _text(_name, _kind == LocationKind.room ? 'Name (optional)' : 'Name',
            hint: switch (_kind) {
              LocationKind.building => 'e.g. Pavitra House',
              LocationKind.wing => 'e.g. East wing',
              LocationKind.floor => 'e.g. Floor 2',
              LocationKind.room => 'Defaults to the room number',
              LocationKind.area => 'e.g. Common area, Kitchen, Office',
            },
            max: 120),
        if (e != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Active'),
            subtitle: const Text('Inactive places are hidden from pickers. History is kept.'),
          ),
      ],
    );
  }
}
