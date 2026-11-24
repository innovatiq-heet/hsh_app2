import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../controllers/amenities_home_controller.dart';
import '../utils/amenity_format.dart';
import '../widgets/amenity_sheets.dart';
import 'amenity_setup_screen.dart';
import 'amenity_type_screen.dart';
import 'asset_detail_screen.dart';
import 'asset_scanner_screen.dart';
import 'location_screen.dart';

/// Operator console → Amenities: Dashboard, Inventory and Locations, with
/// scan, setup (categories & types) and the activity log.
class AmenitiesHomeScreen extends GetView<AmenitiesHomeController> {
  const AmenitiesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DefaultTabController(
        length: 3,
        child: Builder(builder: (context) {
          final tabs = DefaultTabController.of(context);
          tabs.addListener(() {
            if (!tabs.indexIsChanging && controller.tab.value != tabs.index) controller.openTab(tabs.index);
          });
          // A drill-down from the dashboard switches tab from the controller.
          return Obx(() {
            if (tabs.index != controller.tab.value) tabs.animateTo(controller.tab.value);
            return Scaffold(
              backgroundColor: PhonebookTheme.bg,
              appBar: AppBar(
                backgroundColor: const Color(0xFF032B4F),
                foregroundColor: Colors.white,
                title: const Text('Amenities', style: TextStyle(fontWeight: FontWeight.w800)),
                actions: [
                  IconButton(
                    tooltip: 'Scan a QR code',
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssetScannerScreen(repository: controller.repo)));
                      controller.refreshAll();
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'setup') {
                        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AmenitySetupScreen(repository: controller.repo)));
                        controller.refreshAll();
                      } else {
                        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ActivityScreen(repo: controller.repo)));
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'setup', child: Text('Categories & types')),
                      PopupMenuItem(value: 'activity', child: Text('Activity log')),
                    ],
                  ),
                ],
                bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: PhonebookTheme.amberBright,
                  tabs: [Tab(text: 'Dashboard'), Tab(text: 'Inventory'), Tab(text: 'Locations')],
                ),
              ),
              floatingActionButton: switch (controller.tab.value) {
                1 => FloatingActionButton.extended(
                    heroTag: 'amenities_add',
                    backgroundColor: PhonebookTheme.blue,
                    foregroundColor: Colors.white,
                    onPressed: () => _addItems(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
                2 => FloatingActionButton.extended(
                    heroTag: 'amenities_add_location',
                    backgroundColor: PhonebookTheme.blue,
                    foregroundColor: Colors.white,
                    onPressed: () async {
                      if (await showLocationForm(context, repo: controller.repo)) controller.loadLocations();
                    },
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('Building / area'),
                  ),
                _ => null,
              },
              body: const TabBarView(
                physics: NeverScrollableScrollPhysics(),
                children: [_DashboardTab(), _InventoryTab(), _LocationsTab()],
              ),
            );
          });
        }),
      ),
    );
  }

  Future<void> _addItems(BuildContext context) async {
    final types = controller.types.where((t) => t.isActive).toList();
    if (types.isEmpty) {
      AppSnackbar.info('No Amenity Types', 'Create a category and a type first (⋮ → Categories & types).');
      return;
    }
    final type = await showModalBottomSheet<AmenityType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
            const Text('What are you adding?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            for (final t in types)
              ListTile(
                title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${t.categoryName ?? ''} · ${t.isBulk ? 'by quantity' : 'each with an ID'}'),
                onTap: () => Navigator.of(c).pop(t),
              ),
          ]),
        ),
      ),
    );
    if (type == null || !context.mounted) return;
    if (controller.locations.isEmpty) await controller.loadLocations();
    if (!context.mounted) return;
    if (await showAddSheet(context, repo: controller.repo, type: type, locations: controller.locations)) {
      controller.refreshAll();
    }
  }
}

// ---------------------------------------------------------------- dashboard

