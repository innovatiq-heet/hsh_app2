import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../../../models/amenities/amenity_models.dart';
import '../../api_client.dart';
import '../base_repository.dart';

/// Filters for the asset list (`GET /amenities/assets`). Only set fields are sent.
class AssetQuery {
  final String? search;
  final int? categoryId;
  final int? typeId;
  final AssetStatus? status;
  final AssetCondition? condition;
  final AssetPlacement? placement;
  final int? locationId;
  final String? room;
  final int? studentId;
  final String? warranty; // expired | expiring | active | none
  final String? maintenance; // due | open
  final String? installedFrom;
  final String? installedTo;
  final String sort;

  const AssetQuery({
    this.search,
    this.categoryId,
    this.typeId,
    this.status,
    this.condition,
    this.placement,
    this.locationId,
    this.room,
    this.studentId,
    this.warranty,
    this.maintenance,
    this.installedFrom,
    this.installedTo,
    this.sort = 'code',
  });

  static const empty = AssetQuery();

  bool get hasFilters =>
      categoryId != null ||
      typeId != null ||
      status != null ||
      condition != null ||
      placement != null ||
      locationId != null ||
      (room ?? '').isNotEmpty ||
      studentId != null ||
      warranty != null ||
      maintenance != null ||
      installedFrom != null ||
      installedTo != null;

  Map<String, dynamic> toQuery() => {
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
        'category_id': ?categoryId,
        'type_id': ?typeId,
        if (status != null) 'status': status!.api,
        if (condition != null) 'condition': condition!.api,
        if (placement != null) 'placement': placement!.api,
        'location_id': ?locationId,
        if ((room ?? '').trim().isNotEmpty) 'room': room!.trim(),
        'student_id': ?studentId,
        'warranty': ?warranty,
        'maintenance': ?maintenance,
        'installed_from': ?installedFrom,
        'installed_to': ?installedTo,
        'sort': sort,
      };

  AssetQuery copyWith({
    String? search,
    int? categoryId,
    int? typeId,
    AssetStatus? status,
    AssetCondition? condition,
    AssetPlacement? placement,
    int? locationId,
    String? room,
    String? warranty,
    String? maintenance,
    bool clearCategory = false,
    bool clearType = false,
    bool clearStatus = false,
    bool clearCondition = false,
    bool clearPlacement = false,
    bool clearLocation = false,
    bool clearRoom = false,
    bool clearWarranty = false,
    bool clearMaintenance = false,
  }) =>
      AssetQuery(
        search: search ?? this.search,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        typeId: clearType ? null : (typeId ?? this.typeId),
        status: clearStatus ? null : (status ?? this.status),
        condition: clearCondition ? null : (condition ?? this.condition),
        placement: clearPlacement ? null : (placement ?? this.placement),
        locationId: clearLocation ? null : (locationId ?? this.locationId),
        room: clearRoom ? null : (room ?? this.room),
        studentId: studentId,
        warranty: clearWarranty ? null : (warranty ?? this.warranty),
        maintenance: clearMaintenance ? null : (maintenance ?? this.maintenance),
        installedFrom: installedFrom,
        installedTo: installedTo,
        sort: sort,
      );
}

/// Who an asset or quantity goes to: a student (numeric `students.id`) or a
/// location. Exactly one.
class AssignTarget {
  final int? studentId;
  final int? locationId;

  const AssignTarget.student(int this.studentId) : locationId = null;
  const AssignTarget.location(int this.locationId) : studentId = null;

  Map<String, dynamic> toJson() => studentId != null ? {'student_id': studentId} : {'location_id': locationId};
}

/// The reply of an assign / transfer: the server may warn (e.g. the student
/// is not an active resident) while still saving.
class AssignResult {
  final String? warning;
  const AssignResult({this.warning});
}

