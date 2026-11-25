import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/models/auth/user_session.dart';
import '../../../core/models/space_amenities/space_amenity_models.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../../core/storage/session_store.dart';
import '../../home/controllers/home_controller.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_sliver_header.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../utils/space_amenity_ui.dart';
import 'asset_details_screen.dart';
import 'space_details_screen.dart';

class StudentMySpaceScreen extends StatefulWidget {
  const StudentMySpaceScreen({super.key});

  @override
  State<StudentMySpaceScreen> createState() => _StudentMySpaceScreenState();
}

class _StudentMySpaceScreenState extends State<StudentMySpaceScreen> {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  StudentMySpaceResponse? _data;
  bool _loading = true;
  String? _error;

  bool get _isAlumni => UserSession.isAlumniRoomOrId(room: Get.find<SessionStore>().currentSession?.room);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() { _loading = true; _error = null; });
    try {
      final res = await _repo.studentMySpace();
      if (mounted) setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _reportAsset(SpaceAssetModel asset) {
    Get.toNamed(
      Routes.complaintAdd,
      arguments: {
        'spaceId': asset.spaceId,
        'assetId': asset.id,
        'assetCode': asset.assetCode,
        'assetName': asset.name,
        'categoryId': asset.complaintCategoryId,
        'itemId': asset.complaintItemId,
      },
    )?.then((_) => _load(showLoading: false));
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
          final myRoom = data.myRoom;

          return AppRefreshIndicator(
            onRefresh: () => _load(showLoading: false),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                NavySliverHeader(
                  title: 'My Room & Amenities',
                  subtitle: myRoom != null ? '${myRoom.space.floorName} · ${myRoom.space.name}' : 'Room & common hostel spaces',
                  onBack: () => Navigator.of(context).pop(),
                  actions: [
                    NavyHeaderAction(
                      icon: Icons.support_agent_outlined,
                      tooltip: 'My Complaints',
                      onTap: () {
                        if (Get.isRegistered<HomeController>()) {
                          Get.find<HomeController>().changeTab(HomeController.complaintsTab);
                        }
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapLg, AppDimens.screenPadding, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PhonebookSectionHeader(title: 'My Room'),
                        if (myRoom == null)
                          const EmptyState(
                            icon: Icons.meeting_room_outlined,
                            title: 'No room assigned',
                            message: 'Room amenities appear once a hostel room is assigned.',
                          )
                        else ...[
                          PhonebookCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(color: PhonebookTheme.blueSoft, borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.bed_outlined, color: PhonebookTheme.blue),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(myRoom.space.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: PhonebookTheme.ink)),
                                      Text(
                                        '${myRoom.space.floorName} · ${myRoom.totalAssets} amenities · ${myRoom.openComplaintsCount} open complaints',
                                        style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapLg),
                          const PhonebookSectionHeader(title: 'My Room Amenities'),
                          if (myRoom.assets.isEmpty)
                            const PhonebookCard(
                              padding: EdgeInsets.all(14),
                              child: Text('No amenities registered in your room yet.', style: TextStyle(color: PhonebookTheme.muted)),
                            )
                          else
                            for (final a in myRoom.assets) ...[
                              PhonebookCard(
                                onTap: () => Get.to(() => AssetDetailsScreen(assetId: a.id)),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(SpaceAmenityUi.iconFor(a.typeIcon), color: SpaceAmenityUi.statusColor(a.status)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
                                          Text(
                                            '${a.assetCode} · ${SpaceAmenityUi.statusLabel(a.status)}',
                                            style: TextStyle(fontSize: 11.5, color: SpaceAmenityUi.statusColor(a.status), fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isAlumni)
                                      TextButton(
                                        onPressed: () => _reportAsset(a),
                                        child: const Text('Report'),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                        ],
                        const SizedBox(height: AppDimens.gapLg),
                        const PhonebookSectionHeader(title: 'Common Spaces'),
                        if (data.commonSpaces.isEmpty)
                          const PhonebookCard(
                            padding: EdgeInsets.all(14),
                            child: Text('No common spaces listed.', style: TextStyle(color: PhonebookTheme.muted)),
                          )
                        else
                          for (final sp in data.commonSpaces) ...[
                            PhonebookCard(
                              onTap: () => Get.to(() => SpaceDetailsScreen(spaceId: sp.id)),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(SpaceAmenityUi.iconFor(sp.spaceTypeIcon), color: PhonebookTheme.blue),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(sp.name, style: const TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
                                        Text('${sp.floorName} · ${sp.spaceTypeName} · ${sp.totalAssets} amenities', style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: PhonebookTheme.muted),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        const SizedBox(height: AppDimens.gapLg),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (Get.isRegistered<HomeController>()) {
                              Get.find<HomeController>().changeTab(HomeController.complaintsTab);
                            }
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.support_agent_outlined, color: AppColors.warningOrange),
                          label: const Text('View My Complaints'),
                        ),
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