class _DashboardTab extends GetView<AmenitiesHomeController> {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          builder: (_) => Obx(() {
            final d = controller.dashboard.value ?? const AmenitiesDashboard();
            final cards = <(String, String, IconData, Color, AssetQuery?)>[
              ('Total items', '${d['assets'] + d['bulk_units']}', Icons.inventory_2_rounded, PhonebookTheme.ink, AssetQuery.empty),
              ('Asset value', AmenityFormat.money(d.value), Icons.currency_rupee_rounded, PhonebookTheme.green, null),
              ('Available', '${d['available']}', Icons.check_circle_outline, PhonebookTheme.green,
                  const AssetQuery(status: AssetStatus.active, placement: AssetPlacement.inStore)),
              ('Assigned', '${d['assigned']}', Icons.person_outline, PhonebookTheme.blue, const AssetQuery(placement: AssetPlacement.withStudent)),
              ('Installed', '${d['installed']}', Icons.build_circle_outlined, PhonebookTheme.blue, const AssetQuery(placement: AssetPlacement.installed)),
              ('Under repair', '${d['under_repair']}', Icons.handyman_outlined, PhonebookTheme.amber, const AssetQuery(status: AssetStatus.underRepair)),
              ('Issue reported', '${d['issue_reported']}', Icons.report_problem_outlined, PhonebookTheme.amber,
                  const AssetQuery(status: AssetStatus.issueReported)),
              ('Damaged', '${d['damaged']}', Icons.broken_image_outlined, PhonebookTheme.red, const AssetQuery(status: AssetStatus.damaged)),
              ('Lost', '${d['lost']}', Icons.help_outline_rounded, PhonebookTheme.red, const AssetQuery(status: AssetStatus.lost)),
              ('Retired', '${d['retired']}', Icons.archive_outlined, PhonebookTheme.muted, const AssetQuery(status: AssetStatus.retired)),
              ('Warranty ending', '${d['warranty_expiring']}', Icons.verified_outlined, PhonebookTheme.amber, const AssetQuery(warranty: 'expiring')),
              ('Maintenance due', '${d['maintenance_due']}', Icons.event_repeat_rounded, PhonebookTheme.amber, const AssetQuery(maintenance: 'due')),
            ];
            return RefreshIndicator(
              onRefresh: () => controller.load(showLoading: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.1,
                    children: [
                      for (final (label, value, icon, color, filter) in cards)
                        _StatCard(label: label, value: value, icon: icon, color: color,
                            onTap: filter == null ? null : () => controller.drillDown(filter)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const PhonebookSectionHeader(title: 'By category'),
                  if (d.categories.isEmpty)
                    const Text('No categories yet. Add them from ⋮ → Categories & types.', style: TextStyle(color: PhonebookTheme.muted))
                  else
                    for (final c in d.categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PhonebookCard(
                          onTap: () => controller.drillDown(AssetQuery(categoryId: c.id)),
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AmenityFormat.color(c.color).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(AmenityFormat.icon(c.icon), color: AmenityFormat.color(c.color), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
                            ),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('${c.assetCount + c.bulkUnits} items', style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(AmenityFormat.money(d.categoryValues[c.id]), style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted)),
                            ]),
                            const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted),
                          ]),
                        ),
                      ),
                ],
              ),
            );
          }),
        ));
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => PhonebookCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              ),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}

// ---------------------------------------------------------------- inventory

