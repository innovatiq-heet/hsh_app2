import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/user_role.dart';
import '../../constants/app_routes.dart';
import '../../network/repository/authentication/auth_repository.dart';
import '../../network/request/authentication/login_request.dart';
import '../../storage/session_store.dart';
import '../../utils/validators.dart';

class LoginController extends GetxController {
  final AuthRepository _authRepository = Get.find();

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;

  // TODO(api): remove dev role switcher once real login returns role from the JWT.
  final Rx<UserRole> devRole = UserRole.student.obs;

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  String? validateEmail(String? value) => Validators.email(value);

  String? validatePassword(String? value) => Validators.password(value);

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;
    isLoading.value = true;
    try {
      final session = await _authRepository.login(
        LoginRequest(
          email: emailController.text.trim(),
          password: passwordController.text,
        ),
        devRoleOverride: devRole.value,
      );
      await SessionStore.instance.saveSession(
        token: session.token,
        role: session.role,
        email: session.email,
        name: session.name,
      );
      _routeByRole(session.role);
    } finally {
      isLoading.value = false;
    }
  }

  void _routeByRole(UserRole role) {
    switch (role) {
      case UserRole.student:
        Get.offAllNamed(Routes.studentHome);
        break;
      case UserRole.admin:
      case UserRole.warden:
        Get.offAllNamed(Routes.operatorShell);
        break;
      case UserRole.staff:
        Get.offAllNamed(Routes.laundryModule);
        break;
      case UserRole.complainsolver:
        Get.offAllNamed(Routes.complainSolverModule);
        break;
      case UserRole.unknown:
        Get.snackbar('Login failed', 'Unrecognized role for this account.');
        break;
    }
  }
}
