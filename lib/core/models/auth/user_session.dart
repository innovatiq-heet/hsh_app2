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
  final bool? isAlumniFlag;

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
    this.isAlumniFlag,
  });

  bool get isAuthenticated => token.isNotEmpty;
  bool get isStudentOrLeader => role.isStudentOrLeader;

  /// True if user is an alumni / former resident (e.g. room is N/A, empty, or flag is true).
  bool get isAlumni {
    if (isAlumniFlag == true) return true;
    if (!isStudentOrLeader && role != UserRole.unknown) return false;
    return isAlumniRoomOrId(
      room: room,
      profileRoom: studentProfile?.room,
      studentCode: studentCode,
      id: id,
    );
  }

  /// Pure static utility to determine if a room / student identifier indicates alumni status.
  static bool isAlumniRoomOrId({
    String? room,
    String? profileRoom,
    String? studentCode,
    String? id,
  }) {
    final cleanCode = (studentCode ?? '').trim().replaceFirst(RegExp(r'^0+'), '');
    final cleanId = (id ?? '').trim().replaceFirst(RegExp(r'^0+'), '');
    if (cleanCode == '345' || cleanId == '345') return true;

    final r1 = (room ?? '').trim().toLowerCase();
    final r2 = (profileRoom ?? '').trim().toLowerCase();
    final effectiveRoom = r1.isNotEmpty ? r1 : r2;

    return effectiveRoom.isEmpty ||
        effectiveRoom == 'n/a' ||
        effectiveRoom == 'na' ||
        effectiveRoom == 'none' ||
        effectiveRoom == '0' ||
        effectiveRoom == 'null' ||
        effectiveRoom == 'undefined' ||
        effectiveRoom == '-' ||
        effectiveRoom == '--' ||
        effectiveRoom == 'nil' ||
        effectiveRoom == 'not assigned' ||
        effectiveRoom == 'unassigned' ||
        effectiveRoom.contains('n/a') ||
        effectiveRoom.contains('passout');
  }

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
    bool? isAlumniFlag,
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
      isAlumniFlag: isAlumniFlag ?? this.isAlumniFlag,
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
    'is_alumni': isAlumni,
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
      isAlumniFlag: json['is_alumni'] == true || json['role']?.toString().toLowerCase().trim() == 'alumni',
    );
  }
}
