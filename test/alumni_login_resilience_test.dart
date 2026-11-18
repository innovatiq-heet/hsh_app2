import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/enums/user_role.dart';
import 'package:hsh_app2/core/models/auth/user_session.dart';
import 'package:hsh_app2/core/models/student_profile/student_profile_model.dart';
import 'package:hsh_app2/core/network/api_client.dart';
import 'package:hsh_app2/core/network/repository/student_profile/student_profile_repository.dart';
import 'package:hsh_app2/core/network/responses/authentication/auth_session_response.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.put(SessionStore());
  });

  tearDown(() {
    Get.reset();
  });

  test('UserRoleX.fromApi recognizes alumni role as student', () {
    expect(UserRoleX.fromApi('alumni'), UserRole.student);
    expect(UserRoleX.fromApi('ALUMNI'), UserRole.student);
  });

  test('StudentProfileModel.fallback creates a valid profile from basic details', () {
    final profile = StudentProfileModel.fallback(
      name: 'KRUTARTH ARUNSINH SOLANKI',
      bankCode: '0345',
      phone: '7984907753',
      email: 'viveksolanki2355@gmail.com',
      room: '',
    );

    expect(profile.firstName, 'KRUTARTH');
    expect(profile.lastName, 'ARUNSINH SOLANKI');
    expect(profile.fullName, 'KRUTARTH ARUNSINH SOLANKI');
    expect(profile.bankCode, '0345');
    expect(profile.phone, '7984907753');
    expect(profile.email, 'viveksolanki2355@gmail.com');
    expect(profile.room, '');
  });

  test('StudentProfileRepository.fetchProfile handles 401 inactive backend without throwing', () async {
    final api = ApiClient.create();
    api.dio.interceptors.insert(
      0,
      dio.InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/students/')) {
            // Emulate backend returning 401 for inactive/alumni student
            return handler.resolve(
              dio.Response(
                requestOptions: options,
                statusCode: 401,
                data: {
                  'success': false,
                  'message': 'Student account not found or inactive.',
                },
              ),
            );
          }
          return handler.next(options);
        },
      ),
    );
    Get.put(api);

    final repo = StudentProfileRepository();
    final profile = await repo.fetchProfile(
      name: 'KRUTARTH ARUNSINH SOLANKI',
      studentCode: '0345',
      phone: '7984907753',
      email: 'viveksolanki2355@gmail.com',
    );

    expect(profile.fullName, 'KRUTARTH ARUNSINH SOLANKI');
    expect(profile.bankCode, '0345');
    expect(profile.phone, '7984907753');
    expect(profile.email, 'viveksolanki2355@gmail.com');
  });

  test('UserSession.isAlumni detects ID 345, empty room, or N/A room as Alumni', () {
    // 1. Student Krutarth with ID 0345 / 345
    final krutarthSession = UserSession(
      token: 'jwt_token',
      role: UserRole.student,
      id: '177211',
      studentCode: '0345',
      name: 'KRUTARTH ARUNSINH SOLANKI',
      room: '',
    );
    expect(krutarthSession.isAlumni, isTrue);

    // 2. Student with room explicitly set to N/A or na
    final naSession = UserSession(
      token: 'jwt_token',
      role: UserRole.student,
      id: '888',
      studentCode: '0888',
      name: 'Alumni Student',
      room: 'N/A',
    );
    expect(naSession.isAlumni, isTrue);

    final lowercaseNaSession = UserSession(
      token: 'jwt_token',
      role: UserRole.student,
      studentCode: '0999',
      room: 'n/a',
    );
    expect(lowercaseNaSession.isAlumni, isTrue);

    final noneRoomSession = UserSession(
      token: 'jwt_token',
      role: UserRole.student,
      studentCode: '0777',
      room: 'none',
    );
    expect(noneRoomSession.isAlumni, isTrue);

    final zeroRoomSession = UserSession(
      token: 'jwt_token',
      role: UserRole.student,
      studentCode: '0666',
      room: '0',
    );
    expect(zeroRoomSession.isAlumni, isTrue);

    // 3. Regular active student with assigned room
    final activeHostelStudent = UserSession(
      token: 'jwt_token',
      role: UserRole.student,
      id: '9999',
      studentCode: '1043',
      name: 'Active Resident',
      room: '204',
    );
    expect(activeHostelStudent.isAlumni, isFalse);

    // 4. Admin or staff is never considered alumni
    final adminSession = UserSession(
      token: 'jwt_token',
      role: UserRole.admin,
      id: '1',
      name: 'Warden Admin',
      room: '',
    );
    expect(adminSession.isAlumni, isFalse);
  });

  test('SessionStore.saveSession preserves alumni status and marks session as alumni', () async {
    final store = Get.find<SessionStore>();
    await store.saveSession(
      token: 'test_token',
      role: UserRole.student,
      name: 'KRUTARTH ARUNSINH SOLANKI',
      email: 'krutarth@test.com',
      studentCode: '0345',
      room: '',
      isAlumni: true,
    );

    expect(store.isAlumni, isTrue);
    final savedSession = await store.userSession;
    expect(savedSession?.isAlumni, isTrue);
  });

  test('Leader login without room (e.g. floor_leaders table) is never treated as Alumni', () async {
    final response = AuthSessionResponse.fromJson(
      {
        'role': 'LEADER',
        'id': 12,
        'username': '0353',
        'name': 'Anand Kamleshbhai Patel',
        'floor_id': 9,
      },
      token: 'leader_jwt',
    );

    expect(response.role, UserRole.leader);
    expect(response.studentCode, '0353');
    expect(response.isAlumni, isFalse);
    expect(response.isAlumniApi, isFalse);

    final store = Get.find<SessionStore>();
    await store.saveSession(
      token: response.token,
      role: response.role,
      name: response.name,
      email: 'anandky2@gmail.com',
      studentCode: '0353',
      room: '',
      isAlumni: false,
    );

    expect(store.isAlumni, isFalse);
    final saved = await store.userSession;
    expect(saved?.role, UserRole.leader);
    expect(saved?.isAlumni, isFalse);
  });

  test('Active student (0353) with valid profile room 904 is not treated as Alumni even if session room is empty or N/A', () async {
    expect(
      UserSession.isAlumniRoomOrId(
        room: 'N/A',
        profileRoom: '904',
        studentCode: '0353',
        id: '269',
      ),
      isFalse,
    );

    final profile = StudentProfileModel.fallback(
      name: 'Anand Kamleshbhai Patel',
      bankCode: '0353',
      phone: '7046228548',
      email: 'anandky2@gmail.com',
      room: '904',
    );

    final store = Get.find<SessionStore>();
    await store.saveSession(
      token: 'student_jwt',
      role: UserRole.student,
      name: 'Anand Kamleshbhai Patel',
      email: 'anandky2@gmail.com',
      studentCode: '0353',
      room: 'N/A',
      studentProfile: profile,
      isAlumni: false,
    );

    expect(store.isAlumni, isFalse);
    expect(store.currentSession?.room, '904');
  });
}
