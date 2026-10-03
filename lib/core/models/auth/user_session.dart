import '../../enums/user_role.dart';
import '../student_profile/student_profile_model.dart';

/// Clean OOP model representing an authenticated user session.
/// Encapsulates authentication credentials, role, core profile attributes,
/// and optional full student details to eliminate data redundancy.
class UserSession {
  final String token;
  final UserRole role;
  final String id;
  final String name;
  final String email;
  final String phone;
  final String studentCode;
  final String room;
  final StudentProfileModel? studentProfile;

  const UserSession({
    required this.token,
    required this.role,
    this.id = '',
    this.name = '',
    this.email = '',
    this.phone = '',
    this.studentCode = '',
    this.room = '',
    this.studentProfile,
  });

  bool get isAuthenticated => token.isNotEmpty;
  bool get isStudentOrLeader => role.isStudentOrLeader;

  UserSession copyWith({
    String? token,
    UserRole? role,
    String? id,
    String? name,
    String? email,
    String? phone,
    String? studentCode,
    String? room,
    StudentProfileModel? studentProfile,
  }) {
    return UserSession(
      token: token ?? this.token,
      role: role ?? this.role,
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      studentCode: studentCode ?? this.studentCode,
      room: room ?? this.room,
      studentProfile: studentProfile ?? this.studentProfile,
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'role': role.apiValue,
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'student_code': studentCode,
    'room': room,
    if (studentProfile != null) 'student_profile': studentProfile!.toJson(),
  };

  factory UserSession.fromJson(Map<String, dynamic> json) {
    StudentProfileModel? profile;
    if (json['student_profile'] is Map<String, dynamic>) {
      profile = StudentProfileModel.fromJson(
        json['student_profile'] as Map<String, dynamic>,
      );
    }

    return UserSession(
      token: json['token']?.toString() ?? '',
      role: UserRoleX.fromApi(json['role']?.toString()),
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      studentCode: json['student_code']?.toString() ??
          json['studentCode']?.toString() ??
          '',
      room: json['room']?.toString() ?? '',
      studentProfile: profile,
    );
  }
}