class _InventoryTab extends GetView<AmenitiesHomeController> {
  const _InventoryTab();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller.searchController,
              decoration: phonebookInputDecoration(
                hint: 'Search code, serial, type, student, room',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Filters',
            onPressed: () => _openFilters(context),
            icon: const Icon(Icons.tune_rounded),
          ),
        ]),
      ),
      Obx(() {
        final chips = controller.filterChips;
        if (chips.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final c in chips)
              Padding(
                padding: const EdgeInsets.only(right: 6, top: 6),
                child: InputChip(label: Text(c.label), onDeleted: () => controller.setFilters(c.without)),
              ),
            TextButton(onPressed: controller.clearFilters, child: const Text('Clear all')),
          ]),
        );
      }),
      Expanded(
        child: Obx(() {
          if (controller.isInventoryLoading.value && controller.assets.isEmpty) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final error = controller.inventoryError.value;
          if (error != null && controller.assets.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(error, style: const TextStyle(color: PhonebookTheme.slate)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: controller.loadInventory, child: const Text('Retry')),
              ]),
            );
          }
          final bulk = controller.bulkTypes;
          final assets = controller.assets;
          if (bulk.isEmpty && assets.isEmpty) {
            return const Center(child: Text('Nothing matches.', style: TextStyle(color: PhonebookTheme.muted)));
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) controller.loadMore();
              return false;
            },
            child: RefreshIndicator(
              onRefresh: controller.loadInventory,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  for (final t in bulk)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PhonebookCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () async {
                          await AmenityTypeScreen.open(context, t.id);
                          controller.refreshAll();
                        },
                        child: Row(children: [
                          const Icon(Icons.stacked_bar_chart_rounded, color: PhonebookTheme.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(
                                '${t.inventory['assigned']} assigned · ${t.inventory['available']} available'
                                '${t.inventory['under_repair'] > 0 ? ' · ${t.inventory['under_repair']} under repair' : ''}',
                                style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.slate),
                              ),
                            ]),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted),
                        ]),
                      ),
                    ),
                  if (assets.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, top: 4),
                      child: Text('${controller.total.value} items', style: const TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w600)),
                    ),
                  for (final a in assets)
                    AssetTile(asset: a, onTap: () async {
                      await AssetDetailScreen.open(context, a.id);
                      controller.loadInventory();
                    }),
                  if (controller.isLoadingMore.value)
                    const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                ],
              ),
            ),
          );
        }),
      ),
    ]);
  }

  Future<void> _openFilters(BuildContext context) async {
    if (controller.locations.isEmpty) controller.loadLocations();
    final picked = await showModalBottomSheet<AssetQuery>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FilterSheet(controller: controller, initial: controller.query.value),
    );
    if (picked != null) controller.setFilters(picked);
  }
}

class _FilterSheet extends StatefulWidget {
  final AmenitiesHomeController controller;
  final AssetQuery initial;

  const _FilterSheet({required this.controller, required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late AssetQuery _q = widget.initial;
  late final _room = TextEditingController(text: widget.initial.room ?? '');

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  Widget _group(String title, List<Widget> chips) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: PhonebookTheme.slate)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final types = c.types.where((t) => _q.categoryId == null || t.categoryId == _q.categoryId).toList();
    final location = c.locations.expand((l) => l.flatten()).where((l) => l.id == _q.locationId).firstOrNull;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('Filters', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            TextButton(onPressed: () => setState(() => _q = AssetQuery.empty), child: const Text('Reset')),
          ]),
          const SizedBox(height: 10),
          _group('Category', [
            for (final cat in c.categories)
              PhonebookTintChip(
                label: cat.name,
                selected: _q.categoryId == cat.id,
                onTap: () => setState(() => _q = _q.categoryId == cat.id ? _q.copyWith(clearCategory: true, clearType: true) : _q.copyWith(categoryId: cat.id, clearType: true)),
              ),
          ]),
          if (types.isNotEmpty)
            _group('Type', [
              for (final t in types)
                PhonebookTintChip(
                  label: t.name,
                  selected: _q.typeId == t.id,
                  onTap: () => setState(() => _q = _q.typeId == t.id ? _q.copyWith(clearType: true) : _q.copyWith(typeId: t.id)),
                ),
            ]),
          _group('Status', [
            for (final s in AssetStatus.values)
              PhonebookTintChip(
                label: AmenityFormat.status(s),
                color: AmenityFormat.statusColor(s),
                selected: _q.status == s,
                onTap: () => setState(() => _q = _q.status == s ? _q.copyWith(clearStatus: true) : _q.copyWith(status: s)),
              ),
          ]),
          _group('Condition', [
            for (final s in AssetCondition.values)
              PhonebookTintChip(
                label: AmenityFormat.condition(s),
                selected: _q.condition == s,
                onTap: () => setState(() => _q = _q.condition == s ? _q.copyWith(clearCondition: true) : _q.copyWith(condition: s)),
              ),
          ]),
          _group('Where', [
            for (final p in AssetPlacement.values)
              PhonebookTintChip(
                label: AmenityFormat.placement(p),
                selected: _q.placement == p,
                onTap: () => setState(() => _q = _q.placement == p ? _q.copyWith(clearPlacement: true) : _q.copyWith(placement: p)),
              ),
          ]),
          _group('Warranty', [
            for (final w in const ['active', 'expiring', 'expired', 'none'])
              PhonebookTintChip(
                label: AmenityFormat.warranty(w),
                selected: _q.warranty == w,
                onTap: () => setState(() => _q = _q.warranty == w ? _q.copyWith(clearWarranty: true) : _q.copyWith(warranty: w)),
              ),
          ]),
          _group('Maintenance', [
            for (final m in const [('due', 'Due'), ('open', 'Repair open')])
              PhonebookTintChip(
                label: m.$2,
                selected: _q.maintenance == m.$1,
                onTap: () => setState(() => _q = _q.maintenance == m.$1 ? _q.copyWith(clearMaintenance: true) : _q.copyWith(maintenance: m.$1)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final l = await pickLocation(context, c.locations);
                if (l != null) setState(() => _q = _q.copyWith(locationId: l.id));
              },
              child: InputDecorator(
                decoration: phonebookInputDecoration(
                  label: 'Location (includes everything inside)',
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: _q.locationId == null
                      ? null
                      : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _q = _q.copyWith(clearLocation: true))),
                ),
                child: Text(location?.path ?? 'Any'),
              ),
            ),
          ),
          TextField(controller: _room, decoration: phonebookInputDecoration(label: 'Room number', hint: 'e.g. 204')),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final room = _room.text.trim();
                Navigator.of(context).pop(room.isEmpty ? _q.copyWith(clearRoom: true) : _q.copyWith(room: room));
              },
              style: ElevatedButton.styleFrom(backgroundColor: PhonebookTheme.blue, foregroundColor: Colors.white, elevation: 0),
              child: const Text('Show results', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- locations

class _LocationsTab extends GetView<AmenitiesHomeController> {
  const _LocationsTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLocationsLoading.value && controller.locations.isEmpty) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      final error = controller.locationsError.value;
      if (error != null && controller.locations.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error, style: const TextStyle(color: PhonebookTheme.slate)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: controller.loadLocations, child: const Text('Retry')),
          ]),
        );
      }
      if (controller.locations.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No locations yet. Add a building or area with the button below.',
                textAlign: TextAlign.center, style: TextStyle(color: PhonebookTheme.muted)),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: controller.loadLocations,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
          children: [for (final l in controller.locations) _LocationNode(location: l, depth: 0)],
        ),
      );
    });
  }
}

