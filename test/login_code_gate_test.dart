import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/network/api_exception.dart';
import 'package:hsh_app2/core/network/repository/authentication/auth_repository.dart';
import 'package:hsh_app2/core/network/request/authentication/login_request.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// A student's/leader's second login onward needs a warden-issued code
/// (docs/PARENT_CONTROL_DOCS.md §5.7a): the backend flags this instead of
/// returning a token, and the client must tell that apart from a plain
/// wrong-credentials failure rather than showing a confusing error.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;
  late AuthRepository repo;

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    Get.put(SessionStore());
    api = FakeApi()..install();
    repo = AuthRepository();
  });

  tearDown(Get.reset);

  test('LoginRequest omits code when not given, sends it trimmed when given', () {
    expect(const LoginRequest(studentId: '0345').toJson().containsKey('code'), isFalse);
    expect(
      const LoginRequest(studentId: '0345', code: '  ').toJson().containsKey('code'),
      isFalse,
      reason: 'a blank code is the same as none',
    );
    expect(
      const LoginRequest(studentId: '0345', code: ' 483920 ').toJson()['code'],
      '483920',
    );
  });

  test(
    'LoginRequest always identifies this app so the backend never gates the attendance web portal',
    () {
      expect(
        const LoginRequest(studentId: '0345').toJson()['client'],
        'hsh_app2_mobile',
      );
    },
  );

  test('a 200 response with requires_code throws ApiException(statusCode: 428)', () async {
    api.on('POST /auth/login', {
      'requires_code': true,
      'message': 'Enter the code your warden gave you.',
    });

    await expectLater(
      repo.login(const LoginRequest(studentId: '0345', password: 'p')),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 428)
          .having((e) => e.message, 'message', 'Enter the code your warden gave you.')),
    );
  });

  test('a non-2xx requires_code response also surfaces as statusCode 428', () async {
    api.on(
      'POST /auth/login',
      {'requires_code': true, 'message': 'Code required'},
      status: 428,
    );

    await expectLater(
      repo.login(const LoginRequest(studentId: '0345', password: 'p')),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 428)),
    );
  });

  test('sending the code goes through like any other login field', () async {
    api.on('POST /auth/login', {
      'success': true,
      'token': 'tok',
      'user': {'role': 'student', 'id': 7, 'name': 'Asha'},
      'data': {
        'token': 'tok',
        'user': {'role': 'student', 'id': 7, 'name': 'Asha'},
      },
    });

    final session = await repo.login(
      const LoginRequest(studentId: '0345', password: 'p', code: '483920'),
    );

    expect(session.token, 'tok');
    expect(api.last('POST /auth/login').data['code'], '483920');
  });

  test('a plain wrong-credentials failure is not mistaken for a code prompt', () async {
    api.on('POST /auth/login', {'message': 'Invalid credentials'}, status: 401);

    await expectLater(
      repo.login(const LoginRequest(studentId: '0345', password: 'wrong')),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });
}
