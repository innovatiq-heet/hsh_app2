import '../../../constants/app_config.dart';
import '../../../enums/complaint_status.dart';

/// The student a complaint belongs to. Only solver/admin responses carry it.
class ComplaintStudent {
  final int id;
  final String name;
  final String studentCode;

  const ComplaintStudent({
    required this.id,
    required this.name,
    this.studentCode = '',
  });

  factory ComplaintStudent.fromJson(Map<String, dynamic> json) {
    return ComplaintStudent(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      studentCode: (json['student_code'] ?? '').toString(),
    );
  }
}

/// A room complaint from `/api/complaints` and `/api/admin/complaints`.
class ComplaintResponse {
  final String id;
  final String roomId;
  final int categoryId;
  final String category;
  final int itemId;
  final String item;
  final String itemCode;
  final String? comment;

  /// Server-relative path (`/api/complaints/:id/image`) that needs the
  /// bearer token; `null` when no photo was attached.
  final String? imageUrl;
  final ComplaintStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ComplaintStudent? student;

  const ComplaintResponse({
    required this.id,
    required this.roomId,
    required this.categoryId,
    required this.category,
    required this.itemId,
    required this.item,
    this.itemCode = '',
    this.comment,
    this.imageUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.student,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  bool get hasComment => comment != null && comment!.trim().isNotEmpty;

  /// Absolute URL for the photo. [AppConfig.mediaBaseUrl] is the host
  /// without `/api`, because [imageUrl] already starts with `/api`.
  String? get absoluteImageUrl =>
      hasImage ? '${AppConfig.mediaBaseUrl}$imageUrl' : null;

  factory ComplaintResponse.fromJson(Map<String, dynamic> json) {
    final createdAt = _asDate(json['created_at']) ?? DateTime.now();
    final rawImage = json['image_url']?.toString();
    final rawComment = json['comment']?.toString();
    return ComplaintResponse(
      id: (json['id'] ?? '').toString(),
      roomId: (json['room_id'] ?? '').toString(),
      categoryId: _asInt(json['category_id']),
      category: (json['category'] ?? '').toString(),
      itemId: _asInt(json['item_id']),
      item: (json['item'] ?? '').toString(),
      itemCode: (json['item_code'] ?? '').toString(),
      comment: rawComment == null || rawComment.trim().isEmpty ? null : rawComment,
      imageUrl: rawImage == null || rawImage.isEmpty ? null : rawImage,
      status: ComplaintStatusX.fromApi(json['status']?.toString()),
      createdAt: createdAt,
      updatedAt: _asDate(json['updated_at']) ?? createdAt,
      student: json['student'] is Map
          ? ComplaintStudent.fromJson(Map<String, dynamic>.from(json['student'] as Map))
          : null,
    );
  }
}

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

DateTime? _asDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());
