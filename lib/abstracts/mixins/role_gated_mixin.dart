import '../../common_enums/user_role.dart';

/// Screens/shells shared across staff/warden/admin (laundry, complaints,
/// operator) mix this in to gate sections by the current session role
/// rather than assuming one-role-one-shell.
mixin RoleGatedMixin {
  bool isAllowed(UserRole current, Set<UserRole> allowed) =>
      allowed.contains(current);
}
