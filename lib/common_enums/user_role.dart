enum UserRole { student, admin, warden, staff, complainsolver, unknown }

extension UserRoleX on UserRole {
  static UserRole fromApi(String? value) {
    switch (value) {
      case 'student':
        return UserRole.student;
      case 'admin':
        return UserRole.admin;
      case 'warden':
        return UserRole.warden;
      case 'staff':
        return UserRole.staff;
      case 'complainsolver':
        return UserRole.complainsolver;
      default:
        return UserRole.unknown;
    }
  }

  String get apiValue => name;

  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.admin:
        return 'Admin';
      case UserRole.warden:
        return 'Warden';
      case UserRole.staff:
        return 'Staff';
      case UserRole.complainsolver:
        return 'Complaint Solver';
      case UserRole.unknown:
        return 'Unknown';
    }
  }

  /// Laundry recharge/status actions are shared across these operator roles.
  bool get canOperateLaundry =>
      this == UserRole.admin ||
      this == UserRole.warden ||
      this == UserRole.staff;

  /// Complaint resolution is shared across these roles.
  bool get canSolveComplaints =>
      this == UserRole.admin ||
      this == UserRole.warden ||
      this == UserRole.complainsolver;

  /// Admission approval, room swap, deposits, sabha scheduling, etc.
  bool get canOperate => this == UserRole.admin || this == UserRole.warden;
}
