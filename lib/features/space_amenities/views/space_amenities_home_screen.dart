import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/models/space_amenities/space_amenity_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_sliver_header.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/space_amenities_controller.dart';
import '../utils/space_amenity_ui.dart';
import 'asset_details_screen.dart';
import 'asset_scanner_screen.dart';
import 'configuration_screen.dart';
import 'floor_details_screen.dart';
import 'reports_screen.dart';
import 'space_details_screen.dart';

class SpaceAmenitiesHomeScreen extends GetView<SpaceAmenitiesHomeController> {
  const SpaceAmenitiesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value && controller.overview.value == null,
          hasError: controller.hasError.value && controller.overview.value == null,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.loadOverview,
          loadingWidget: const SafeArea(child: SkeletonList()),
          builder: (_) => AppRefreshIndicator(
            onRefresh: () async {
              await controller.loadOverview(showLoading: false);
              if (controller.activeSection.value == 1) await controller.loadAssets();
              if (controller.activeSection.value == 2) await controller.loadMaintenance();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                NavySliverHeader(
                  title: 'Spaces & Amenities',
                  subtitle: 'Hostel inventory overview',
                  onBack: () => Navigator.of(context).pop(),
                  actions: [
                    NavyHeaderAction(
                      icon: Icons.qr_code_scanner_rounded,
                      tooltip: 'Scan asset QR',
                      onTap: () => Get.to(() => const AssetScannerScreen())?.then((_) => controller.loadOverview(showLoading: false)),
                    ),
                    if (controller.isAdminOrWarden)
                      NavyHeaderAction(
                        icon: Icons.analytics_outlined,
                        tooltip: 'Reports & analytics',
                        onTap: () => Get.to(() => const SpaceReportsScreen()),
                      ),
                    if (controller.isAdminOrWarden)
                      NavyHeaderAction(
                        icon: Icons.settings_outlined,
                        tooltip: 'Configuration',
                        onTap: () => Get.to(() => const SpaceConfigurationScreen())?.then((_) => controller.loadOverview(showLoading: false)),
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      AppDimens.gapLg,
                      AppDimens.screenPadding,
                      48,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionTabs(controller: controller),
                        const SizedBox(height: AppDimens.gapLg),
                        Obx(() {
                          switch (controller.activeSection.value) {
                            case 1:
                              return _SpacesAndAssetsSection(controller: controller);
                            case 2:
                              return _MaintenanceSection(controller: controller);
                            default:
                              return _OverviewSection(controller: controller);
                          }
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  final SpaceAmenitiesHomeController controller;
  const _SectionTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('Overview', Icons.dashboard_outlined),
      ('Spaces', Icons.apartment_outlined),
      if (controller.canViewMaintenance) ('Maintenance', Icons.build_outlined),
    ];
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PhonebookTheme.border),
        ),
        child: Row(
          children: [
            for (int i = 0; i < tabs.length; i++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => controller.selectSection(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: controller.activeSection.value == i ? PhonebookTheme.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tabs[i].$2,
                          size: 16,
                          color: controller.activeSection.value == i ? Colors.white : PhonebookTheme.slate,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tabs[i].$1,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: controller.activeSection.value == i ? Colors.white : PhonebookTheme.slate,
                          ),
                        ),
                      ],
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

class _OverviewSection extends StatelessWidget {
  final SpaceAmenitiesHomeController controller;
  const _OverviewSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ov = controller.overview.value;
      if (ov == null) return const SizedBox.shrink();
      final s = ov.summary;
      final res = controller.searchResults.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GlobalSearchField(controller: controller),
          const SizedBox(height: AppDimens.gapLg),
          if (controller.searchQuery.value.trim().isNotEmpty) ...[
            _SearchResultsView(results: res, isSearching: controller.isSearching.value, onRefresh: () => controller.loadOverview(showLoading: false)),
          ] else ...[
            GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.72,
              children: [
                _SummaryTile(
                  label: 'Total Spaces',
                  value: '${s.totalSpaces}',
                  icon: Icons.meeting_room_outlined,
                  color: PhonebookTheme.blue,
                  onTap: () => controller.selectSection(1),
                ),
                _SummaryTile(
                  label: 'Total Assets',
                  value: '${s.totalAssets}',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.primaryDark,
                  onTap: () {
                    controller.assetStatusFilter.value = '';
                    controller.selectSection(1);
                    controller.loadAssets();
                  },
                ),
                _SummaryTile(
                  label: 'Working Assets',
                  value: '${s.workingAssets}',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.successGreen,
                  onTap: () {
                    controller.assetStatusFilter.value = 'working';
                    controller.selectSection(1);
                    controller.loadAssets();
                  },
                ),
                _SummaryTile(
                  label: 'Faulty Assets',
                  value: '${s.faultyAssets}',
                  icon: Icons.warning_amber_rounded,
                  color: s.faultyAssets > 0 ? AppColors.errorRed : PhonebookTheme.muted,
                  onTap: controller.openFaultyAssets,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.gapMd),
            PhonebookCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                title: const Text(
                  'Maintenance & Expense Summary',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: PhonebookTheme.ink),
                ),
                subtitle: Text(
                  '${s.openComplaints} open complaints · ${s.underRepairAssets} under repair',
                  style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted),
                ),
                children: [
                  Row(
                    children: [
                      _MiniStat(label: 'Open', value: '${s.pendingComplaints}', color: AppColors.warningOrange),
                      _MiniStat(label: 'In Progress', value: '${s.inProgressComplaints}', color: PhonebookTheme.blue),
                      _MiniStat(label: 'Awaiting Repl.', value: '${s.awaitingReplacementAssets}', color: AppColors.errorRed),
                      if (s.totalMaintenanceCost != null)
                        _MiniStat(
                          label: 'Maint. Spend',
                          value: '₹${s.totalMaintenanceCost!.toStringAsFixed(0)}',
                          color: PhonebookTheme.ink,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapXl),
            const PhonebookSectionHeader(title: 'Hostel Floors'),
            if (ov.floors.isEmpty)
              const EmptyState(
                icon: Icons.apartment_outlined,
                title: 'No floors found',
                message: 'Floors and spaces will appear here once configured.',
              )
            else
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ov.floors.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (_, i) => _FloorCard(
                  floor: ov.floors[i],
                  onTap: () => Get.to(() => FloorDetailsScreen(floorId: ov.floors[i].floorId))
                      ?.then((_) => controller.loadOverview(showLoading: false)),
                ),
              ),
          ],
        ],
      );
    });
  }
}

class _FloorCard extends StatelessWidget {
  final FloorOverviewItem floor;
  final VoidCallback onTap;
  const _FloorCard({required this.floor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final healthy = floor.healthStatus == 'healthy';
    final healthColor = healthy
        ? AppColors.successGreen
        : (floor.healthStatus == 'attention' ? AppColors.errorRed : PhonebookTheme.amber);
    final healthLabel = healthy ? 'Healthy' : '${floor.openIssues + floor.faultyAssets} Issues';

    return PhonebookCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PhonebookTheme.blueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.layers_outlined, color: PhonebookTheme.blue, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  healthLabel,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: healthColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            floor.floorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: PhonebookTheme.ink),
          ),
          if (floor.subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              floor.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted, height: 1.3),
            ),
          ],
          const Spacer(),
          const Divider(height: 14),
          Row(
            children: [
              Text(
                '${floor.totalSpaces} spaces',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: PhonebookTheme.slate),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${floor.totalAssets} assets',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: PhonebookTheme.slate),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpacesAndAssetsSection extends StatelessWidget {
  final SpaceAmenitiesHomeController controller;
  const _SpacesAndAssetsSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final floors = controller.overview.value?.floors ?? const [];
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PhonebookSectionHeader(title: 'Jump to Floor'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in floors) ...[
                  PhonebookTintChip(
                    label: '${f.floorName} (${f.totalSpaces})',
                    selected: false,
                    icon: Icons.layers_outlined,
                    onTap: () => Get.to(() => FloorDetailsScreen(floorId: f.floorId))
                        ?.then((_) => controller.loadOverview(showLoading: false)),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),
          const PhonebookSectionHeader(title: 'Registered Assets'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PhonebookTintChip(
                label: 'All Active',
                selected: controller.assetStatusFilter.value == '',
                onTap: () {
                  controller.assetStatusFilter.value = '';
                  controller.loadAssets();
                },
              ),
              PhonebookTintChip(
                label: 'Working',
                selected: controller.assetStatusFilter.value == 'working',
                color: AppColors.successGreen,
                onTap: () {
                  controller.assetStatusFilter.value = 'working';
                  controller.loadAssets();
                },
              ),
              PhonebookTintChip(
                label: 'Faulty / Repair',
                selected: controller.assetStatusFilter.value == 'faulty_group',
                color: AppColors.errorRed,
                onTap: () {
                  controller.assetStatusFilter.value = 'faulty_group';
                  controller.loadAssets();
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          if (controller.isLoadingAssets.value)
            const SkeletonList(count: 4, padding: EdgeInsets.zero)
          else if (controller.filteredAssets.isEmpty)
            const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No matching assets',
              message: 'Select a floor above to add amenities to a room or common space.',
            )
          else
            Column(
              children: [
                for (final a in controller.filteredAssets) ...[
                  _AssetListTile(
                    asset: a,
                    onTap: () => Get.to(() => AssetDetailsScreen(assetId: a.id))
                        ?.then((_) {
                      controller.loadAssets();
                      controller.loadOverview(showLoading: false);
                    }),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _MaintenanceSection extends StatelessWidget {
  final SpaceAmenitiesHomeController controller;
  const _MaintenanceSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.canViewMaintenance) {
        return const EmptyState(
          icon: Icons.lock_outline,
          title: 'Restricted',
          message: 'Maintenance workspace is available to administrators and complaint solvers.',
        );
      }
      if (controller.isLoadingMaint.value && controller.maintenance.value == null) {
        return const SkeletonList(count: 4, padding: EdgeInsets.zero);
      }
      final m = controller.maintenance.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (m != null)
            GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _SummaryTile(
                  label: 'Pending (Open)',
                  value: '${m.open}',
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.warningOrange,
                  onTap: () {
                    controller.maintStatusFilter.value = 'OPEN';
                    controller.loadMaintenance();
                  },
                ),
                _SummaryTile(
                  label: 'In Progress',
                  value: '${m.inProgress}',
                  icon: Icons.build_circle_outlined,
                  color: PhonebookTheme.blue,
                  onTap: () {
                    controller.maintStatusFilter.value = 'IN_PROGRESS';
                    controller.loadMaintenance();
                  },
                ),
                _SummaryTile(
                  label: 'Awaiting Repl.',
                  value: '${m.awaitingReplacement}',
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.errorRed,
                  onTap: () {
                    controller.maintStatusFilter.value = '';
                    controller.loadMaintenance();
                  },
                ),
                _SummaryTile(
                  label: 'Completed',
                  value: '${m.completed}',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.successGreen,
                  onTap: () {
                    controller.maintStatusFilter.value = 'RESOLVED';
                    controller.loadMaintenance();
                  },
                ),
              ],
            ),
          const SizedBox(height: AppDimens.gapMd),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final st in [('', 'All'), ('OPEN', 'Open'), ('IN_PROGRESS', 'In Progress'), ('RESOLVED', 'Resolved')])
                PhonebookTintChip(
                  label: st.$2,
                  selected: controller.maintStatusFilter.value == st.$1,
                  onTap: () {
                    controller.maintStatusFilter.value = st.$1;
                    controller.loadMaintenance();
                  },
                ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          if (m == null || m.items.isEmpty)
            const EmptyState(
              icon: Icons.assignment_turned_in_outlined,
              title: 'No maintenance items',
              message: 'Complaints and asset repair tasks matching your filters will appear here.',
            )
          else
            Column(
              children: [
                for (final item in m.items) ...[
                  _MaintenanceCard(
                    item: item,
                    onTap: () => Get.toNamed(
                      Routes.complainAdminDetail,
                      arguments: '${item.id}',
                    )?.then((_) => controller.loadMaintenance()),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      );
    });
  }
}

class _MaintenanceCard extends StatelessWidget {
  final MaintenanceWorkspaceItem item;
  final VoidCallback onTap;
  const _MaintenanceCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cStatus = ComplaintStatusX.fromApi(item.status);
    return PhonebookCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cStatus.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(SpaceAmenityUi.iconFor(item.assetIcon), color: cStatus.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.assetName != null ? '${item.assetName} (${item.item})' : item.item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: PhonebookTheme.ink),
                    ),
                    Text(
                      '${item.floorName} · ${item.spaceName}${item.assetCode != null ? ' · ${item.assetCode}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cStatus.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  cStatus.staffLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cStatus.color),
                ),
              ),
            ],
          ),
          if (item.comment != null && item.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.comment!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.slate),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Priority: ${item.priority.toUpperCase()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PhonebookTheme.slate),
              ),
              const Spacer(),
              if (item.createdAt != null)
                Text(
                  DateFormatting.dateOnly(item.createdAt!),
                  style: const TextStyle(fontSize: 11, color: PhonebookTheme.muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlobalSearchField extends StatelessWidget {
  final SpaceAmenitiesHomeController controller;
  const _GlobalSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: controller.onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search room, floor, asset ID (HSH-...), serial, or amenity',
        prefixIcon: const Icon(Icons.search_rounded, color: PhonebookTheme.muted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PhonebookTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PhonebookTheme.border),
        ),
      ),
    );
  }
}

