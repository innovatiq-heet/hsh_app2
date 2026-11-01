/// A complaint category from `GET /api/complaint-categories`. Ids come from
/// the server; never hard-code them.
class ComplaintCategory {
  final int id;
  final String name;

  const ComplaintCategory({required this.id, required this.name});

  factory ComplaintCategory.fromJson(Map<String, dynamic> json) {
    return ComplaintCategory(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
    );
  }

  /// [all] limited to [ids], in the order of [all]; every category when [ids] is null.
  static List<ComplaintCategory> limitTo(List<ComplaintCategory> all, List<int>? ids) =>
      ids == null ? all : all.where((c) => ids.contains(c.id)).toList();
}

/// An item in a category from `GET /api/complaint-items?categoryId=`.
class ComplaintItem {
  final int id;
  final int categoryId;
  final String name;
  final String code;

  const ComplaintItem({
    required this.id,
    required this.categoryId,
    required this.name,
    this.code = '',
  });

  factory ComplaintItem.fromJson(Map<String, dynamic> json) {
    return ComplaintItem(
      id: (json['id'] as num).toInt(),
      categoryId: ((json['categoryId'] ?? json['category_id']) as num).toInt(),
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
    );
  }
}
