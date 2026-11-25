import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_config.dart';
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
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/navy_sliver_header.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../utils/space_amenity_ui.dart';
import '../widgets/maintenance_update_sheet.dart';
import '../widgets/replace_asset_sheet.dart';
import '../widgets/transfer_asset_sheet.dart';

class AssetDetailsScreen extends StatefulWidget {
  final int assetId;
  const AssetDetailsScreen({super.key, required this.assetId});

  @override
  State<AssetDetailsScreen> createState() => _AssetDetailsScreenState();
}

class _AssetDetailsScreenState extends State<AssetDetailsScreen> with SingleTickerProviderStateMixin {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  late final TabController _tabs = TabController(length: 4, vsync: this);
  AssetDetailsResponse? _data;
  bool _loading = true;
  String? _error;

  UserRole get _role => Get.find<SessionStore>().currentSession?.role ?? UserRole.unknown;
  bool get _isAdminOrWarden => _role.canOperate;
  bool get _canMaintain => _role.canSolveComplaints;
  bool get _isStudentOrLeader => _role.isStudentOrLeader;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() { _loading = true; _error = null; });
    try {
      final res = await _repo.assetDetails(widget.assetId);
      if (mounted) setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _showQrDialog(SpaceAssetModel asset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(asset.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: asset.assetCode,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(asset.assetCode, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            Text('${asset.floorName} · ${asset.spaceName}', style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _retireAsset(SpaceAssetModel asset) async {
    final noteCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retire Asset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Retire ${asset.name} (${asset.assetCode})? Lifecycle history will be preserved.'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Reason / note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Retire')),
        ],
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (confirm != true) return;
    try {
      await _repo.retireAsset(asset.id, note: note);
      AppSnackbar.success('Asset retired', '${asset.assetCode} archived.');
      _load(showLoading: false);
    } catch (e) {
      AppSnackbar.error('Failed', e.toString());
    }
  }

  Future<void> _showAssetActionsSheet(SpaceAssetModel asset) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Transfer Asset'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final ok = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => TransferAssetSheet(asset: asset),
                );
                if (ok == true) _load(showLoading: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.find_replace_rounded),
              title: const Text('Replace Asset'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final res = await showModalBottomSheet<int>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ReplaceAssetSheet(oldAsset: asset),
                );
                if (res != null) _load(showLoading: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Retire Asset'),
              onTap: () {
                Navigator.of(ctx).pop();
                _retireAsset(asset);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      body: AsyncStateView(
        isLoading: _loading && _data == null,
        hasError: _error != null && _data == null,
        errorMessage: _error ?? '',
        onRetry: _load,
        loadingWidget: const SafeArea(child: SkeletonList()),
        builder: (_) {
          final data = _data!;
          final asset = data.asset;
          final sColor = SpaceAmenityUi.statusColor(asset.status);
          final token = Get.find<SessionStore>().currentToken ?? '';

          return AppRefreshIndicator(
            onRefresh: () => _load(showLoading: false),
            child: NestedScrollView(
              headerSliverBuilder: (_, _) => [
                NavySliverHeader(
                  title: asset.name,
                  subtitle: '${asset.assetCode} · ${asset.floorName} · ${asset.spaceName}',
                  onBack: () => Navigator.of(context).pop(),
                  actions: [
                    NavyHeaderAction(
                      icon: Icons.qr_code_2_rounded,
                      tooltip: 'Asset QR Code',
                      onTap: () => _showQrDialog(asset),
                    ),
                    if (_isAdminOrWarden && !asset.isArchived)
                      NavyHeaderAction(
                        icon: Icons.more_vert_rounded,
                        tooltip: 'Asset actions',
                        onTap: () => _showAssetActionsSheet(asset),
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapLg, AppDimens.screenPadding, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PhonebookCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              if (asset.photoUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    '${AppConfig.mediaBaseUrl}${asset.photoUrl}',
                                    headers: {'Authorization': 'Bearer $token'},
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _IconBox(asset: asset, color: sColor),
                                  ),
                                )
                              else
                                _IconBox(asset: asset, color: sColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(asset.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
                                    const SizedBox(height: 3),
                                    Text('${asset.assetCode} · ${asset.categoryName}', style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _ChipBadge(label: SpaceAmenityUi.statusLabel(asset.status), color: sColor),
                                        _ChipBadge(
                                          label: 'Condition: ${SpaceAmenityUi.conditionLabel(asset.condition)}',
                                          color: SpaceAmenityUi.conditionColor(asset.condition),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (data.replacedBy != null || data.replacesAsset != null) ...[
                          const SizedBox(height: 10),
                          PhonebookCard(
                            onTap: () {
                              final targetId = (data.replacedBy?['id'] ?? data.replacesAsset?['id']) as num?;
                              if (targetId != null) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => AssetDetailsScreen(assetId: targetId.toInt())),
                                );
                              }
                            },
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.swap_horiz_rounded, color: PhonebookTheme.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data.replacedBy != null
                                        ? 'Replaced by ${data.replacedBy!['name']} (${data.replacedBy!['asset_code']})'
                                        : 'Replaces ${data.replacesAsset!['name']} (${data.replacesAsset!['asset_code']})',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: PhonebookTheme.blue),
                                  ),
                                ),
                                const Icon(Icons.open_in_new_rounded, size: 16, color: PhonebookTheme.blue),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _StatBox(label: 'Repairs', value: '${data.totalRepairs}'),
                            const SizedBox(width: 8),
                            if (data.totalMaintenanceCost != null) ...[
                              _StatBox(label: 'Maint. Cost', value: '₹${data.totalMaintenanceCost!.toStringAsFixed(0)}'),
                              const SizedBox(width: 8),
                            ],
                            _StatBox(label: 'Open Issues', value: '${data.openComplaints}'),
                            const SizedBox(width: 8),
                            _StatBox(
                              label: 'Warranty',
                              value: data.warrantyStatus == 'none' ? 'N/A' : data.warrantyStatus.toUpperCase(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (_isStudentOrLeader && !asset.isArchived)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => Get.toNamed(
                                    Routes.complaintAdd,
                                    arguments: {
                                      'spaceId': asset.spaceId,
                                      'assetId': asset.id,
                                      'assetCode': asset.assetCode,
                                      'assetName': asset.name,
                                      'categoryId': asset.complaintCategoryId,
                                      'itemId': asset.complaintItemId,
                                    },
                                  )?.then((_) => _load(showLoading: false)),
                                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                                  label: const Text('Report Complaint'),
                                ),
                              ),
                            if (_canMaintain && !asset.isArchived) ...[
                              if (_isStudentOrLeader) const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ok = await showModalBottomSheet<bool>(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => MaintenanceUpdateSheet(
                                        assetId: asset.id,
                                        assetName: '${asset.name} (${asset.assetCode})',
                                        currentCondition: asset.condition,
                                        canReplaceAsset: _isAdminOrWarden,
                                      ),
                                    );
                                    if (ok == true) _load(showLoading: false);
                                  },
                                  icon: const Icon(Icons.build_outlined, size: 18),
                                  label: const Text('Update Maintenance'),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        TabBar(
                          controller: _tabs,
                          isScrollable: true,
                          tabs: const [
                            Tab(text: 'Timeline'),
                            Tab(text: 'Details'),
                            Tab(text: 'Complaints'),
                            Tab(text: 'Location History'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabs,
                children: [
                  _TimelineTab(events: data.timeline),
                  _DetailsTab(asset: asset),
                  _ComplaintsTab(
                    complaints: data.complaints,
                    isStaff: _canMaintain,
                    onRefresh: () => _load(showLoading: false),
                  ),
                  _LocationHistoryTab(history: data.locationHistory),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final SpaceAssetModel asset;
  final Color color;
  const _IconBox({required this.asset, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(SpaceAmenityUi.iconFor(asset.typeIcon), color: color, size: 28),
    );
  }
}

class _ChipBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ChipBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PhonebookCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: PhonebookTheme.muted)),
          ],
        ),
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  final List<AssetEventModel> events;
  const _TimelineTab({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const EmptyState(icon: Icons.timeline_rounded, title: 'No lifecycle events', message: 'History events will appear here.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final e = events[i];
        return PhonebookCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: PhonebookTheme.blueSoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.history_rounded, color: PhonebookTheme.blue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.description, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (e.byName != null) 'By ${e.byName}',
                        if (e.createdAt != null) DateFormatting.dateOnly(e.createdAt!),
                        if (e.cost != null) 'Cost ₹${e.cost!.toStringAsFixed(0)}',
                        if (e.complaintId != null) 'Complaint #${e.complaintId}',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final SpaceAssetModel asset;
  const _DetailsTab({required this.asset});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      children: [
        PhonebookCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              InfoRow(icon: Icons.qr_code_2_rounded, label: 'Asset ID', value: asset.assetCode),
              InfoRow(icon: Icons.category_outlined, label: 'Category', value: asset.categoryName),
              InfoRow(icon: Icons.inventory_2_outlined, label: 'Amenity Type', value: asset.typeName),
              InfoRow(icon: Icons.location_on_outlined, label: 'Current Space', value: '${asset.floorName} · ${asset.spaceName}'),
              if (asset.manufacturer != null) InfoRow(icon: Icons.factory_outlined, label: 'Manufacturer', value: asset.manufacturer!),
              if (asset.serialNumber != null) InfoRow(icon: Icons.confirmation_number_outlined, label: 'Serial Number', value: asset.serialNumber!),
              if (asset.supplier != null) InfoRow(icon: Icons.storefront_outlined, label: 'Supplier', value: asset.supplier!),
              if (asset.purchaseDate != null) InfoRow(icon: Icons.calendar_today_outlined, label: 'Purchase Date', value: asset.purchaseDate!),
              if (asset.purchaseCost != null) InfoRow(icon: Icons.currency_rupee_rounded, label: 'Purchase Cost', value: '₹${asset.purchaseCost!.toStringAsFixed(2)}'),
              if (asset.installationDate != null) InfoRow(icon: Icons.event_available_outlined, label: 'Installation Date', value: asset.installationDate!),
              if (asset.warrantyExpiresAt != null) InfoRow(icon: Icons.verified_user_outlined, label: 'Warranty Until', value: asset.warrantyExpiresAt!),
              if (asset.notes != null) InfoRow(icon: Icons.notes_rounded, label: 'Notes', value: asset.notes!),
              if (asset.createdByName != null) InfoRow(icon: Icons.person_outline_rounded, label: 'Registered By', value: asset.createdByName!),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComplaintsTab extends StatelessWidget {
  final List<Map<String, dynamic>> complaints;
  final bool isStaff;
  final VoidCallback onRefresh;
  const _ComplaintsTab({required this.complaints, required this.isStaff, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (complaints.isEmpty) {
      return const EmptyState(icon: Icons.check_circle_outline, title: 'No complaints', message: 'No complaints have been linked to this asset.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      itemCount: complaints.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final c = complaints[i];
        return PhonebookCard(
          onTap: () => Get.toNamed(
            isStaff ? Routes.complainAdminDetail : Routes.complaintDetail,
            arguments: '${c['id']}',
          )?.then((_) => onRefresh()),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${c['id']} · ${c['item'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
                    if (c['comment'] != null) Text('${c['comment']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: PhonebookTheme.slate)),
                    Text('Status: ${c['status'] ?? ''} · Priority: ${c['priority'] ?? 'medium'}', style: const TextStyle(fontSize: 11, color: PhonebookTheme.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted),
            ],
          ),
        );
      },
    );
  }
}

class _LocationHistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _LocationHistoryTab({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const EmptyState(icon: Icons.location_on_outlined, title: 'No location changes', message: 'Transfers and placements appear here.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final h = history[i];
        return PhonebookCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${h['reason'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
              const SizedBox(height: 4),
              Text(
                [
                  if (h['from_space_name'] != null) 'From: ${h['from_space_name']}',
                  if (h['to_space_name'] != null) 'To: ${h['to_space_name']}',
                  if (h['by_name'] != null) 'By ${h['by_name']}',
                ].join(' · '),
                style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}
