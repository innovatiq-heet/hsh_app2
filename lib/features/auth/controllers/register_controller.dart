import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/authentication/auth_repository.dart';
import '../../../core/network/request/authentication/login_request.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/app_snackbar.dart';

class RegisterController extends GetxController {
  final AuthRepository _authRepository = Get.find();

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;


  String? validateRequired(String? value) => Validators.required(value);

  String? validateEmail(String? value) => Validators.email(value);

  String? validatePassword(String? value) => Validators.password(value);

  Future<void> register() async {
    if (!formKey.currentState!.validate()) return;
    isLoading.value = true;
    try {
      final session = await _authRepository.register(
        RegisterRequest(
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          password: passwordController.text,
        ),
      );
      await Get.find<SessionStore>().saveSession(
        token: session.token,
        role: session.role,
        email: session.email,
        name: session.name,
      );
      if (session.isAlumni) {
        Get.offAllNamed(Routes.alumniHub);
      } else {
        Get.offAllNamed(Routes.studentHome);
      }
    } on ApiException catch (e) {
      _showError(
        e.statusCode == 409
            ? 'Email already exists. Please login instead.'
            : e.message,
      );
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  void _showError(String message) {
    AppSnackbar.error(
      'Registration Failed',
      message,
    );
  }
}
