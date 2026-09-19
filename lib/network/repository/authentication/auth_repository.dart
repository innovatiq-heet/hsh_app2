import '../../../common_enums/user_role.dart';
import '../../../constants/app_config.dart';
import '../../request/authentication/login_request.dart';
import '../../responses/authentication/auth_session_response.dart';

/// Mocked for now — every method matches the shape a real Dio call will
/// return, so swapping the body for an HTTP call later doesn't touch
/// callers.
class AuthRepository {
  // TODO(api): remove [devRoleOverride] once real login returns role from the JWT.
  Future<AuthSessionResponse> login(
    LoginRequest request, {
    UserRole devRoleOverride = UserRole.student,
  }) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return AuthSessionResponse(
      id: 'mock-user-id',
      name: devRoleOverride == UserRole.student
          ? 'Krutarth Solanki'
          : '${devRoleOverride.label} User',
      email: request.email,
      role: devRoleOverride,
      token: 'mock.jwt.token',
    );
  }

  Future<AuthSessionResponse> register(RegisterRequest request) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return AuthSessionResponse(
      id: 'mock-new-user-id',
      name: request.name,
      email: request.email,
      role: UserRole.student,
      token: 'mock.jwt.token',
    );
  }

  Future<AuthSessionResponse?> checkSession(String token) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return AuthSessionResponse(
      id: 'mock-user-id',
      name: 'Krutarth Solanki',
      email: 'krutarth.solanki@example.com',
      role: UserRole.student,
      token: token,
    );
  }
}
