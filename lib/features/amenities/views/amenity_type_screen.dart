import 'package:flutter/material.dart';

import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../shared/widgets/empty_state.dart';
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

  Future<List<AmenityLocation>> _locs() async =>
      _locations ??= await _repo.locations().catchError((_) => <AmenityLocation>[]);

  Future<void> _add() async {
    final locations = await _locs();
    if (!mounted) return;
    if (await showAddSheet(context, repo: _repo, type: _type!, locations: locations)) await _load();
  }

  Future<void> _assignBulk() async {
    final locations = await _locs();
    if (!mounted) return;
    if (await showAssignSheet(
      context,
      repo: _repo,
      locations: locations,
      type: _type,
      studentsAllowed: _type!.assignableToStudents,
    )) {
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
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      floatingActionButton: t == null || !t.isActive
          ? null
          : FloatingActionButton.extended(
              heroTag: 'amenity_type_add',
              backgroundColor: PhonebookTheme.blue,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: Text(t.isBulk ? 'Add stock' : 'Add items', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: PhonebookHeaderDelegate(
              overline: t?.categoryName?.toUpperCase() ?? 'AMENITY TYPE',
              title: t?.name ?? 'Amenity Type',
              subtitle: t == null
                  ? ''
                  : (t.isBulk
                      ? 'Bulk Asset · Tracked by quantity (${t.unit})'
                      : 'Individual Asset · Tracked by unique ID/QR'),
              topPadding: topPadding,
              onLeadingTap: () => Navigator.of(context).maybePop(),
              pills: t == null
                  ? null
                  : Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        PhonebookHeaderPill(
                          icon: Icons.check_circle_outline_rounded,
                          label: '${t.inventory['available']} available',
                        ),
                        PhonebookHeaderPill(
                          icon: Icons.person_outline_rounded,
                          label: '${t.inventory['assigned']} assigned',
                        ),
                        PhonebookHeaderPill(
                          icon: Icons.currency_rupee_rounded,
                          label: AmenityFormat.money(t.inventory.value),
                        ),
                      ],
                    ),
            ),
          ),
          if (_loading && t == null)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: PhonebookTheme.blue, strokeWidth: 2.2)),
            )
          else if (_error != null && t == null)
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
                      Text(_error!, style: const TextStyle(color: PhonebookTheme.slate, fontWeight: FontWeight.w500)),
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
                      _InventoryStrip(type: t!),
                      const SizedBox(height: 16),
                      if (t.isBulk) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (t.inventory['available'] > 0) ? _assignBulk : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PhonebookTheme.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                                label: const Text('Assign Units', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _move,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: PhonebookTheme.blue,
                                  side: const BorderSide(color: PhonebookTheme.blue),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.sync_alt_rounded, size: 18),
                                label: const Text('Move Units', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const PhonebookSectionHeader(title: 'Active Assignments'),
                        if (_assignments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: EmptyState(
                              icon: Icons.person_outline_rounded,
                              title: 'No assignments yet',
                              message: 'Use "Assign Units" above to assign stock to a student or room.',
                            ),
                          )
                        else
                          for (final a in _assignments)
                            AssignmentTile(
                              assignment: a,
                              trailing: a.isOpen
                                  ? IconButton(
                                      tooltip: 'Return units',
                                      onPressed: () => _return(a),
                                      icon: const Icon(Icons.keyboard_return_rounded, color: PhonebookTheme.green),
                                    )
                                  : null,
                            ),
                      ] else ...[
                        PhonebookSectionHeader(title: 'Registered Items ($_assetTotal)'),
                        if (_assets.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'No items created yet',
                              message: 'Use the "Add items" button below to add assets with QR codes.',
                            ),
                          )
                        else
                          for (final a in _assets)
                            AssetTile(
                              asset: a,
                              onTap: () async {
                                await AssetDetailScreen.open(context, a.id);
                                if (mounted) await _load();
                              },
                            ),
                        if (_assetTotal > _assets.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: Text(
                                'Showing ${_assets.length} of $_assetTotal items. Search in Inventory to filter.',
                                style: const TextStyle(color: PhonebookTheme.muted, fontSize: 12.5),
                              ),
                            ),
                          ),
                      ],
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

class _InventoryStrip extends StatelessWidget {
  final AmenityType type;

  const _InventoryStrip({required this.type});

  @override
  Widget build(BuildContext context) {
    final inv = type.inventory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 3 Metric Cards matching Phonebook style
        Row(
          children: [
            Expanded(
              child: PhonebookCountCard(
                value: '${inv['total']}',
                label: 'Total stock',
                icon: Icons.inventory_2_outlined,
                color: PhonebookTheme.ink,
                bgColor: PhonebookTheme.blueSoft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PhonebookCountCard(
                value: '${inv['available']}',
                label: 'Available',
                icon: Icons.check_circle_outline_rounded,
                color: PhonebookTheme.green,
                bgColor: PhonebookTheme.greenSoft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PhonebookCountCard(
                value: '${inv['assigned']}',
                label: 'Assigned',
                icon: Icons.person_outline_rounded,
                color: PhonebookTheme.blue,
                bgColor: PhonebookTheme.blueSoft,
              ),
            ),
          ],
        ),
        if (inv['under_repair'] > 0 || inv['damaged'] > 0 || inv['lost'] > 0) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (inv['under_repair'] > 0)
                Expanded(
                  child: PhonebookCountCard(
                    value: '${inv['under_repair']}',
                    label: 'In repair',
                    icon: Icons.handyman_outlined,
                    color: PhonebookTheme.amber,
                    bgColor: PhonebookTheme.amberSoft,
                  ),
                ),
              if (inv['damaged'] > 0) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: PhonebookCountCard(
                    value: '${inv['damaged']}',
                    label: 'Damaged',
                    icon: Icons.broken_image_outlined,
                    color: PhonebookTheme.red,
                    bgColor: PhonebookTheme.redSoft,
                  ),
                ),
              ],
              if (inv['lost'] > 0) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: PhonebookCountCard(
                    value: '${inv['lost']}',
                    label: 'Lost',
                    icon: Icons.help_outline_rounded,
                    color: PhonebookTheme.red,
                    bgColor: PhonebookTheme.redSoft,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
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
      AssetPlacement.withStudent =>
        '${cur?.student?.name ?? 'Student'}${cur?.roomNumber == null ? '' : ' · Room ${cur!.roomNumber}'}',
      AssetPlacement.inStore => 'In store${a.homeLocation == null ? '' : ' · ${a.homeLocation!.path}'}',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PhonebookCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AmenityFormat.statusColor(a.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                a.typeName.toLowerCase().contains('key') ? Icons.vpn_key_rounded : Icons.inventory_2_outlined,
                color: AmenityFormat.statusColor(a.status),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        a.assetCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: PhonebookTheme.ink,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (a.label != null && a.label!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· ${a.label}',
                          style: const TextStyle(fontSize: 13, color: PhonebookTheme.slate, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 14, color: PhonebookTheme.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${a.typeName} · $where',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.slate, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AmenityChip(AmenityFormat.status(a.status), color: AmenityFormat.statusColor(a.status)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
