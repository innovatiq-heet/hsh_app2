import '../../../common_enums/user_role.dart';

/// Shape of the JWT-derived session the API returns on login/register/session-check:
/// { id, email, role, token }.
class AuthSessionResponse {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String token;

  const AuthSessionResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
  });
}
