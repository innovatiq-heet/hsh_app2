enum UserRole { student, admin, warden, staff, complainsolver,attendance, laundry, unknown }

extension UserRoleX on UserRole {
  static UserRole fromApi(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'student':
        return UserRole.student;
      case 'admin':
        return UserRole.admin;
      case 'warden':
        return UserRole.warden;
      case 'staff':
        return UserRole.staff;
      case 'complainsolver':
      case 'complain_solver':
        return UserRole.complainsolver;
      case 'laundry':
      case 'laundary':
        return UserRole.laundry;
      case 'attendance':
        return UserRole.attendance;
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
      case UserRole.laundry:
        return 'Laundry';
      case UserRole.attendance:
        return 'Attendance Operator';
      case UserRole.unknown:
        return 'Unknown';
    }
  }

  /// Laundry recharge/status actions are shared across these operator roles.
  bool get canOperateLaundry =>
      this == UserRole.admin ||
      this == UserRole.warden ||
      this == UserRole.staff ||
      this == UserRole.laundry;

  /// Complaint resolution is shared across these roles.
  bool get canSolveComplaints =>
      this == UserRole.admin ||
      this == UserRole.warden ||
      this == UserRole.complainsolver;

  /// Admission approval, room swap, deposits, sabha scheduling, etc.
  bool get canOperate => this == UserRole.admin || this == UserRole.warden;

  /// Attendance dynamic QR and manual logging.
  bool get canOperateAttendance =>
      this == UserRole.admin ||
      this == UserRole.warden ||
      this == UserRole.attendance;
}
