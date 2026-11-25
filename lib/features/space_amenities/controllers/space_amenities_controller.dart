import 'dart:async';
import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/models/space_amenities/space_amenity_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../../core/storage/session_store.dart';

class SpaceAmenitiesHomeController extends GetxController with LoadStateMixin {
  final SpaceAmenitiesRepository _repo;
  SpaceAmenitiesHomeController({SpaceAmenitiesRepository? repository})
      : _repo = repository ?? Get.find<SpaceAmenitiesRepository>();

  final activeSection = 0.obs; // 0 = Overview, 1 = Spaces, 2 = Maintenance
  final overview = Rxn<SpaceOverviewResponse>();
  final statsExpanded = false.obs;

  // Global search
  final searchQuery = ''.obs;
  final isSearching = false.obs;
  final searchResults = Rxn<Map<String, dynamic>>();
  Timer? _debounce;

  // Filtered assets list (for Spaces / Faulty quick view)
  final assetStatusFilter = ''.obs; // '', 'working', 'faulty_group'
  final filteredAssets = <SpaceAssetModel>[].obs;
  final isLoadingAssets = false.obs;

  // Maintenance workspace tab
  final maintenance = Rxn<MaintenanceWorkspaceResponse>();
  final maintStatusFilter = ''.obs;
  final maintPriorityFilter = ''.obs;
  final isLoadingMaint = false.obs;

  UserRole get role => Get.find<SessionStore>().currentSession?.role ?? UserRole.unknown;
  bool get isAdminOrWarden => role.canOperate;
  bool get canViewMaintenance => role.canSolveComplaints;

  @override
  void onInit() {
    super.onInit();
    loadOverview();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> loadOverview({bool showLoading = true}) => guard(() async {
        overview.value = await _repo.overview();
      }, showLoading: showLoading);

  void selectSection(int idx) {
    activeSection.value = idx;
    if (idx == 1 && filteredAssets.isEmpty) loadAssets();
    if (idx == 2 && maintenance.value == null && canViewMaintenance) loadMaintenance();
  }

  void openFaultyAssets() {
    assetStatusFilter.value = 'faulty_group';
    activeSection.value = 1;
    loadAssets();
  }

  void onSearchChanged(String val) {
    searchQuery.value = val;
    _debounce?.cancel();
    if (val.trim().isEmpty) {
      searchResults.value = null;
      isSearching.value = false;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      isSearching.value = true;
      try {
        searchResults.value = await _repo.search(val.trim());
      } catch (_) {
        // Keep current results if transient search fails
      } finally {
        isSearching.value = false;
      }
    });
  }

  Future<void> loadAssets() async {
    isLoadingAssets.value = true;
    try {
      final list = await _repo.listAssets(
        status: assetStatusFilter.value.isEmpty ? null : assetStatusFilter.value,
      );
      filteredAssets.assignAll(list);
    } on ApiException {
      // ignore
    } finally {
      isLoadingAssets.value = false;
    }
  }

  Future<void> loadMaintenance() async {
    if (!canViewMaintenance) return;
    isLoadingMaint.value = true;
    try {
      maintenance.value = await _repo.maintenanceWorkspace(
        status: maintStatusFilter.value.isEmpty ? null : maintStatusFilter.value,
        priority: maintPriorityFilter.value.isEmpty ? null : maintPriorityFilter.value,
      );
    } on ApiException {
      // ignore
    } finally {
      isLoadingMaint.value = false;
    }
  }
}
