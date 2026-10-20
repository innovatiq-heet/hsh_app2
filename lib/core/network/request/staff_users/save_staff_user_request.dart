/// Body for creating (`POST /api/admin/users`, all of name/phone/role) or
/// editing (`PUT /api/admin/users/:id`, only the fields being changed) a
/// staff user. Null fields are left out of the JSON.
class SaveStaffUserRequest {
  final String? name;
  final String? phoneNumber;
  final String? role;
  final bool? isActive;

  const SaveStaffUserRequest({
    this.name,
    this.phoneNumber,
    this.role,
    this.isActive,
  });

  bool get isEmpty =>
      name == null && phoneNumber == null && role == null && isActive == null;

  Map<String, dynamic> toJson() => {
        'name': ?name,
        'phone_number': ?phoneNumber,
        'role': ?role,
        'is_active': ?isActive,
      };
}
