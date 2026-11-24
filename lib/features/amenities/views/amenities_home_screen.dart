import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../controllers/amenities_home_controller.dart';
import '../utils/amenity_format.dart';
import '../widgets/amenity_sheets.dart';
import 'amenity_setup_screen.dart';
import 'amenity_type_screen.dart';
import 'asset_detail_screen.dart';
import 'asset_scanner_screen.dart';
import 'location_screen.dart';

/// Luminous circular background orb painter matching Phonebook & Screen Time headers.
class _AmenitiesOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.38, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.62, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.86, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
            if (!tabs.indexIsChanging && controller.tab.value != tabs.index) {
              controller.openTab(tabs.index);
            }
          });
          // A drill-down from the dashboard switches tab from the controller.
          return Obx(() {
            if (tabs.index != controller.tab.value) {
              tabs.animateTo(controller.tab.value);
            }
            return Scaffold(
              backgroundColor: PhonebookTheme.bg,
              body: Column(
                children: [
                  // Signature Executive Deep-Navy Header with Tabs
                  _buildExecutiveHeader(context),

                  // Tab Views
                  const Expanded(
                    child: TabBarView(
                      physics: NeverScrollableScrollPhysics(),
                      children: [_DashboardTab(), _InventoryTab(), _LocationsTab()],
                    ),
                  ),
                ],
              ),
              floatingActionButton: switch (controller.tab.value) {
                1 => FloatingActionButton.extended(
                    heroTag: 'amenities_add',
                    backgroundColor: PhonebookTheme.blue,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onPressed: () => _addItems(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add items', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                2 => FloatingActionButton.extended(
                    heroTag: 'amenities_add_location',
                    backgroundColor: PhonebookTheme.blue,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onPressed: () async {
                      if (await showLocationForm(context, repo: controller.repo)) {
                        controller.loadLocations();
                      }
                    },
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('Add location', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                _ => null,
              },
            );
          });
        }),
      ),
    );
  }

  Widget _buildExecutiveHeader(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: PhonebookTheme.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x3803192E),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _AmenitiesOrbPainter())),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                    child: Row(
                      children: [
                        if (canPop) ...[
                          PhonebookHeaderCircleButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'OPERATOR CONSOLE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: PhonebookTheme.amberBright,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Amenities',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Keys, furniture, appliances & hostel asset register',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        PhonebookHeaderCircleButton(
                          icon: Icons.qr_code_scanner_rounded,
                          tooltip: 'Scan a QR code',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AssetScannerScreen(repository: controller.repo),
                              ),
                            );
                            controller.refreshAll();
                          },
                        ),
                        const SizedBox(width: 8),
                        PhonebookHeaderCircleButton(
                          icon: Icons.more_vert_rounded,
                          tooltip: 'Options',
                          onTap: () {},
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onSelected: (v) async {
                              if (v == 'setup') {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => AmenitySetupScreen(repository: controller.repo),
                                  ),
                                );
                                controller.refreshAll();
                              } else {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => _ActivityScreen(repo: controller.repo),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'setup',
                                child: Row(
                                  children: [
                                    Icon(Icons.tune_rounded, size: 18, color: PhonebookTheme.ink),
                                    SizedBox(width: 10),
                                    Text('Categories & types', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'activity',
                                child: Row(
                                  children: [
                                    Icon(Icons.history_rounded, size: 18, color: PhonebookTheme.ink),
                                    SizedBox(width: 10),
                                    Text('Activity log', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Status Metric Pills Row
                  Obx(() {
                    final d = controller.dashboard.value;
                    final totalItems = d == null ? 0 : (d['assets'] + d['bulk_units']);
                    final available = d == null ? 0 : d['available'];
                    final assigned = d == null ? 0 : d['assigned'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            PhonebookHeaderPill(
                              icon: Icons.inventory_2_rounded,
                              label: '$totalItems items registered',
                            ),
                            const SizedBox(width: 8),
                            PhonebookHeaderPill(
                              icon: Icons.check_circle_outline_rounded,
                              label: '$available available',
                            ),
                            const SizedBox(width: 8),
                            PhonebookHeaderPill(
                              icon: Icons.person_outline_rounded,
                              label: '$assigned assigned',
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),

                  // Modern Segmented TabBar
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: PhonebookTheme.ink,
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.82),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      tabs: const [
                        Tab(text: 'Dashboard', height: 36),
                        Tab(text: 'Inventory', height: 36),
                        Tab(text: 'Locations', height: 36),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      showDragHandle: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2.5)),
              ),
            ),
            const Text('What are you adding?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
            const SizedBox(height: 8),
            for (final t in types)
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: PhonebookTheme.blueSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(t.isBulk ? Icons.layers_rounded : Icons.vpn_key_rounded, color: PhonebookTheme.blue, size: 20),
                ),
                title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
                subtitle: Text('${t.categoryName ?? ''} · ${t.isBulk ? 'Counted by quantity' : 'Individually tagged ID'}',
                    style: const TextStyle(color: PhonebookTheme.muted, fontSize: 12.5)),
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
            final totalCount = d['assets'] + d['bulk_units'];
            final availableCount = d['available'];

            final statusBreakdown = <(String, String, IconData, Color, Color, AssetQuery?)>[
              ('Assigned', '${d['assigned']}', Icons.person_outline_rounded, PhonebookTheme.blue, PhonebookTheme.blueSoft,
                  const AssetQuery(placement: AssetPlacement.withStudent)),
              ('Installed', '${d['installed']}', Icons.build_circle_outlined, PhonebookTheme.purple, PhonebookTheme.purpleSoft,
                  const AssetQuery(placement: AssetPlacement.installed)),
              ('Under repair', '${d['under_repair']}', Icons.handyman_outlined, PhonebookTheme.amber, PhonebookTheme.amberSoft,
                  const AssetQuery(status: AssetStatus.underRepair)),
              ('Issue reported', '${d['issue_reported']}', Icons.report_problem_outlined, PhonebookTheme.amber, PhonebookTheme.amberSoft,
                  const AssetQuery(status: AssetStatus.issueReported)),
              ('Damaged', '${d['damaged']}', Icons.broken_image_outlined, PhonebookTheme.red, PhonebookTheme.redSoft,
                  const AssetQuery(status: AssetStatus.damaged)),
              ('Lost', '${d['lost']}', Icons.help_outline_rounded, PhonebookTheme.red, PhonebookTheme.redSoft,
                  const AssetQuery(status: AssetStatus.lost)),
              ('Warranty ending', '${d['warranty_expiring']}', Icons.verified_outlined, PhonebookTheme.amber, PhonebookTheme.amberSoft,
                  const AssetQuery(warranty: 'expiring')),
              ('Maintenance due', '${d['maintenance_due']}', Icons.event_repeat_rounded, PhonebookTheme.amber, PhonebookTheme.amberSoft,
                  const AssetQuery(maintenance: 'due')),
              ('Retired', '${d['retired']}', Icons.archive_outlined, PhonebookTheme.muted, PhonebookTheme.border,
                  const AssetQuery(status: AssetStatus.retired)),
            ];

            return RefreshIndicator(
              onRefresh: () => controller.load(showLoading: false),
              color: PhonebookTheme.blue,
              backgroundColor: Colors.white,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // ── Top 3 Executive Count Cards ──
                  Row(
                    children: [
                      Expanded(
                        child: PhonebookCountCard(
                          value: '$totalCount',
                          label: 'Total items',
                          icon: Icons.inventory_2_outlined,
                          color: PhonebookTheme.blue,
                          bgColor: PhonebookTheme.blueSoft,
                          onTap: () => controller.drillDown(AssetQuery.empty),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PhonebookCountCard(
                          value: AmenityFormat.money(d.value),
                          label: 'Asset value',
                          icon: Icons.currency_rupee_rounded,
                          color: PhonebookTheme.green,
                          bgColor: PhonebookTheme.greenSoft,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PhonebookCountCard(
                          value: '$availableCount',
                          label: 'Available',
                          icon: Icons.check_circle_outline_rounded,
                          color: PhonebookTheme.green,
                          bgColor: PhonebookTheme.greenSoft,
                          onTap: () => controller.drillDown(
                            const AssetQuery(status: AssetStatus.active, placement: AssetPlacement.inStore),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Status Breakdown Grid ──
                  const PhonebookSectionHeader(title: 'Status & Operational State'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.3,
                    children: [
                      for (final (label, value, icon, color, bgColor, filter) in statusBreakdown)
                        PhonebookCard(
                          onTap: filter == null ? null : () => controller.drillDown(filter),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        value,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: PhonebookTheme.ink,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: PhonebookTheme.slate,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Categories Breakdown ──
                  const PhonebookSectionHeader(title: 'Asset Categories'),
                  if (d.categories.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PhonebookTheme.border),
                      ),
                      child: const Center(
                        child: Text(
                          'No categories yet. Add them from ⋮ → Categories & types.',
                          style: TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w500),
                        ),
                      ),
                    )
                  else
                    for (final c in d.categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PhonebookCard(
                          onTap: () => controller.drillDown(AssetQuery(categoryId: c.id)),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AmenityFormat.color(c.color).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(AmenityFormat.icon(c.icon), color: AmenityFormat.color(c.color), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15.5,
                                        color: PhonebookTheme.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.assetCount + c.bulkUnits} items registered',
                                      style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.muted, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AmenityFormat.money(d.categoryValues[c.id]),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: PhonebookTheme.ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${c.assetCount} indiv · ${c.bulkUnits} bulk',
                                    style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.slate),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted, size: 22),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            );
          }),
        ));
  }
}

// ---------------------------------------------------------------- inventory

class _InventoryTab extends GetView<AmenitiesHomeController> {
  const _InventoryTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Obx(
            () => PhonebookSearchFilterBar(
              controller: controller.searchController,
              hintText: 'Search code, serial, type, student, room...',
              hasQuery: controller.searchController.text.isNotEmpty,
              onChanged: (_) {},
              onClear: () {
                controller.searchController.clear();
              },
              onFilterTap: () => _openFilters(context),
              activeFilterCount: controller.filterChips.length,
            ),
          ),
        ),

        // Active Filter Chips
        Obx(() {
          final chips = controller.filterChips;
          if (chips.isEmpty) return const SizedBox.shrink();
          return SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final c in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 4),
                    child: InputChip(
                      label: Text(c.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      backgroundColor: PhonebookTheme.blueSoft,
                      labelStyle: const TextStyle(color: PhonebookTheme.blue),
                      deleteIconColor: PhonebookTheme.blue,
                      side: BorderSide(color: PhonebookTheme.blue.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onDeleted: () => controller.setFilters(c.without),
                    ),
                  ),
                TextButton(
                  onPressed: controller.clearFilters,
                  child: const Text('Clear all', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: PhonebookTheme.blue)),
                ),
              ],
            ),
          );
        }),

        // Items List
        Expanded(
          child: Obx(() {
            if (controller.isInventoryLoading.value && controller.assets.isEmpty && controller.bulkTypes.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: PhonebookTheme.blue, strokeWidth: 2.2));
            }
            final error = controller.inventoryError.value;
            if (error != null && controller.assets.isEmpty && controller.bulkTypes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
                      child: const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: 12),
                    Text(error, style: const TextStyle(color: PhonebookTheme.slate, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: controller.loadInventory, child: const Text('Retry')),
                  ],
                ),
              );
            }
            final bulk = controller.bulkTypes;
            final assets = controller.assets;
            if (bulk.isEmpty && assets.isEmpty) {
              return const Center(
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No assets found',
                  message: 'Try adjusting your search keywords or active filters.',
                ),
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                  controller.loadMore();
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: controller.loadInventory,
                color: PhonebookTheme.blue,
                backgroundColor: Colors.white,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                  children: [
                    if (bulk.isNotEmpty) ...[
                      const PhonebookSectionHeader(title: 'Bulk Tracked Amenities'),
                      for (final t in bulk)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PhonebookCard(
                            padding: const EdgeInsets.all(14),
                            onTap: () async {
                              await AmenityTypeScreen.open(context, t.id);
                              controller.refreshAll();
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: PhonebookTheme.blueSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.layers_rounded, color: PhonebookTheme.blue, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: PhonebookTheme.ink),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${t.inventory['assigned']} assigned · ${t.inventory['available']} available'
                                        '${t.inventory['under_repair'] > 0 ? ' · ${t.inventory['under_repair']} in repair' : ''}',
                                        style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.slate, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted, size: 22),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                    if (assets.isNotEmpty) ...[
                      PhonebookSectionHeader(title: 'Individual Assets (${controller.total.value})'),
                      for (final a in assets)
                        AssetTile(
                          asset: a,
                          onTap: () async {
                            await AssetDetailScreen.open(context, a.id);
                            controller.loadInventory();
                          },
                        ),
                    ],
                    if (controller.isLoadingMore.value)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(color: PhonebookTheme.blue, strokeWidth: 2)),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Future<void> _openFilters(BuildContext context) async {
    if (controller.locations.isEmpty) controller.loadLocations();
    final picked = await showModalBottomSheet<AssetQuery>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                color: PhonebookTheme.slate,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final types = c.types.where((t) => _q.categoryId == null || t.categoryId == _q.categoryId).toList();
    final location = c.locations.expand((l) => l.flatten()).where((l) => l.id == _q.locationId).firstOrNull;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2.5)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: PhonebookTheme.blueSoft, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.tune_rounded, color: PhonebookTheme.blue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Filter Assets',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: PhonebookTheme.ink),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _q = AssetQuery.empty;
                      _room.clear();
                    }),
                    child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.redAccent)),
                  ),
                ],
              ),
            ),
            const Divider(height: 18, color: PhonebookTheme.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _group('Category', [
                      for (final cat in c.categories)
                        PhonebookTintChip(
                          label: cat.name,
                          neutralUnselected: true,
                          selected: _q.categoryId == cat.id,
                          onTap: () => setState(() => _q = _q.categoryId == cat.id
                              ? _q.copyWith(clearCategory: true, clearType: true)
                              : _q.copyWith(categoryId: cat.id, clearType: true)),
                        ),
                    ]),
                    if (types.isNotEmpty)
                      _group('Type', [
                        for (final t in types)
                          PhonebookTintChip(
                            label: t.name,
                            neutralUnselected: true,
                            selected: _q.typeId == t.id,
                            onTap: () => setState(() => _q = _q.typeId == t.id ? _q.copyWith(clearType: true) : _q.copyWith(typeId: t.id)),
                          ),
                      ]),
                    _group('Status', [
                      for (final s in AssetStatus.values)
                        PhonebookTintChip(
                          label: AmenityFormat.status(s),
                          color: AmenityFormat.statusColor(s),
                          neutralUnselected: true,
                          selected: _q.status == s,
                          onTap: () => setState(() => _q = _q.status == s ? _q.copyWith(clearStatus: true) : _q.copyWith(status: s)),
                        ),
                    ]),
                    _group('Condition', [
                      for (final s in AssetCondition.values)
                        PhonebookTintChip(
                          label: AmenityFormat.condition(s),
                          neutralUnselected: true,
                          selected: _q.condition == s,
                          onTap: () => setState(() => _q = _q.condition == s ? _q.copyWith(clearCondition: true) : _q.copyWith(condition: s)),
                        ),
                    ]),
                    _group('Where', [
                      for (final p in AssetPlacement.values)
                        PhonebookTintChip(
                          label: AmenityFormat.placement(p),
                          neutralUnselected: true,
                          selected: _q.placement == p,
                          onTap: () => setState(() => _q = _q.placement == p ? _q.copyWith(clearPlacement: true) : _q.copyWith(placement: p)),
                        ),
                    ]),
                    _group('Warranty', [
                      for (final w in const ['active', 'expiring', 'expired', 'none'])
                        PhonebookTintChip(
                          label: AmenityFormat.warranty(w),
                          neutralUnselected: true,
                          selected: _q.warranty == w,
                          onTap: () => setState(() => _q = _q.warranty == w ? _q.copyWith(clearWarranty: true) : _q.copyWith(warranty: w)),
                        ),
                    ]),
                    _group('Maintenance', [
                      for (final m in const [('due', 'Due'), ('open', 'Repair open')])
                        PhonebookTintChip(
                          label: m.$2,
                          neutralUnselected: true,
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
                            prefixIcon: const Icon(Icons.place_outlined, color: PhonebookTheme.blue),
                            suffixIcon: _q.locationId == null
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded, color: PhonebookTheme.muted),
                                    onPressed: () => setState(() => _q = _q.copyWith(clearLocation: true)),
                                  ),
                          ),
                          child: Text(
                            location?.path ?? 'Any location',
                            style: TextStyle(
                              color: location == null ? PhonebookTheme.muted : PhonebookTheme.ink,
                              fontWeight: location == null ? FontWeight.w400 : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _room,
                      decoration: phonebookInputDecoration(
                        label: 'Room number',
                        hint: 'e.g. 204',
                        prefixIcon: const Icon(Icons.meeting_room_outlined, color: PhonebookTheme.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: PhonebookTheme.border)),
                ),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final room = _room.text.trim();
                      Navigator.of(context).pop(room.isEmpty ? _q.copyWith(clearRoom: true) : _q.copyWith(room: room));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PhonebookTheme.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Show Results', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ),
            ),
          ],
        ),
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
        return const Center(child: CircularProgressIndicator(color: PhonebookTheme.blue, strokeWidth: 2.2));
      }
      final error = controller.locationsError.value;
      if (error != null && controller.locations.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 12),
              Text(error, style: const TextStyle(color: PhonebookTheme.slate, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: controller.loadLocations, child: const Text('Retry')),
            ],
          ),
        );
      }
      if (controller.locations.isEmpty) {
        return const Center(
          child: EmptyState(
            icon: Icons.place_outlined,
            title: 'No locations yet',
            message: 'Add a building, floor, or room with the button below.',
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: controller.loadLocations,
        color: PhonebookTheme.blue,
        backgroundColor: Colors.white,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
          children: [
            const PhonebookSectionHeader(title: 'Campus Locations Tree'),
            for (final l in controller.locations) _LocationNode(location: l, depth: 0),
          ],
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
    final leadingIcon = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: l.isActive ? PhonebookTheme.blueSoft : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        locationKindIcon(l.kind),
        size: 18,
        color: l.isActive ? PhonebookTheme.blue : PhonebookTheme.muted,
      ),
    );

    final title = Row(
      children: [
        leadingIcon,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.kind == LocationKind.room ? 'Room ${l.roomNumber ?? l.name}' : l.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: l.isActive ? PhonebookTheme.ink : PhonebookTheme.muted,
                ),
              ),
              Text(
                AmenityFormat.locationKind(l.kind),
                style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (l.assetCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: PhonebookTheme.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${l.assetCount} items',
              style: const TextStyle(
                color: PhonebookTheme.blue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );

    final menu = PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: PhonebookTheme.muted, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) async {
        if (v == 'open') {
          await LocationScreen.open(context, l.id);
        } else if (v == 'add') {
          if (await showLocationForm(context, repo: controller.repo, parent: l)) {
            controller.loadLocations();
          }
        } else {
          if (await showLocationForm(context, repo: controller.repo, existing: l)) {
            controller.loadLocations();
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'open', child: Text('Open details', style: TextStyle(fontWeight: FontWeight.w600))),
        PopupMenuItem(value: 'add', child: Text('Add inside', style: TextStyle(fontWeight: FontWeight.w600))),
        PopupMenuItem(value: 'edit', child: Text('Edit location', style: TextStyle(fontWeight: FontWeight.w600))),
      ],
    );

    if (l.children.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 14.0, bottom: 8),
        child: PhonebookCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () => LocationScreen.open(context, l.id),
          child: Row(
            children: [
              Expanded(child: title),
              menu,
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * 14.0, bottom: 8),
      child: PhonebookCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            title: title,
            trailing: menu,
            shape: const Border(),
            children: [for (final c in l.children) _LocationNode(location: c, depth: depth + 1)],
          ),
        ),
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
        body: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: PhonebookTheme.headerGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3803192E),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _AmenitiesOrbPainter())),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
                        child: Row(
                          children: [
                            PhonebookHeaderCircleButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: 'Back',
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AUDIT TRAIL',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: PhonebookTheme.amberBright,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Activity Log',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Complete history of asset movements, assignments & repairs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AmenityEventsList(load: (offset) => repo.activity(offset: offset), activity: true),
            ),
          ],
        ),
      );
}
