import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';

/// Amenities home: Dashboard, Inventory (search, filters, paging) and
/// Locations. Admins and wardens only.
class AmenitiesHomeController extends GetxController with LoadStateMixin {
  AmenitiesHomeController({AmenitiesRepository? repository, this.searchDebounce = const Duration(milliseconds: 300)})
      : repo = repository ?? AmenitiesRepository();

  final AmenitiesRepository repo;
  final Duration searchDebounce;

  static const pageSize = 50;

  final accessDenied = false.obs;
  final tab = 0.obs; // 0 dashboard, 1 inventory, 2 locations

  // Dashboard
  final dashboard = Rxn<AmenitiesDashboard>();

  // Inventory
  final searchController = TextEditingController();
  final query = AssetQuery.empty.obs;
  final assets = <AmenityAsset>[].obs;
  final total = 0.obs;
  final isInventoryLoading = false.obs;
  final isLoadingMore = false.obs;
  final inventoryError = RxnString();
  final bulkTypes = <AmenityType>[].obs;

  // Setup data for filters and forms
  final categories = <AmenityCategory>[].obs;
  final types = <AmenityType>[].obs;

  // Locations
  final locations = <AmenityLocation>[].obs;
  final isLocationsLoading = false.obs;
  final locationsError = RxnString();

