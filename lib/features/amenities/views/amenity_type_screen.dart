import 'package:flutter/material.dart';

import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../utils/amenity_format.dart';
import '../widgets/amenity_sheets.dart';
import 'asset_detail_screen.dart';

/// One amenity type: its inventory and, for individual types, its assets;
/// for bulk types, the stock actions and its assignments.
class AmenityTypeScreen extends StatefulWidget {
  final int typeId;
  final AmenitiesRepository? repository;

  const AmenityTypeScreen({super.key, required this.typeId, this.repository});

  static Future<void> open(BuildContext context, int typeId) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AmenityTypeScreen(typeId: typeId)));

  @override
  State<AmenityTypeScreen> createState() => _AmenityTypeScreenState();
}

class _AmenityTypeScreenState extends State<AmenityTypeScreen> {
  late final AmenitiesRepository _repo = widget.repository ?? AmenitiesRepository();
  AmenityType? _type;
  List<AmenityAsset> _assets = const [];
  int _assetTotal = 0;
  List<AmenityAssignment> _assignments = const [];
  List<AmenityLocation>? _locations;
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
      final type = await _repo.type(widget.typeId);
      List<AmenityAsset> assets = const [];
      var total = 0;
      List<AmenityAssignment> assignments = const [];
      if (type.isBulk) {
        assignments = await _repo.typeAssignments(type.id);
      } else {
        final page = await _repo.assets(AssetQuery(typeId: type.id), limit: 200);
        assets = page.items;
        total = page.total;
      }
      if (!mounted) return;
      setState(() {
        _type = type;
        _assets = assets;
        _assetTotal = total;
        _assignments = assignments;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    } catch (_) {
      if (mounted) setState(() => (_error = "Couldn't load this amenity.", _loading = false));
    }
  }

  Future<List<AmenityLocation>> _locs() async => _locations ??= await _repo.locations().catchError((_) => <AmenityLocation>[]);

  Future<void> _add() async {
    final locations = await _locs();
    if (!mounted) return;
    if (await showAddSheet(context, repo: _repo, type: _type!, locations: locations)) await _load();
  }

  Future<void> _assignBulk() async {
    final locations = await _locs();
    if (!mounted) return;
    if (await showAssignSheet(context,
        repo: _repo, locations: locations, type: _type, studentsAllowed: _type!.assignableToStudents)) {
      await _load();
    }
  }

  Future<void> _move() async {
    if (await showMoveUnitsSheet(context, repo: _repo, type: _type!)) await _load();
  }

  Future<void> _return(AmenityAssignment a) async {
    if (await showReturnSheet(context, repo: _repo, assignment: a)) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = _type;
    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF032B4F),
        foregroundColor: Colors.white,
        title: Text(t?.name ?? 'Amenity', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: t == null || !t.isActive
          ? null
          : FloatingActionButton.extended(
              heroTag: 'amenity_type_add',
              backgroundColor: PhonebookTheme.blue,
              foregroundColor: Colors.white,
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: Text(t.isBulk ? 'Add stock' : 'Add items'),
            ),
      body: _loading && t == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : (_error != null && t == null)
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
                      _InventoryStrip(type: t!),
                      const SizedBox(height: 12),
                      if (t.isBulk) ...[
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (t.inventory['available'] > 0) ? _assignBulk : null,
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                              label: const Text('Assign'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _move,
                              icon: const Icon(Icons.sync_alt_rounded, size: 18),
                              label: const Text('Move units'),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        const PhonebookSectionHeader(title: 'Assignments'),
                        if (_assignments.isEmpty)
                          const Text('Nothing assigned yet.', style: TextStyle(color: PhonebookTheme.muted))
                        else
                          for (final a in _assignments)
                            AssignmentTile(
                              assignment: a,
                              trailing: a.isOpen
                                  ? IconButton(
                                      tooltip: 'Return',
                                      onPressed: () => _return(a),
                                      icon: const Icon(Icons.keyboard_return_rounded, color: PhonebookTheme.green),
                                    )
                                  : null,
                            ),
                      ] else ...[
                        PhonebookSectionHeader(title: 'Items ($_assetTotal)'),
                        if (_assets.isEmpty)
                          const Text('No items yet. Add them with the button below.', style: TextStyle(color: PhonebookTheme.muted))
                        else
                          for (final a in _assets) AssetTile(asset: a, onTap: () async {
                            await AssetDetailScreen.open(context, a.id);
                            if (mounted) await _load();
                          }),
                        if (_assetTotal > _assets.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Showing ${_assets.length} of $_assetTotal. Use Inventory search to find others.',
                                style: const TextStyle(color: PhonebookTheme.muted, fontSize: 12.5)),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _InventoryStrip extends StatelessWidget {
  final AmenityType type;

  const _InventoryStrip({required this.type});

  @override
  Widget build(BuildContext context) {
    final inv = type.inventory;
    final cells = <(String, int, Color)>[
      ('Total', inv['total'], PhonebookTheme.ink),
      ('Available', inv['available'], PhonebookTheme.green),
      ('Assigned', inv['assigned'], PhonebookTheme.blue),
      if (!type.isBulk || inv['installed'] > 0) ('Installed', inv['installed'], PhonebookTheme.blue),
      ('Under repair', inv['under_repair'], PhonebookTheme.amber),
      ('Damaged', inv['damaged'], PhonebookTheme.red),
      ('Lost', inv['lost'], PhonebookTheme.red),
      ('Retired', inv['retired'], PhonebookTheme.muted),
    ];
    return PhonebookCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${type.categoryName ?? ''} · ${type.isBulk ? 'Counted by quantity (${type.unit})' : 'Asset IDs HSH-${type.codePrefix}-…'}',
            style: const TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 10, children: [
          for (final (label, n, color) in cells)
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('$n', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted, fontWeight: FontWeight.w600)),
            ]),
        ]),
        const SizedBox(height: 8),
        Text('Value ${AmenityFormat.money(inv.value)}', style: const TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.slate)),
      ]),
    );
  }
}

/// One asset in a list.
class AssetTile extends StatelessWidget {
  final AmenityAsset asset;
  final VoidCallback onTap;

  const AssetTile({super.key, required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = asset;
    final cur = a.currentAssignment;
    final where = switch (a.placement) {
      AssetPlacement.installed => cur?.location?.path ?? 'Installed',
      AssetPlacement.withStudent => '${cur?.student?.name ?? 'Student'}${cur?.roomNumber == null ? '' : ' · Room ${cur!.roomNumber}'}',
      AssetPlacement.inStore => 'In store${a.homeLocation == null ? '' : ' · ${a.homeLocation!.path}'}',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PhonebookCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a.assetCode}${a.label == null ? '' : ' · ${a.label}'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
              const SizedBox(height: 2),
              Text('${a.typeName} · $where', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.slate)),
            ]),
          ),
          const SizedBox(width: 8),
          AmenityChip(AmenityFormat.status(a.status), color: AmenityFormat.statusColor(a.status)),
        ]),
      ),
    );
  }
}
