import '../../../enums/user_role.dart';
import '../../../models/auth/user_session.dart';

/// Shape of the JWT-derived session the API returns on login/register/session-check:
/// { id, email, role, token }.
class AuthSessionResponse {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String token;
  final String phone;
  final String studentCode;
  final String room;

  const AuthSessionResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
    this.phone = '',
    this.studentCode = '',
    this.room = '',
  });

  /// True if user is an alumni / former resident (e.g. room is N/A, empty, or ID is 345).
  bool get isAlumni =>
      (role == UserRole.student || role == UserRole.leader) &&
      UserSession.isAlumniRoomOrId(
        room: room,
        studentCode: studentCode,
        id: id,
      );

  /// [json] is the API's `user` object (e.g. `data.user` from the login/me
  /// response) — the backend sends `id` as an integer, so it's coerced to a
  /// string here since the rest of the app treats ids as strings.
  factory AuthSessionResponse.fromJson(
    Map<String, dynamic> json, {
    String? token,
  }) {
    final rawId = json['id'] ?? json['student_id'];
    return AuthSessionResponse(
      id: rawId == null ? '' : rawId.toString(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRoleX.fromApi(json['role'] as String?),
      token: token ?? '',
      phone: json['phone']?.toString() ?? json['phone_number']?.toString() ?? '',
      studentCode: json['student_code']?.toString() ??
          json['studentCode']?.toString() ??
          json['bank_code']?.toString() ??
          json['bankCode']?.toString() ??
          '',
      room: json['room']?.toString() ?? json['room_number']?.toString() ?? '',
    );
  }
}
