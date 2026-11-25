import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../../../models/space_amenities/space_amenity_models.dart';
import '../../../utils/image_type.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../base_repository.dart';

class SpaceAmenitiesRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  Future<SpaceOverviewResponse> overview() async {
    try {
      final res = await _dio.get('/space-amenities/overview');
      return SpaceOverviewResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<Map<String, dynamic>> search(String q) async {
    try {
      final res = await _dio.get('/space-amenities/search', queryParameters: {'q': q});
      return _map(res.data);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<Map<String, dynamic>> reports() async {
    try {
      final res = await _dio.get('/space-amenities/reports');
      return _map(res.data);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<FloorDetailsResponse> floorDetails(
    int floorId, {
    String? search,
    String? kind,
    int? spaceTypeId,
    bool hasIssues = false,
  }) async {
    try {
      final res = await _dio.get(
        '/space-amenities/floors/$floorId',
        queryParameters: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (kind != null && kind.isNotEmpty) 'kind': kind,
          'space_type_id': ?spaceTypeId,
          if (hasIssues) 'has_issues': 'true',
        },
      );
      return FloorDetailsResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<SpaceDetailsResponse> createSpace(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post('/space-amenities/spaces', data: body);
      return SpaceDetailsResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<SpaceDetailsResponse> updateSpace(int spaceId, Map<String, dynamic> body) async {
    try {
      final res = await _dio.put('/space-amenities/spaces/$spaceId', data: body);
      return SpaceDetailsResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> archiveSpace(int spaceId) async {
    try {
      await _dio.delete('/space-amenities/spaces/$spaceId');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<SpaceDetailsResponse> spaceDetails(int spaceId) async {
    try {
      final res = await _dio.get('/space-amenities/spaces/$spaceId');
      return SpaceDetailsResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<List<SpaceAssetModel>> listAssets({
    String? status,
    int? floorId,
    int? spaceId,
    int? categoryId,
    String? q,
    bool archived = false,
  }) async {
    try {
      final res = await _dio.get(
        '/space-amenities/assets',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          'floor_id': ?floorId,
          'space_id': ?spaceId,
          'category_id': ?categoryId,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (archived) 'archived': 'true',
        },
      );
      return _list(res.data).map(SpaceAssetModel.fromJson).toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<AssetDetailsResponse> assetByCode(String code) async {
    try {
      final res = await _dio.get('/space-amenities/assets/by-code/${Uri.encodeComponent(code)}');
      return AssetDetailsResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<AssetDetailsResponse> assetDetails(int assetId) async {
    try {
      final res = await _dio.get('/space-amenities/assets/$assetId');
      return AssetDetailsResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<List<SpaceAssetModel>> registerAssetsBulk(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post('/space-amenities/assets/bulk', data: body);
      return _list(res.data).map(SpaceAssetModel.fromJson).toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<AssetDetailsResponse> updateAsset(int assetId, Map<String, dynamic> body) async {
    try {
      final res = await _dio.put('/space-amenities/assets/$assetId', data: body);
      return AssetDetailsResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<AssetDetailsResponse> transferAsset(int assetId, {required int destinationSpaceId, required String reason}) async {
    try {
      final res = await _dio.post(
        '/space-amenities/assets/$assetId/transfer',
        data: {'destination_space_id': destinationSpaceId, 'reason': reason},
      );
      return AssetDetailsResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<Map<String, dynamic>> replaceAsset(int assetId, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post('/space-amenities/assets/$assetId/replace', data: body);
      return _map(res.data);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<AssetDetailsResponse> retireAsset(int assetId, {String? note}) async {
    try {
      final res = await _dio.post(
        '/space-amenities/assets/$assetId/retire',
        data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
      );
      return AssetDetailsResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<String> uploadPhoto(File file) async {
    try {
      final raf = await file.open();
      final bytes = await raf.read(16);
      await raf.close();
      final mime = ImageType.sniffMimeType(bytes);
      if (mime == null) throw const ApiException('Photo must be a JPEG, PNG or WebP image');
      final form = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          file.path,
          filename: 'asset.${mime.split('/').last}',
          contentType: DioMediaType.parse(mime),
        ),
      });
      final res = await _dio.post('/space-amenities/assets/upload-photo', data: form);
      final m = _map(res.data);
      return (m['photo_file'] ?? '').toString();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<MaintenanceWorkspaceResponse> maintenanceWorkspace({
    int? floorId,
    int? spaceId,
    int? categoryId,
    String? status,
    String? priority,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final res = await _dio.get(
        '/space-amenities/maintenance',
        queryParameters: {
          'floor_id': ?floorId,
          'space_id': ?spaceId,
          'category_id': ?categoryId,
          if (status != null && status.isNotEmpty) 'status': status,
          if (priority != null && priority.isNotEmpty) 'priority': priority,
          if (fromDate != null && fromDate.isNotEmpty) 'from_date': fromDate,
          if (toDate != null && toDate.isNotEmpty) 'to_date': toDate,
        },
      );
      return MaintenanceWorkspaceResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<Map<String, dynamic>> submitMaintenanceUpdate(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post('/space-amenities/maintenance/update', data: body);
      return _map(res.data);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<SpaceConfigResponse> config() async {
    try {
      final res = await _dio.get('/space-amenities/config');
      return SpaceConfigResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> saveSpaceType(int? id, Map<String, dynamic> body) async {
    try {
      if (id == null) {
        await _dio.post('/space-amenities/config/space-types', data: body);
      } else {
        await _dio.put('/space-amenities/config/space-types/$id', data: body);
      }
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> saveCategory(int? id, Map<String, dynamic> body) async {
    try {
      if (id == null) {
        await _dio.post('/space-amenities/config/categories', data: body);
      } else {
        await _dio.put('/space-amenities/config/categories/$id', data: body);
      }
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> saveAmenityType(int? id, Map<String, dynamic> body) async {
    try {
      if (id == null) {
        await _dio.post('/space-amenities/config/types', data: body);
      } else {
        await _dio.put('/space-amenities/config/types/$id', data: body);
      }
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> saveSchedule(int? id, Map<String, dynamic> body) async {
    try {
      if (id == null) {
        await _dio.post('/space-amenities/config/schedules', data: body);
      } else {
        await _dio.put('/space-amenities/config/schedules/$id', data: body);
      }
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> saveSettings(Map<String, dynamic> body) async {
    try {
      await _dio.put('/space-amenities/config/settings', data: body);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<StudentMySpaceResponse> studentMySpace() async {
    try {
      final res = await _dio.get('/space-amenities/student/my-space');
      return StudentMySpaceResponse.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Map<String, dynamic> _map(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException('Unexpected server response');
  }

  Iterable<Map<String, dynamic>> _list(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e));
  }
}
