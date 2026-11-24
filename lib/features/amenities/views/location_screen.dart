import 'package:flutter/material.dart';

import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../widgets/amenity_sheets.dart';
import 'amenity_type_screen.dart';
import 'asset_detail_screen.dart';

/// A room or area: what is installed there, what is kept there (e.g. the
/// room's spare keys), and for a room each resident with their items. It
/// replaces the old Room Keys room screen: give a key to a resident, take it
/// back, open a key to mark it lost or found, add keys.
class LocationScreen extends StatefulWidget {
  final int? locationId;

  /// Opens the room with this number instead (old Room Keys links).
  final String? roomNumber;
  final AmenitiesRepository? repository;

  const LocationScreen({super.key, this.locationId, this.roomNumber, this.repository})
      : assert(locationId != null || roomNumber != null);

  static Future<void> open(BuildContext context, int locationId) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LocationScreen(locationId: locationId)));

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  late final AmenitiesRepository _repo = widget.repository ?? AmenitiesRepository();
  List<AmenityLocation> _tree = const [];
  int? _id;
  LocationAmenities? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _id = widget.locationId;
    _load();
  }

  static String _norm(String? r) => (r ?? '').trim().toUpperCase();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _tree = await _repo.locations();
      if (_id == null) {
        final wanted = _norm(widget.roomNumber);
        final room = _tree
            .expand((l) => l.flatten())
            .where((l) => l.kind == LocationKind.room && _norm(l.roomNumber ?? l.name) == wanted)
            .firstOrNull;
        if (room == null) throw ApiException('Room $wanted is not in the locations yet. Add it under Locations.');
        _id = room.id;
      }
      final data = await _repo.locationAmenities(_id!);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    } catch (_) {
      if (mounted) setState(() => (_error = "Couldn't load this location.", _loading = false));
    }
  }

  List<AmenityAsset> get _spare => [
        for (final a in _data?.homeAssets ?? const <AmenityAsset>[])
          if (a.placement == AssetPlacement.inStore && a.status == AssetStatus.active) a,
      ];

  /// Gives one of the items kept here (e.g. a spare key) to [student].
  Future<void> _give(StudentBrief student) async {
    final spare = _spare;
    if (spare.isEmpty) {
      AppSnackbar.info('Nothing Kept Here', 'Add items to this room first (button below).');
      return;
    }
    final asset = await showModalBottomSheet<AmenityAsset>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Give to ${student.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final a in spare)
              ListTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text('${a.typeName}${a.label == null ? '' : ' · ${a.label}'}'),
                subtitle: Text('${a.assetCode}${a.serialNumber == null ? '' : ' · No. ${a.serialNumber}'}'),
                onTap: () => Navigator.of(c).pop(a),
              ),
          ],
        ),
      ),
    );
    if (asset == null || !mounted) return;
    final ok = await showAssignSheet(
      context,
      repo: _repo,
      locations: _tree,
      asset: asset,
      student: PickableStudent(id: student.id, name: student.name, room: student.room ?? ''),
    );
    if (ok) await _load();
  }

  Future<void> _return(AmenityAssignment a) async {
    if (await showReturnSheet(context, repo: _repo, assignment: a)) await _load();
  }

  Future<void> _openItem(AmenityAssignment a) async {
    if (a.asset != null) {
      await AssetDetailScreen.open(context, a.asset!.id);
    } else if (a.typeId != null) {
      await AmenityTypeScreen.open(context, a.typeId!);
    }
    if (mounted) await _load();
  }

  Future<void> _addHere() async {
    final types = await _repo.types().catchError((_) => <AmenityType>[]);
    if (!mounted) return;
    final individual = types.where((t) => t.isActive && !t.isBulk).toList();
    if (individual.isEmpty) {
      AppSnackbar.info('No Amenity Types', 'Create one under Categories & types first.');
      return;
    }
    final type = await showModalBottomSheet<AmenityType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Add here', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              for (final t in individual)
                ListTile(
                  title: Text(t.name),
                  subtitle: Text(t.categoryName ?? ''),
                  onTap: () => Navigator.of(c).pop(t),
                ),
            ],
          ),
        ),
      ),
    );
    if (type == null || !mounted) return;
    final here = _tree.expand((l) => l.flatten()).where((l) => l.id == _id).firstOrNull;
    if (await showAddSheet(context, repo: _repo, type: type, locations: _tree, home: here)) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final loc = d?.location;
    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF032B4F),
        foregroundColor: Colors.white,
        title: Text(
          loc == null ? (widget.roomNumber == null ? 'Location' : 'Room ${widget.roomNumber}') : (loc.kind == LocationKind.room ? 'Room ${loc.roomNumber ?? loc.name}' : loc.name),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: d == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'location_add',
              backgroundColor: PhonebookTheme.blue,
              foregroundColor: Colors.white,
              onPressed: _addHere,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add here'),
            ),
      body: _loading && d == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : (_error != null && d == null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: PhonebookTheme.slate)),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _load, child: const Text('Retry')),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    children: [
                      if (loc != null)
                        Text(loc.path, style: const TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      if (d!.residents.isNotEmpty) ...[
                        const PhonebookSectionHeader(title: 'Residents'),
                        for (final r in d.residents) _ResidentCard(
                          student: r.student,
                          items: r.items,
                          onGive: () => _give(r.student),
                          onReturn: _return,
                          onOpen: _openItem,
                        ),
                        const SizedBox(height: 8),
                      ],
                      const PhonebookSectionHeader(title: 'Installed here'),
                      if (d.installed.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text('Nothing installed here yet.', style: TextStyle(color: PhonebookTheme.muted)),
                        )
                      else
                        for (final a in d.installed)
                          AssignmentTile(
                            assignment: a,
                            showItem: true,
                            onTap: () => _openItem(a),
                            trailing: IconButton(
                              tooltip: 'Take back',
                              onPressed: () => _return(a),
                              icon: const Icon(Icons.keyboard_return_rounded, color: PhonebookTheme.green),
                            ),
                          ),
                      const PhonebookSectionHeader(title: 'Kept here (in store)'),
                      if (d.homeAssets.isEmpty)
                        const Text('Nothing kept here.', style: TextStyle(color: PhonebookTheme.muted))
                      else
                        for (final a in d.homeAssets)
                          AssetTile(asset: a, onTap: () async {
                            await AssetDetailScreen.open(context, a.id);
                            if (mounted) await _load();
                          }),
                    ],
                  ),
                ),
    );
  }
}

class _ResidentCard extends StatelessWidget {
  final StudentBrief student;
  final List<AmenityAssignment> items;
  final VoidCallback onGive;
  final ValueChanged<AmenityAssignment> onReturn;
  final ValueChanged<AmenityAssignment> onOpen;

  const _ResidentCard({
    required this.student,
    required this.items,
    required this.onGive,
    required this.onReturn,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PhonebookCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person_rounded, color: PhonebookTheme.blue),
            const SizedBox(width: 8),
            Expanded(child: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w800, color: PhonebookTheme.ink))),
            TextButton.icon(onPressed: onGive, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Give')),
          ]),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 32, bottom: 6),
              child: Text('No items.', style: TextStyle(color: PhonebookTheme.muted, fontSize: 12.5)),
            )
          else
            for (final a in items)
              InkWell(
                onTap: () => onOpen(a),
                child: Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Row(children: [
                    Expanded(
                      child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600, color: PhonebookTheme.slate)),
                    ),
                    IconButton(
                      tooltip: 'Take back',
                      onPressed: () => onReturn(a),
                      icon: const Icon(Icons.keyboard_return_rounded, size: 20, color: PhonebookTheme.green),
                    ),
                  ]),
                ),
              ),
        ]),
      ),
    );
  }
}