/// `/api/amenities` (Amenities Management). Throws [ApiException] with the
/// server's message. Student ids are numeric `students.id` only.
class AmenitiesRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  static const _base = '/amenities';

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  dynamic _data(Response r) {
    final body = r.data;
    return body is Map ? body['data'] : null;
  }

  Map<String, dynamic> _obj(Response r) {
    final d = _data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(Response r) {
    final d = _data(r);
    final list = d is List ? d : (d is Map ? d['items'] : null);
    return list is List ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
  }

  AssignResult _assignResult(Response r) {
    final body = r.data;
    final warning = body is Map ? (body['warning'] ?? (body['data'] is Map ? body['data']['warning'] : null)) : null;
    return AssignResult(warning: warning?.toString());
  }

  // ---------------------------------------------------------------- dashboard

  Future<AmenitiesDashboard> dashboard() => _run(() async => AmenitiesDashboard.fromJson(_obj(await _dio.get('$_base/dashboard'))));

  // ---------------------------------------------------- categories and types

  Future<List<AmenityCategory>> categories({bool includeInactive = false}) => _run(() async => _list(await _dio.get(
        '$_base/categories',
        queryParameters: {if (includeInactive) 'include_inactive': 1},
      )).map(AmenityCategory.fromJson).toList());

  Future<AmenityCategory> createCategory(Map<String, dynamic> body) =>
      _run(() async => AmenityCategory.fromJson(_obj(await _dio.post('$_base/categories', data: body))));

  /// Partial: only [changes] are sent.
  Future<AmenityCategory> updateCategory(int id, Map<String, dynamic> changes) =>
      _run(() async => AmenityCategory.fromJson(_obj(await _dio.put('$_base/categories/$id', data: changes))));

  Future<List<AmenityType>> types({int? categoryId, bool includeInactive = false}) => _run(() async => _list(await _dio.get(
        '$_base/types',
        queryParameters: {'category_id': ?categoryId, if (includeInactive) 'include_inactive': 1},
      )).map(AmenityType.fromJson).toList());

  Future<AmenityType> type(int id) => _run(() async => AmenityType.fromJson(_obj(await _dio.get('$_base/types/$id'))));

  Future<AmenityType> createType(Map<String, dynamic> body) =>
      _run(() async => AmenityType.fromJson(_obj(await _dio.post('$_base/types', data: body))));

  /// Partial: only [changes] are sent.
  Future<AmenityType> updateType(int id, Map<String, dynamic> changes) =>
      _run(() async => AmenityType.fromJson(_obj(await _dio.put('$_base/types/$id', data: changes))));

  // ---------------------------------------------------------------- locations

  Future<List<AmenityLocation>> locations() =>
      _run(() async => _list(await _dio.get('$_base/locations')).map(AmenityLocation.fromJson).toList());

  Future<AmenityLocation> createLocation(Map<String, dynamic> body) =>
      _run(() async => AmenityLocation.fromJson(_obj(await _dio.post('$_base/locations', data: body))));

  Future<AmenityLocation> updateLocation(int id, Map<String, dynamic> changes) =>
      _run(() async => AmenityLocation.fromJson(_obj(await _dio.put('$_base/locations/$id', data: changes))));

  Future<LocationAmenities> locationAmenities(int id) =>
      _run(() async => LocationAmenities.fromJson(_obj(await _dio.get('$_base/locations/$id/amenities'))));

  // ------------------------------------------------------------------ assets

  Future<Paged<AmenityAsset>> assets(AssetQuery query, {int limit = 50, int offset = 0}) => _run(() async {
        final r = await _dio.get('$_base/assets', queryParameters: {...query.toQuery(), 'limit': limit, 'offset': offset});
        return Paged.fromJson(_obj(r), AmenityAsset.fromJson);
      });

  Future<AmenityAsset> asset(int id) => _run(() async => AmenityAsset.fromJson(_obj(await _dio.get('$_base/assets/$id'))));

  Future<AmenityAsset> assetByCode(String code) => _run(
      () async => AmenityAsset.fromJson(_obj(await _dio.get('$_base/assets/by-code/${Uri.encodeComponent(code)}'))));

  /// Creates `count` assets of one type with the same details.
  Future<List<AmenityAsset>> createAssets(Map<String, dynamic> body) =>
      _run(() async => _list(await _dio.post('$_base/assets', data: body)).map(AmenityAsset.fromJson).toList());

  /// Partial: only [changes] are sent.
  Future<AmenityAsset> updateAsset(int id, Map<String, dynamic> changes) =>
      _run(() async => AmenityAsset.fromJson(_obj(await _dio.put('$_base/assets/$id', data: changes))));

  Future<void> setStatus(int id, AssetStatus status, {AssetCondition? condition, String? note}) => _run(() async {
        await _dio.post('$_base/assets/$id/status', data: {
          'status': status.api,
          if (condition != null) 'condition': condition.api,
          if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        });
      });

  Future<AssignResult> assignAsset(int id, AssignTarget to, {AssetCondition? condition, String? expectedReturnDate, String? note}) =>
      _run(() async => _assignResult(await _dio.post('$_base/assets/$id/assign', data: {
            ...to.toJson(),
            if (condition != null) 'condition': condition.api,
            'expected_return_date': ?expectedReturnDate,
            if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
          })));

  Future<AssignResult> transferAsset(int id, AssignTarget to, {AssetCondition? condition, String? note}) =>
      _run(() async => _assignResult(await _dio.post('$_base/assets/$id/transfer', data: {
            ...to.toJson(),
            if (condition != null) 'condition': condition.api,
            if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
          })));

  Future<void> returnAsset(int id, {AssetCondition? condition, String? note}) => _run(() async {
        await _dio.post('$_base/assets/$id/return', data: {
          if (condition != null) 'condition': condition.api,
          if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        });
      });

  Future<Paged<AmenityEvent>> assetEvents(int id, {int limit = 50, int offset = 0}) => _run(() async => Paged.fromJson(
      _obj(await _dio.get('$_base/assets/$id/events', queryParameters: {'limit': limit, 'offset': offset})), AmenityEvent.fromJson));

  Future<List<AmenityAssignment>> assetAssignments(int id) =>
      _run(() async => _list(await _dio.get('$_base/assets/$id/assignments')).map(AmenityAssignment.fromJson).toList());

  // -------------------------------------------------------------------- bulk

  Future<void> addStock(int typeId, {required int quantity, String? unitCost, String? purchaseDate, String? vendor, String? note}) =>
      _run(() async {
        await _dio.post('$_base/types/$typeId/stock', data: {
          'quantity': quantity,
          'unit_cost': ?unitCost,
          'purchase_date': ?purchaseDate,
          'vendor': ?vendor,
          if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        });
      });

  Future<AssignResult> assignBulk(int typeId, AssignTarget to,
          {required int quantity, AssetCondition? condition, String? expectedReturnDate, String? note}) =>
      _run(() async => _assignResult(await _dio.post('$_base/types/$typeId/assign', data: {
            ...to.toJson(),
            'quantity': quantity,
            if (condition != null) 'condition': condition.api,
            'expected_return_date': ?expectedReturnDate,
            if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
          })));

  Future<void> moveBulk(int typeId, {required int quantity, required BulkState from, required BulkState to, String? note}) =>
      _run(() async {
        await _dio.post('$_base/types/$typeId/move', data: {
          'quantity': quantity,
          'from': from.api,
          'to': to.api,
          if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        });
      });

  /// Closes (or, for bulk, partly closes) an assignment.
  Future<void> returnAssignment(int assignmentId, {int? quantity, AssetCondition? condition, String? note, BulkState? toState}) =>
      _run(() async {
        await _dio.post('$_base/assignments/$assignmentId/return', data: {
          'quantity': ?quantity,
          if (condition != null) 'condition': condition.api,
          if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
          if (toState != null) 'to_state': toState.api,
        });
      });

  Future<List<AmenityAssignment>> typeAssignments(int typeId, {bool openOnly = false}) => _run(() async => _list(await _dio.get(
        '$_base/types/$typeId/assignments',
        queryParameters: {if (openOnly) 'open': 1},
      )).map(AmenityAssignment.fromJson).toList());

  // --------------------------------------------------------- students, audit

  Future<StudentAmenities> studentAmenities(int studentId) =>
      _run(() async => StudentAmenities.fromJson(_obj(await _dio.get('$_base/students/$studentId/amenities'))));

  Future<Paged<AmenityEvent>> activity({int? assetId, int? typeId, int limit = 50, int offset = 0}) => _run(() async => Paged.fromJson(
      _obj(await _dio.get('$_base/activity',
          queryParameters: {'asset_id': ?assetId, 'type_id': ?typeId, 'limit': limit, 'offset': offset})),
      AmenityEvent.fromJson));
}
