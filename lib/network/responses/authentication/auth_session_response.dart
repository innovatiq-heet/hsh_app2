import '../../../common_enums/user_role.dart';

/// Shape of the JWT-derived session the API returns on login/register/session-check:
/// { id, email, role, token }.
class AuthSessionResponse {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String token;
  final String? studentCode;
  final String? room;

  const AuthSessionResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
    this.studentCode,
    this.room,
  });

  /// [json] is the API's `user` object (e.g. `data.user` from the login/me
  /// response) — the backend sends `id` as an integer, so it's coerced to a
  /// string here since the rest of the app treats ids as strings.
  factory AuthSessionResponse.fromJson(
    Map<String, dynamic> json, {
    String? token,
  }) {
    final rawId = json['id'];
    final code = (json['student_code'] ?? json['bank_code'] ?? json['bankCode'] ?? json['studentCode'] ?? json['aadhar'])?.toString();
    final room = (json['room'] ?? json['room_number'] ?? json['roomNo'])?.toString();
    return AuthSessionResponse(
      id: rawId == null ? '' : rawId.toString(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRoleX.fromApi(json['role'] as String?),
      token: token ?? '',
      studentCode: code,
      room: room,
    );
  }
}
