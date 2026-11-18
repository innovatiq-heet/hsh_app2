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
  final bool isAlumniApi;

  const AuthSessionResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
    this.phone = '',
    this.studentCode = '',
    this.room = '',
    this.isAlumniApi = false,
  });

  /// True if user is an alumni / former resident (e.g. room is N/A, empty, or isAlumniApi is true).
  /// Leaders, admins, and staff roles are never alumni.
  bool get isAlumni {
    if (role == UserRole.leader) return false;
    if (role != UserRole.student && role != UserRole.unknown) return false;
    return isAlumniApi ||
        UserSession.isAlumniRoomOrId(
          room: room,
          studentCode: studentCode,
          id: id,
        );
  }

  /// [json] is the API's `user` object (e.g. `data.user` from the login/me
  /// response) — the backend sends `id` as an integer, so it's coerced to a
  /// string here since the rest of the app treats ids as strings.
  factory AuthSessionResponse.fromJson(
    Map<String, dynamic> json, {
    String? token,
    bool? isAlumni,
  }) {
    final rawId = json['id'] ?? json['student_id'];
    final rolesList = (json['roles'] as List?)
            ?.map((e) => e.toString().toLowerCase().trim())
            .toList() ??
        [];
    final isLeaderApi = json['is_leader'] == true ||
        rolesList.contains('leader') ||
        rolesList.contains('wing-leader') ||
        rolesList.contains('wing_leader') ||
        rolesList.contains('floor-leader') ||
        rolesList.contains('floor_leader');
    final role = isLeaderApi ? UserRole.leader : UserRoleX.fromApi(json['role'] as String?);
    final roomVal = json['room']?.toString() ?? json['room_number']?.toString() ?? '';
    final codeVal = json['student_code']?.toString() ??
        json['studentCode']?.toString() ??
        json['bank_code']?.toString() ??
        json['bankCode']?.toString() ??
        json['username']?.toString() ??
        '';
    // Leaders and staff (complain-solver, laundry-man) are never alumni.
    final canBeAlumni = role == UserRole.student || role == UserRole.unknown;
    final explicitAlumni = isAlumni == true ||
        json['is_alumni'] == true ||
        json['role']?.toString().toLowerCase().trim() == 'alumni';
    final isAlum = canBeAlumni &&
        explicitAlumni &&
        !UserSession.isValidHostelRoom(roomVal);

    return AuthSessionResponse(
      id: rawId == null ? '' : rawId.toString(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: role,
      token: token ?? '',
      phone: json['phone']?.toString() ?? json['phone_number']?.toString() ?? '',
      studentCode: codeVal,
      room: isAlum && !UserSession.isValidHostelRoom(roomVal) ? 'N/A' : roomVal,
      isAlumniApi: isAlum,
    );
  }
}
