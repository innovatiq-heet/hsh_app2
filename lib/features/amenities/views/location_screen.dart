import 'package:flutter/material.dart';

import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/empty_state.dart';
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
      showDragHandle: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2.5)),
              ),
            ),
            Text(
              'Give to ${student.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: PhonebookTheme.ink),
            ),
            const SizedBox(height: 10),
            for (final a in spare)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PhonebookCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => Navigator.of(c).pop(a),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: PhonebookTheme.blueSoft, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.vpn_key_rounded, color: PhonebookTheme.blue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${a.typeName}${a.label == null ? '' : ' · ${a.label}'}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: PhonebookTheme.ink),
                            ),
                            Text(
                              '${a.assetCode}${a.serialNumber == null ? '' : ' · No. ${a.serialNumber}'}',
                              style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted),
                    ],
                  ),
                ),
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
      showDragHandle: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2.5)),
                ),
              ),
              const Text('Add to this location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
              const SizedBox(height: 10),
              for (final t in individual)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PhonebookCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => Navigator.of(c).pop(t),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: PhonebookTheme.blueSoft, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.inventory_2_outlined, color: PhonebookTheme.blue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: PhonebookTheme.ink)),
                              Text(t.categoryName ?? '', style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted),
                      ],
                    ),
                  ),
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
    final topPadding = MediaQuery.of(context).padding.top;

    final locationTitle = loc == null
        ? (widget.roomNumber == null ? 'Location' : 'Room ${widget.roomNumber}')
        : (loc.kind == LocationKind.room ? 'Room ${loc.roomNumber ?? loc.name}' : loc.name);

    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      floatingActionButton: d == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'location_add',
              backgroundColor: PhonebookTheme.blue,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: _addHere,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add here', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: PhonebookHeaderDelegate(
              overline: loc?.kind == LocationKind.room ? 'HOSTEL ROOM' : 'CAMPUS LOCATION',
              title: locationTitle,
              subtitle: loc?.path ?? 'Hostel Location & Residents',
              topPadding: topPadding,
              onLeadingTap: () => Navigator.of(context).maybePop(),
              pills: d == null
                  ? null
                  : Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (loc?.kind == LocationKind.room)
                          PhonebookHeaderPill(
                            icon: Icons.groups_rounded,
                            label: '${d.residents.length} residents',
                          ),
                        PhonebookHeaderPill(
                          icon: Icons.build_circle_outlined,
                          label: '${d.installed.length} installed',
                        ),
                        PhonebookHeaderPill(
                          icon: Icons.inventory_2_outlined,
                          label: '${d.homeAssets.length} in store',
                        ),
                      ],
                    ),
            ),
          ),
          if (_loading && d == null)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: PhonebookTheme.blue, strokeWidth: 2.2)),
            )
          else if (_error != null && d == null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
                        child: const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: PhonebookTheme.slate, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: RefreshIndicator(
                onRefresh: _load,
                color: PhonebookTheme.blue,
                backgroundColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (d!.residents.isNotEmpty) ...[
                        const PhonebookSectionHeader(title: 'Room Residents & Their Items'),
                        for (final r in d.residents)
                          _ResidentCard(
                            student: r.student,
                            items: r.items,
                            onGive: () => _give(r.student),
                            onReturn: _return,
                            onOpen: _openItem,
                          ),
                        const SizedBox(height: 14),
                      ],
                      const PhonebookSectionHeader(title: 'Installed in This Location'),
                      if (d.installed.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: EmptyState(
                            icon: Icons.build_circle_outlined,
                            title: 'Nothing installed here',
                            message: 'Assets like fans, lights or AC units installed in this location will appear here.',
                          ),
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
                      const SizedBox(height: 14),
                      const PhonebookSectionHeader(title: 'Kept Here (In Store / Spares)'),
                      if (d.homeAssets.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No spare items kept here',
                            message: 'Items assigned as their home location (such as spare room keys) appear here.',
                          ),
                        )
                      else
                        for (final a in d.homeAssets)
                          AssetTile(
                            asset: a,
                            onTap: () async {
                              await AssetDetailScreen.open(context, a.id);
                              if (mounted) await _load();
                            },
                          ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
      padding: const EdgeInsets.only(bottom: 12),
      child: PhonebookCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: PhonebookTheme.blueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded, color: PhonebookTheme.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: PhonebookTheme.ink),
                      ),
                      Text(
                        '${items.length} ${items.length == 1 ? 'item' : 'items'} in possession',
                        style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onGive,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PhonebookTheme.blueSoft,
                    foregroundColor: PhonebookTheme.blue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Give item', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const Divider(height: 20, color: PhonebookTheme.border),
              for (final a in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () => onOpen(a),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: PhonebookTheme.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PhonebookTheme.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            a.title.toLowerCase().contains('key') ? Icons.vpn_key_rounded : Icons.inventory_2_outlined,
                            size: 16,
                            color: PhonebookTheme.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              a.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: PhonebookTheme.ink),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Return item',
                            onPressed: () => onReturn(a),
                            icon: const Icon(Icons.keyboard_return_rounded, size: 18, color: PhonebookTheme.green),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
