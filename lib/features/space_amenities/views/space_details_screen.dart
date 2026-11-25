import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/models/space_amenities/space_amenity_models.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_sliver_header.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../utils/space_amenity_ui.dart';
import '../widgets/add_amenity_sheet.dart';
import '../widgets/space_editor_sheet.dart';
import 'asset_details_screen.dart';

class SpaceDetailsScreen extends StatefulWidget {
  final int spaceId;
  const SpaceDetailsScreen({super.key, required this.spaceId});

  @override
  State<SpaceDetailsScreen> createState() => _SpaceDetailsScreenState();
}

class _SpaceDetailsScreenState extends State<SpaceDetailsScreen> {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  SpaceDetailsResponse? _data;
  bool _loading = true;
  String? _error;
  final Set<int> _expandedTypes = {};

  UserRole get _role => Get.find<SessionStore>().currentSession?.role ?? UserRole.unknown;
  bool get _isAdminOrWarden => _role.canOperate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() { _loading = true; _error = null; });
    try {
      final res = await _repo.spaceDetails(widget.spaceId);
      if (mounted) setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openEditSpace() async {
    final data = _data;
    if (data == null) return;
    final cfg = await _repo.config();
    if (!mounted) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SpaceEditorSheet(
        floorId: data.space.floorId,
        spaceTypes: cfg.spaceTypes,
        existing: data.space,
      ),
    );
    if (updated == true) _load(showLoading: false);
  }

  Future<void> _archiveSpace() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Space'),
        content: const Text('Archive this space? Active assets must be transferred or retired first.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Archive')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.archiveSpace(widget.spaceId);
      AppSnackbar.success('Space archived', 'The space has been archived.');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      AppSnackbar.error('Could not archive', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = _data?.space;
    final title = sp?.name ?? 'Space Details';
    final subtitle = sp == null
        ? 'Loading space…'
        : '${sp.floorName} · ${sp.spaceTypeName}${sp.capacity != null ? ' · Cap ${sp.capacity}' : ''}';

    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      floatingActionButton: _isAdminOrWarden && sp != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                final added = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AddAmenitySheet(space: sp),
                );
                if (added == true) _load(showLoading: false);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Amenity'),
            )
          : null,
      body: AsyncStateView(
        isLoading: _loading && _data == null,
        hasError: _error != null && _data == null,
        errorMessage: _error ?? '',
        onRetry: _load,
        loadingWidget: const SafeArea(child: SkeletonList()),
        builder: (_) {
          final data = _data!;
          final groupedAssets = <int, List<SpaceAssetModel>>{};
          for (final a in data.assets) {
            groupedAssets.putIfAbsent(a.typeId, () => []).add(a);
          }

          return AppRefreshIndicator(
            onRefresh: () => _load(showLoading: false),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                NavySliverHeader(
                  title: title,
                  subtitle: subtitle,
                  onBack: () => Navigator.of(context).pop(),
                  actions: [
                    if (_isAdminOrWarden)
                      NavyHeaderAction(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit space',
                        onTap: _openEditSpace,
                      ),
                    if (_isAdminOrWarden)
                      NavyHeaderAction(
                        icon: Icons.archive_outlined,
                        tooltip: 'Archive space',
                        onTap: _archiveSpace,
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapLg, AppDimens.screenPadding, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _StatPill(label: 'Total Assets', value: '${data.totalAssets}', color: PhonebookTheme.blue),
                            const SizedBox(width: 8),
                            _StatPill(label: 'Working', value: '${data.workingAssets}', color: AppColors.successGreen),
                            const SizedBox(width: 8),
                            _StatPill(
                              label: 'Faulty',
                              value: '${data.faultyAssets}',
                              color: data.faultyAssets > 0 ? AppColors.errorRed : PhonebookTheme.muted,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.gapXl),
                        const PhonebookSectionHeader(title: 'Actual Inventory Summary'),
                        if (data.inventorySummary.isEmpty)
                          const PhonebookCard(
                            padding: EdgeInsets.all(14),
                            child: Text(
                              'No registered amenities in this space yet.',
                              style: TextStyle(fontSize: 13, color: PhonebookTheme.muted),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final item in data.inventorySummary)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: item.faulty > 0 ? AppColors.errorRed.withValues(alpha: 0.4) : PhonebookTheme.border,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(SpaceAmenityUi.iconFor(item.typeIcon), size: 17, color: PhonebookTheme.blue),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${item.typeName} × ${item.total}',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: PhonebookTheme.ink),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: AppDimens.gapXl),
                        const PhonebookSectionHeader(title: 'Individual Assets'),
                        if (data.assets.isEmpty)
                          const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No individual assets',
                            message: 'Tap Add Amenity to register physical items in this space.',
                          )
                        else
                          Column(
                            children: [
                              for (final entry in groupedAssets.entries)
                                if (entry.value.length == 1) ...[
                                  _AssetCard(
                                    asset: entry.value.first,
                                    onTap: () => Get.to(() => AssetDetailsScreen(assetId: entry.value.first.id))
                                        ?.then((_) => _load(showLoading: false)),
                                  ),
                                  const SizedBox(height: 10),
                                ] else ...[
                                  _GroupedAssetCard(
                                    assets: entry.value,
                                    expanded: _expandedTypes.contains(entry.key),
                                    onToggle: () => setState(() {
                                      if (_expandedTypes.contains(entry.key)) {
                                        _expandedTypes.remove(entry.key);
                                      } else {
                                        _expandedTypes.add(entry.key);
                                      }
                                    }),
                                    onSelectAsset: (a) => Get.to(() => AssetDetailsScreen(assetId: a.id))
                                        ?.then((_) => _load(showLoading: false)),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                            ],
                          ),
                        const SizedBox(height: AppDimens.gapMd),
                        if (data.assignedStudents.isNotEmpty)
                          _ExpandableInfoSection(
                            title: 'Assigned Students (${data.assignedStudents.length})',
                            icon: Icons.people_outline_rounded,
                            children: [
                              for (final s in data.assignedStudents)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                  subtitle: Text('ID: ${s.id} · Code: ${s.studentCode}', style: const TextStyle(fontSize: 11.5)),
                                ),
                            ],
                          ),
                        if (data.openComplaints.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _ExpandableInfoSection(
                            title: 'Open Complaints (${data.openComplaints.length})',
                            icon: Icons.report_problem_outlined,
                            children: [
                              for (final c in data.openComplaints)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${c['item'] ?? ''} (${c['category'] ?? ''})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                  subtitle: Text('${c['comment'] ?? c['status'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                                  onTap: _role.canSolveComplaints
                                      ? () => Get.toNamed(Routes.complainAdminDetail, arguments: '${c['id']}')?.then((_) => _load(showLoading: false))
                                      : null,
                                ),
                            ],
                          ),
                        ],
                        if (data.space.roomNumber != null && _isAdminOrWarden) ...[
                          const SizedBox(height: 10),
                          _ExpandableInfoSection(
                            title: 'Room Keys (${data.roomKeys.length})',
                            icon: Icons.key_rounded,
                            children: [
                              for (final rk in data.roomKeys)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${rk['key_type'] == 'door' ? 'Door' : 'Cupboard'} #${rk['key_number'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                  subtitle: Text(
                                    rk['student_name'] != null ? 'With ${rk['student_name']}' : 'Status: ${rk['status'] ?? 'office'}',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => Get.toNamed(Routes.operatorRoomKeysRoom, arguments: data.space.roomNumber)
                                      ?.then((_) => _load(showLoading: false)),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                  label: const Text('Manage Room Keys'),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (data.maintenanceHistory.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _ExpandableInfoSection(
                            title: 'Maintenance History (${data.maintenanceHistory.length})',
                            icon: Icons.history_rounded,
                            children: [
                              for (final m in data.maintenanceHistory)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${m['asset_name'] ?? ''} · ${m['action'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text('${m['work_performed'] ?? m['root_cause'] ?? ''}', style: const TextStyle(fontSize: 11.5)),
                                ),
                            ],
                          ),
                        ],
                        if (data.archivedAssets.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _ExpandableInfoSection(
                            title: 'Archived & Replaced Assets (${data.archivedAssets.length})',
                            icon: Icons.inventory_outlined,
                            children: [
                              for (final a in data.archivedAssets)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${a.name} (${a.assetCode})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text(SpaceAmenityUi.statusLabel(a.status), style: const TextStyle(fontSize: 11.5)),
                                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                                  onTap: () => Get.to(() => AssetDetailsScreen(assetId: a.id)),
                                ),
                            ],
                          ),
                        ],
                        if (data.previousAllocations.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _ExpandableInfoSection(
                            title: 'Previous Asset Allocations (${data.previousAllocations.length})',
                            icon: Icons.swap_horiz_rounded,
                            children: [
                              for (final p in data.previousAllocations)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${p['asset_name'] ?? ''} (${p['asset_code'] ?? ''})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text(
                                    '${p['description'] ?? ''} · ${p['created_at'] != null ? DateFormatting.dateOnly(DateTime.tryParse('${p['created_at']}') ?? DateTime.now()) : ''}',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PhonebookCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PhonebookTheme.muted)),
          ],
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  final SpaceAssetModel asset;
  final VoidCallback onTap;
  const _AssetCard({required this.asset, required this.onTap});

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
                  '${asset.assetCode} · ${SpaceAmenityUi.conditionLabel(asset.condition)}',
                  style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted),
                ),
              ],
            ),
          ),
          if (asset.openComplaintsCount > 0) ...[
            const Icon(Icons.report_problem_outlined, size: 17, color: AppColors.errorRed),
            const SizedBox(width: 6),
          ],
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

class _GroupedAssetCard extends StatelessWidget {
  final List<SpaceAssetModel> assets;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<SpaceAssetModel> onSelectAsset;

  const _GroupedAssetCard({
    required this.assets,
    required this.expanded,
    required this.onToggle,
    required this.onSelectAsset,
  });

  @override
  Widget build(BuildContext context) {
    final first = assets.first;
    final faulty = assets.where((a) => a.status != 'working').length;
    return PhonebookCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PhonebookTheme.blueSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(SpaceAmenityUi.iconFor(first.typeIcon), color: PhonebookTheme.blue, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${first.typeName} (${assets.length} items)',
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: PhonebookTheme.ink),
                        ),
                        Text(
                          faulty == 0 ? 'All working' : '$faulty need attention',
                          style: TextStyle(fontSize: 11.5, color: faulty == 0 ? AppColors.successGreen : AppColors.errorRed, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: PhonebookTheme.muted),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            for (final a in assets)
              ListTile(
                dense: true,
                onTap: () => onSelectAsset(a),
                title: Text('${a.name} · ${a.assetCode}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('${SpaceAmenityUi.statusLabel(a.status)} · ${SpaceAmenityUi.conditionLabel(a.condition)}', style: const TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              ),
          ],
        ],
      ),
    );
  }
}

class _ExpandableInfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _ExpandableInfoSection({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return PhonebookCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon, color: PhonebookTheme.blue, size: 20),
        title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: children,
      ),
    );
  }
}
