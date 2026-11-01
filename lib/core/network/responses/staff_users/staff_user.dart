import '../../../enums/user_role.dart';
import '../complaints/complaint_catalog.dart';

/// A number-login staff account from Admin → Manage Users
/// (`/api/admin/users`). [role] is the raw API value, e.g. `complain-solver`.
class StaffUser {
  /// The role whose complaints can be limited to some categories.
  static const complaintSolverRole = 'complain-solver';

  final int id;
  final String name;
  final String phoneNumber;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  /// Complaint categories a complaint solver works on; `null` means all of
  /// them (and is always `null` for other roles).
  final List<ComplaintCategory>? categories;

  const StaffUser({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.categories,
  });

  String get roleLabel => roleLabelOf(role);

  bool get isComplaintSolver => role == complaintSolverRole;

  /// Ids of [categories]; `null` means all categories.
  List<int>? get categoryIds => categories?.map((c) => c.id).toList();

  /// "All categories", "Electrical, Carpentry" or "No categories".
  String get categoriesLabel {
    final list = categories;
    if (list == null) return 'All categories';
    if (list.isEmpty) return 'No categories';
    return list.map((c) => c.name).join(', ');
  }

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
        categories: categories,
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
      categories: _categoriesFromJson(json),
    );
  }

  /// `categories` ([{id, name}]) when present, else bare `category_ids`; null = all.
  static List<ComplaintCategory>? _categoriesFromJson(Map<String, dynamic> json) {
    final categories = json['categories'];
    if (categories is List) {
      return categories
          .whereType<Map>()
          .map((e) => ComplaintCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final ids = json['category_ids'];
    if (ids is List) {
      return ids.whereType<num>().map((id) => ComplaintCategory(id: id.toInt(), name: '#$id')).toList();
    }
    return null;
  }
}

/// `GET /api/admin/users`: the users plus the roles the form may offer.
class StaffUserList {
  final List<StaffUser> users;
  final List<String> roles;

  const StaffUserList({required this.users, required this.roles});
}