  Timer? _debounce;
  int _inventorySeq = 0;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_onSearchChanged);
    _start();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    searchController.dispose();
    super.onClose();
  }

  /// Admins and wardens only; anyone else is sent back before any request.
  Future<bool> ensureOperator() async {
    final role = Get.isRegistered<SessionStore>() ? await Get.find<SessionStore>().role : UserRole.unknown;
    if (role.canOperate) return true;
    accessDenied.value = true;
    isLoading.value = false;
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) nav.pop();
    AppSnackbar.error('Access Denied', 'Amenities are managed by hostel administrators and wardens.');
    return false;
  }

  Future<void> _start() async {
    if (!await ensureOperator()) return;
    await load();
  }

  /// Dashboard plus the categories and types the filters use.
  Future<void> load({bool showLoading = true}) => guard(() async {
        dashboard.value = await repo.dashboard();
        await refreshSetup();
      }, showLoading: showLoading);

  Future<void> refreshSetup() async {
    try {
      final results = await Future.wait([repo.categories(), repo.types()]);
      categories.assignAll(results[0] as List<AmenityCategory>);
      types.assignAll(results[1] as List<AmenityType>);
    } catch (_) {
      // Filters fall back to free search; the screens show their own errors.
    }
  }

  // ------------------------------------------------------------------ tabs

  void openTab(int i) {
    tab.value = i;
    if (i == 1 && assets.isEmpty && !isInventoryLoading.value) loadInventory();
    if (i == 2 && locations.isEmpty && !isLocationsLoading.value) loadLocations();
  }

  /// A dashboard card or category row: Inventory with that filter.
  void drillDown(AssetQuery filter) {
    searchController.text = '';
    query.value = filter;
    tab.value = 1;
    loadInventory();
  }

  // ------------------------------------------------------------- inventory

  void _onSearchChanged() {
    if ((query.value.search ?? '') == searchController.text) return;
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      query.value = query.value.copyWith(search: searchController.text);
      loadInventory();
    });
  }

  void setFilters(AssetQuery q) {
    query.value = AssetQuery(
      search: searchController.text,
      categoryId: q.categoryId,
      typeId: q.typeId,
      status: q.status,
      condition: q.condition,
      placement: q.placement,
      locationId: q.locationId,
      room: q.room,
      warranty: q.warranty,
      maintenance: q.maintenance,
      installedFrom: q.installedFrom,
      installedTo: q.installedTo,
      sort: q.sort,
    );
    loadInventory();
  }

  void clearFilters() => setFilters(AssetQuery.empty);

  /// First page of assets for the current filters, plus the bulk types that
  /// match (they have no individual assets).
  Future<void> loadInventory() async {
    final seq = ++_inventorySeq;
    isInventoryLoading.value = true;
    inventoryError.value = null;
    try {
      final page = await repo.assets(query.value, limit: pageSize);
      if (seq != _inventorySeq) return;
      assets.assignAll(page.items);
      total.value = page.total;
      _filterBulkTypes();
    } on ApiException catch (e) {
      if (seq == _inventorySeq) inventoryError.value = e.message;
    } catch (_) {
      if (seq == _inventorySeq) inventoryError.value = "Couldn't load the inventory.";
    } finally {
      if (seq == _inventorySeq) isInventoryLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || isInventoryLoading.value || assets.length >= total.value) return;
    isLoadingMore.value = true;
    final seq = _inventorySeq;
    try {
      final page = await repo.assets(query.value, limit: pageSize, offset: assets.length);
      if (seq == _inventorySeq) assets.addAll(page.items);
    } catch (_) {
      AppSnackbar.error('Not Loaded', "Couldn't load more items.");
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Bulk types that fit the filters: only category / type / search apply;
  /// asset-only filters (status, warranty, …) hide them.
  void _filterBulkTypes() {
    final q = query.value;
    final assetOnly = q.status != null ||
        q.condition != null ||
        q.placement != null ||
        q.warranty != null ||
        q.maintenance != null ||
        q.installedFrom != null ||
        q.installedTo != null ||
        q.locationId != null ||
        (q.room ?? '').isNotEmpty;
    if (assetOnly) {
      bulkTypes.clear();
      return;
    }
    final s = (q.search ?? '').trim().toLowerCase();
    bulkTypes.assignAll(types.where((t) =>
        t.isBulk &&
        t.isActive &&
        (q.categoryId == null || t.categoryId == q.categoryId) &&
        (q.typeId == null || t.id == q.typeId) &&
        (s.isEmpty || t.name.toLowerCase().contains(s) || (t.categoryName ?? '').toLowerCase().contains(s))));
  }

  /// Chips for the active filters, each with how to remove it.
  List<({String label, AssetQuery without})> get filterChips {
    final q = query.value;
    String catName(int id) => categories.firstWhereOrNull((c) => c.id == id)?.name ?? 'Category';
    String typeName(int id) => types.firstWhereOrNull((t) => t.id == id)?.name ?? 'Type';
    return [
      if (q.categoryId != null) (label: catName(q.categoryId!), without: q.copyWith(clearCategory: true)),
      if (q.typeId != null) (label: typeName(q.typeId!), without: q.copyWith(clearType: true)),
      if (q.status != null) (label: q.status!.api.replaceAll('_', ' '), without: q.copyWith(clearStatus: true)),
      if (q.condition != null) (label: 'Condition: ${q.condition!.api}', without: q.copyWith(clearCondition: true)),
      if (q.placement != null) (label: q.placement!.api.replaceAll('_', ' '), without: q.copyWith(clearPlacement: true)),
      if (q.locationId != null)
        (
          label: locations.expand((l) => l.flatten()).where((l) => l.id == q.locationId).firstOrNull?.path ?? 'Location',
          without: q.copyWith(clearLocation: true),
        ),
      if ((q.room ?? '').isNotEmpty) (label: 'Room ${q.room}', without: q.copyWith(clearRoom: true)),
      if (q.warranty != null) (label: 'Warranty: ${q.warranty}', without: q.copyWith(clearWarranty: true)),
      if (q.maintenance != null) (label: 'Maintenance: ${q.maintenance}', without: q.copyWith(clearMaintenance: true)),
    ];
  }

  // -------------------------------------------------------------- locations

  Future<void> loadLocations() async {
    isLocationsLoading.value = true;
    locationsError.value = null;
    try {
      locations.assignAll(await repo.locations());
    } on ApiException catch (e) {
      locationsError.value = e.message;
    } catch (_) {
      locationsError.value = "Couldn't load the locations.";
    } finally {
      isLocationsLoading.value = false;
    }
  }

  /// Refresh whatever the screen shows after a change.
  Future<void> refreshAll() async {
    await load(showLoading: false);
    if (tab.value == 1 || assets.isNotEmpty) await loadInventory();
    if (locations.isNotEmpty) await loadLocations();
  }
}
