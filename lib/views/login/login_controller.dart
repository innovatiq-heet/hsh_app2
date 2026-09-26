import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_number/mobile_number.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/user_role.dart';
import '../../constants/app_routes.dart';
import '../../network/api_exception.dart';
import '../../network/repository/authentication/auth_repository.dart';
import '../../network/request/authentication/login_request.dart';
import '../../storage/session_store.dart';
import '../../utils/validators.dart';

class LoginController extends GetxController {
  final AuthRepository _authRepository = Get.find();

  final formKey = GlobalKey<FormState>();
  late TextEditingController emailController;
  late TextEditingController passwordController;

  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    _attemptAutoLogin();
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  String? validateEmail(String? value) => Validators.email(value);

  String? validatePassword(String? value) => Validators.password(value);


  Future<void> _attemptAutoLogin() async {
    if (!Platform.isAndroid) return;
    try {
      final status = await Permission.phone.request();
      if (!status.isGranted) return;

      final hasSim = await MobileNumber.hasPhonePermission;
      if (!hasSim) return;

      List<String> simNumbers = [];
      final List<SimCard>? simCards = await MobileNumber.getSimCards;
      if (simCards != null && simCards.isNotEmpty) {
        for (final sim in simCards) {
          if (sim.number != null && sim.number!.trim().isNotEmpty) {
            simNumbers.add(sim.number!.trim());
          }
        }
      }

      final mobileNum = await MobileNumber.mobileNumber;
      if (mobileNum != null && mobileNum.trim().isNotEmpty && !simNumbers.contains(mobileNum.trim())) {
        simNumbers.add(mobileNum.trim());
      }

      if (simNumbers.isEmpty) return;

      isLoading.value = true;
      final session = await _authRepository.autoLogin(simNumbers);
      await SessionStore.instance.saveSession(
        token: session.token,
        role: session.role,
        email: session.email,
        name: session.name,
      );
      _routeByRole(session.role);
    } catch (e) {
      // Gracefully fall back to manual login form
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;
    isLoading.value = true;
    try {
      final session = await _authRepository.login(
        LoginRequest(
          email: emailController.text.trim(),
          password: passwordController.text,
        ),
      );
      await SessionStore.instance.saveSession(
        token: session.token,
        role: session.role,
        email: session.email,
        name: session.name,
      );
      _routeByRole(session.role);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Login Failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
    );
  }

  void _routeByRole(UserRole role) {
    switch (role) {
      case UserRole.student:
      case UserRole.leader:
        Get.offAllNamed(Routes.studentHome);
        break;
      case UserRole.admin:
      case UserRole.warden:
        Get.offAllNamed(Routes.operatorShell);
        break;
      case UserRole.laundry:
      case UserRole.staff:
        Get.offAllNamed(Routes.laundryModule);
        break;
      case UserRole.complainsolver:
        Get.offAllNamed(Routes.complainSolverModule);
        break;
      case UserRole.attendance:
        Get.offAllNamed(Routes.operatorAttendanceQrDisplay);
        break;
      case UserRole.unknown:
        _showError('Unrecognized role for this account.');
        break;
    }
  }
}