class _SearchResultsView extends StatelessWidget {
  final Map<String, dynamic>? results;
  final bool isSearching;
  final VoidCallback onRefresh;
  const _SearchResultsView({required this.results, required this.isSearching, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (isSearching && results == null) {
      return const SkeletonList(count: 3, padding: EdgeInsets.zero);
    }
    final floors = ((results?['floors'] as List?) ?? const []).whereType<Map>().toList();
    final spaces = ((results?['spaces'] as List?) ?? const []).whereType<Map>().toList();
    final assets = ((results?['assets'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => SpaceAssetModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    if (floors.isEmpty && spaces.isEmpty && assets.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message: 'Try another room number, floor name, asset ID, or serial number.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (floors.isNotEmpty) ...[
          const PhonebookSectionHeader(title: 'Floors'),
          for (final f in floors) ...[
            PhonebookCard(
              onTap: () => Get.to(() => FloorDetailsScreen(floorId: (f['floor_id'] as num).toInt())),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.layers_outlined, color: PhonebookTheme.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${f['floor_name'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.ink),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
        ],
        if (spaces.isNotEmpty) ...[
          const PhonebookSectionHeader(title: 'Spaces & Rooms'),
          for (final s in spaces) ...[
            PhonebookCard(
              onTap: () => Get.to(() => SpaceDetailsScreen(spaceId: (s['id'] as num).toInt())),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(SpaceAmenityUi.iconFor('${s['space_type_icon'] ?? ''}'), color: PhonebookTheme.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
                        Text('${s['floor_name'] ?? ''} · ${s['space_type_name'] ?? ''}', style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
        ],
        if (assets.isNotEmpty) ...[
          const PhonebookSectionHeader(title: 'Assets'),
          for (final a in assets) ...[
            _AssetListTile(
              asset: a,
              onTap: () => Get.to(() => AssetDetailsScreen(assetId: a.id))?.then((_) => onRefresh()),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PhonebookCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: PhonebookTheme.ink),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: PhonebookTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: PhonebookTheme.muted)),
        ],
      ),
    );
  }
}

class _AssetListTile extends StatelessWidget {
  final SpaceAssetModel asset;
  final VoidCallback onTap;
  const _AssetListTile({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sColor = SpaceAmenityUi.statusColor(asset.status);
    return PhonebookCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: sColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(SpaceAmenityUi.iconFor(asset.typeIcon), color: sColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
                const SizedBox(height: 2),
                Text(
                  '${asset.assetCode} · ${asset.floorName} · ${asset.spaceName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: sColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              SpaceAmenityUi.statusLabel(asset.status),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sColor),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted, size: 20),
        ],
      ),
    );
  }
}
