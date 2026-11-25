import 'dart:io';

/// Body of `POST /api/complaints`. [roomId] must be the student's own room
/// (from `/auth/me`); the server answers 403 for any other room. The server
/// sets `status` itself and rejects `image_url`, so neither is sent.
class SubmitComplaintRequest {
  final String roomId;
  final int categoryId;
  final int itemId;
  final String? comment;
  final File? image;
  final int? spaceId;
  final int? assetId;
  final String? priority;

  const SubmitComplaintRequest({
    required this.roomId,
    required this.categoryId,
    required this.itemId,
    this.comment,
    this.image,
    this.spaceId,
    this.assetId,
    this.priority,
  });

  Map<String, dynamic> toJson() => {
        'room_id': roomId,
        'category_id': categoryId,
        'item_id': itemId,
        if (comment != null && comment!.trim().isNotEmpty)
          'comment': comment!.trim(),
        if (spaceId != null) 'space_id': spaceId,
        if (assetId != null) 'asset_id': assetId,
        if (priority != null && priority!.isNotEmpty) 'priority': priority,
      };
}
