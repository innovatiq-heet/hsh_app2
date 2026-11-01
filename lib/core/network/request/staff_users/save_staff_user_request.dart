/// Body for creating (`POST /api/admin/users`, all of name/phone/role) or
/// editing (`PUT /api/admin/users/:id`, only the fields being changed) a
/// staff user. Null fields are left out of the JSON.
class SaveStaffUserRequest {
  final String? name;
  final String? phoneNumber;
  final String? role;
  final bool? isActive;

  /// Complaint categories of a complaint solver; `null` means all of them.
  /// Sent only when [sendCategoryIds] is true, because `null` is a value here.
  final List<int>? categoryIds;
  final bool sendCategoryIds;

  const SaveStaffUserRequest({
    this.name,
    this.phoneNumber,
    this.role,
    this.isActive,
    this.categoryIds,
    this.sendCategoryIds = false,
  });

  bool get isEmpty =>
      name == null &&
      phoneNumber == null &&
      role == null &&
      isActive == null &&
      !sendCategoryIds;

  Map<String, dynamic> toJson() => {
        'name': ?name,
        'phone_number': ?phoneNumber,
        'role': ?role,
        'is_active': ?isActive,
        if (sendCategoryIds) 'category_ids': categoryIds,
      };
}
