import '../../../enums/user_role.dart';

/// A number-login staff account from Admin → Manage Users
/// (`/api/admin/users`). [role] is the raw API value, e.g. `complain-solver`.
class StaffUser {
  final int id;
  final String name;
  final String phoneNumber;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  const StaffUser({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.role,
    required this.isActive,
    this.createdAt,
  });

  String get roleLabel => roleLabelOf(role);

  /// "complain-solver" → "Complaint Solver"; unknown values are shown as-is.
  static String roleLabelOf(String role) {
    final parsed = UserRoleX.fromApi(role);
    return parsed == UserRole.unknown ? role : parsed.label;
  }

  StaffUser copyWith({bool? isActive}) => StaffUser(
        id: id,
        name: name,
        phoneNumber: phoneNumber,
        role: role,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    final active = json['is_active'];
    return StaffUser(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      phoneNumber: (json['phone_number'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      isActive: active == true || active == 1,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}

/// `GET /api/admin/users`: the users plus the roles the form may offer.
class StaffUserList {
  final List<StaffUser> users;
  final List<String> roles;

  const StaffUserList({required this.users, required this.roles});
}
