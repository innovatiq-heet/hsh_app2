import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/enums/user_role.dart';
import 'package:hsh_app2/core/models/student_profile/student_profile_model.dart';
import 'package:hsh_app2/core/network/api_client.dart';
import 'package:hsh_app2/core/network/repository/student_profile/student_profile_repository.dart';
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
}
