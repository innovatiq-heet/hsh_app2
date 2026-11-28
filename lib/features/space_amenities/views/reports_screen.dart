import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_sliver_header.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../utils/space_amenity_access.dart';

class SpaceReportsScreen extends StatefulWidget {
  const SpaceReportsScreen({super.key});

  @override
  State<SpaceReportsScreen> createState() => _SpaceReportsScreenState();
}

class _SpaceReportsScreenState extends State<SpaceReportsScreen> {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() { _loading = true; _error = null; });
    try {
      final res = await _repo.reports();
      if (mounted) setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SpaceAmenityAccess.canConfigure) {
      return Scaffold(
        backgroundColor: PhonebookTheme.bg,
        body: CustomScrollView(
          slivers: [
            NavySliverHeader(
              title: 'Reports & Analytics',
              subtitle: 'Asset health, expenses & warranties',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.lock_outline,
                title: 'Restricted',
                message: 'Reports are available to administrators and wardens.',
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      body: AsyncStateView(
        isLoading: _loading && _data == null,
        hasError: _error != null && _data == null,
        errorMessage: _error ?? '',
        onRetry: _load,
        loadingWidget: const SafeArea(child: SkeletonList()),
        builder: (_) {
          final d = _data!;
          final byFloor = ((d['by_floor'] as List?) ?? const []).whereType<Map>().toList();
          final byCat = ((d['by_category'] as List?) ?? const []).whereType<Map>().toList();
          final costs = (d['maintenance_costs'] as Map?) ?? const {};
          final expiring = ((d['expiring_warranties'] as List?) ?? const []).whereType<Map>().toList();

          return AppRefreshIndicator(
            onRefresh: () => _load(showLoading: false),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                NavySliverHeader(
                  title: 'Reports & Analytics',
                  subtitle: 'Asset health, expenses & warranties',
                  onBack: () => Navigator.of(context).pop(),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapLg, AppDimens.screenPadding, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PhonebookSectionHeader(title: 'Maintenance Expenditure'),
                        PhonebookCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _CostCol(label: 'Material', val: '₹${costs['material_cost'] ?? 0}'),
                              _CostCol(label: 'Labor', val: '₹${costs['labor_cost'] ?? 0}'),
                              _CostCol(label: 'Total', val: '₹${costs['total_cost'] ?? 0}'),
                              _CostCol(label: 'Jobs', val: '${costs['total_jobs'] ?? 0}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapLg),
                        const PhonebookSectionHeader(title: 'Breakdown by Floor'),
                        for (final f in byFloor) ...[
                          PhonebookCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${f['floor_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text('${f['total_assets'] ?? 0} assets · ${f['working_assets'] ?? 0} working · ${f['faulty_assets'] ?? 0} faulty', style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted)),
                                    ],
                                  ),
                                ),
                                Text('₹${f['total_purchase_value'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.blue)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: AppDimens.gapLg),
                        const PhonebookSectionHeader(title: 'Breakdown by Category'),
                        for (final c in byCat) ...[
                          PhonebookCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${c['category_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('${c['total_assets'] ?? 0} total (${c['faulty_assets'] ?? 0} faulty)', style: TextStyle(fontSize: 12, color: ((c['faulty_assets'] as num?) ?? 0) > 0 ? AppColors.errorRed : AppColors.successGreen, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (expiring.isNotEmpty) ...[
                          const SizedBox(height: AppDimens.gapLg),
                          const PhonebookSectionHeader(title: 'Warranties Expiring Soon'),
                          for (final a in expiring) ...[
                            PhonebookCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text('${a['name']} (${a['asset_code']})', style: const TextStyle(fontWeight: FontWeight.w700))),
                                  Text('${a['warranty_expires_at'] ?? ''}', style: const TextStyle(fontSize: 12, color: PhonebookTheme.amber, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
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

class _CostCol extends StatelessWidget {
  final String label;
  final String val;
  const _CostCol({required this.label, required this.val});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
        Text(label, style: const TextStyle(fontSize: 11, color: PhonebookTheme.muted)),
      ],
    );
  }
}
