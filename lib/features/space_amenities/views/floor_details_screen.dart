import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/models/space_amenities/space_amenity_models.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../../core/storage/session_store.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_sliver_header.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../utils/space_amenity_ui.dart';
import '../widgets/space_editor_sheet.dart';
import 'space_details_screen.dart';

class FloorDetailsScreen extends StatefulWidget {
  final int floorId;
  const FloorDetailsScreen({super.key, required this.floorId});

  @override
  State<FloorDetailsScreen> createState() => _FloorDetailsScreenState();
}

class _FloorDetailsScreenState extends State<FloorDetailsScreen> {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  FloorDetailsResponse? _data;
  bool _loading = true;
  String? _error;

  String _search = '';
  String _kindFilter = ''; // '', 'student', 'common'
  int? _spaceTypeId;
  bool _hasIssuesOnly = false;
  bool _gridView = true;

  bool get _isAdminOrWarden =>
      (Get.find<SessionStore>().currentSession?.role ?? UserRole.unknown).canOperate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() { _loading = true; _error = null; });
    try {
      final res = await _repo.floorDetails(
        widget.floorId,
        search: _search,
        kind: _kindFilter.isEmpty ? null : _kindFilter,
        spaceTypeId: _spaceTypeId,
        hasIssues: _hasIssuesOnly,
      );
      if (mounted) setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final floorName = _data?.floorName ?? 'Floor ${widget.floorId}';
    final subtitle = _data == null
        ? 'Loading spaces…'
        : '${_data!.totalSpaces} spaces · ${_data!.totalAssets} amenities · ${_data!.openIssues} open issues';

    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      floatingActionButton: _isAdminOrWarden && _data != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SpaceEditorSheet(
                    floorId: widget.floorId,
                    spaceTypes: _data!.spaceTypes,
                  ),
                );
                if (created == true) _load(showLoading: false);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Space'),
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
          final commonSpaces = data.spaces.where((s) => !s.isStudentRoom).toList();
          final studentRooms = data.spaces.where((s) => s.isStudentRoom).toList();

          return AppRefreshIndicator(
            onRefresh: () => _load(showLoading: false),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                NavySliverHeader(
                  title: floorName,
                  subtitle: subtitle,
                  onBack: () => Navigator.of(context).pop(),
                  actions: [
                    NavyHeaderAction(
                      icon: _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                      tooltip: _gridView ? 'List view' : 'Grid view',
                      onTap: () => setState(() => _gridView = !_gridView),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapLg, AppDimens.screenPadding, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          onChanged: (v) {
                            _search = v;
                            _load(showLoading: false);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search spaces on $floorName…',
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
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              PhonebookTintChip(
                                label: 'All spaces',
                                selected: _kindFilter.isEmpty && _spaceTypeId == null && !_hasIssuesOnly,
                                onTap: () {
                                  setState(() { _kindFilter = ''; _spaceTypeId = null; _hasIssuesOnly = false; });
                                  _load(showLoading: false);
                                },
                              ),
                              const SizedBox(width: 8),
                              PhonebookTintChip(
                                label: 'Student rooms',
                                selected: _kindFilter == 'student',
                                onTap: () {
                                  setState(() { _kindFilter = 'student'; _spaceTypeId = null; });
                                  _load(showLoading: false);
                                },
                              ),
                              const SizedBox(width: 8),
                              PhonebookTintChip(
                                label: 'Common spaces',
                                selected: _kindFilter == 'common',
                                onTap: () {
                                  setState(() { _kindFilter = 'common'; _spaceTypeId = null; });
                                  _load(showLoading: false);
                                },
                              ),
                              const SizedBox(width: 8),
                              PhonebookTintChip(
                                label: 'With issues',
                                selected: _hasIssuesOnly,
                                color: AppColors.errorRed,
                                onTap: () {
                                  setState(() => _hasIssuesOnly = !_hasIssuesOnly);
                                  _load(showLoading: false);
                                },
                              ),
                              for (final st in data.spaceTypes.where((t) => !t.isStudentRoom)) ...[
                                const SizedBox(width: 8),
                                PhonebookTintChip(
                                  label: st.name,
                                  selected: _spaceTypeId == st.id,
                                  onTap: () {
                                    setState(() {
                                      _spaceTypeId = _spaceTypeId == st.id ? null : st.id;
                                      _kindFilter = '';
                                    });
                                    _load(showLoading: false);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapLg),
                        if (data.spaces.isEmpty)
                          const EmptyState(
                            icon: Icons.meeting_room_outlined,
                            title: 'No spaces match',
                            message: 'Adjust your filters or add a new space on this floor.',
                          )
                        else ...[
                          if (commonSpaces.isNotEmpty) ...[
                            const PhonebookSectionHeader(title: 'Common & Special Spaces'),
                            for (final sp in commonSpaces) ...[
                              _SpaceCard(
                                space: sp,
                                compact: false,
                                onTap: () => Get.to(() => SpaceDetailsScreen(spaceId: sp.id))
                                    ?.then((_) => _load(showLoading: false)),
                              ),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: AppDimens.gapMd),
                          ],
                          if (studentRooms.isNotEmpty) ...[
                            const PhonebookSectionHeader(title: 'Student Rooms'),
                            if (_gridView)
                              GridView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: studentRooms.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 1.05,
                                ),
                                itemBuilder: (_, i) => _SpaceCard(
                                  space: studentRooms[i],
                                  compact: true,
                                  onTap: () => Get.to(() => SpaceDetailsScreen(spaceId: studentRooms[i].id))
                                      ?.then((_) => _load(showLoading: false)),
                                ),
                              )
                            else
                              for (final sp in studentRooms) ...[
                                _SpaceCard(
                                  space: sp,
                                  compact: false,
                                  onTap: () => Get.to(() => SpaceDetailsScreen(spaceId: sp.id))
                                      ?.then((_) => _load(showLoading: false)),
                                ),
                                const SizedBox(height: 10),
                              ],
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

class _SpaceCard extends StatelessWidget {
  final SpaceCardItem space;
  final bool compact;
  final VoidCallback onTap;
  const _SpaceCard({required this.space, required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasIssue = space.faultyAssets > 0 || space.openIssues > 0;
    final badgeColor = hasIssue ? AppColors.errorRed : AppColors.successGreen;
    final badgeLabel = hasIssue
        ? (space.faultyAssets > 0 ? '${space.faultyAssets} faulty' : '${space.openIssues} issue')
        : 'All working';

    return PhonebookCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: PhonebookTheme.blueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(SpaceAmenityUi.iconFor(space.spaceTypeIcon), color: PhonebookTheme.blue, size: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            space.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: PhonebookTheme.ink),
          ),
          Text(
            '${space.spaceTypeName}${space.capacity != null ? ' · Cap ${space.capacity}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted),
          ),
          if (compact) const Spacer() else const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${space.totalAssets} amenities',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: PhonebookTheme.slate),
              ),
              if (space.residentCount > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '· ${space.residentCount} students',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: PhonebookTheme.slate),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