class _LocationNode extends GetView<AmenitiesHomeController> {
  final AmenityLocation location;
  final int depth;

  const _LocationNode({required this.location, required this.depth});

  @override
  Widget build(BuildContext context) {
    final l = location;
    final title = Row(children: [
      Icon(locationKindIcon(l.kind), size: 20, color: l.isActive ? PhonebookTheme.slate : PhonebookTheme.muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          l.kind == LocationKind.room ? 'Room ${l.roomNumber ?? l.name}' : l.name,
          style: TextStyle(fontWeight: FontWeight.w700, color: l.isActive ? PhonebookTheme.ink : PhonebookTheme.muted),
        ),
      ),
      if (l.assetCount > 0) Text('${l.assetCount}', style: const TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w700)),
    ]);
    final menu = PopupMenuButton<String>(
      onSelected: (v) async {
        if (v == 'open') {
          await LocationScreen.open(context, l.id);
        } else if (v == 'add') {
          if (await showLocationForm(context, repo: controller.repo, parent: l)) controller.loadLocations();
        } else {
          if (await showLocationForm(context, repo: controller.repo, existing: l)) controller.loadLocations();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'open', child: Text('Open')),
        PopupMenuItem(value: 'add', child: Text('Add inside')),
        PopupMenuItem(value: 'edit', child: Text('Edit')),
      ],
    );
    if (l.children.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 14.0),
        child: ListTile(
          dense: true,
          title: title,
          trailing: menu,
          onTap: () => LocationScreen.open(context, l.id),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(left: depth * 14.0),
      child: ExpansionTile(
        dense: true,
        title: title,
        trailing: menu,
        shape: const Border(),
        children: [for (final c in l.children) _LocationNode(location: c, depth: depth + 1)],
      ),
    );
  }
}

// ----------------------------------------------------------------- activity

class _ActivityScreen extends StatelessWidget {
  final AmenitiesRepository repo;

  const _ActivityScreen({required this.repo});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PhonebookTheme.bg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF032B4F),
          foregroundColor: Colors.white,
          title: const Text('Activity log', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: AmenityEventsList(load: (offset) => repo.activity(offset: offset), activity: true),
      );
}
