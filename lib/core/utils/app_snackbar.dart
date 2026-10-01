import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';

enum SnackbarType {
  success,
  error,
  warning,
  info,
}

/// Centralized Snackbar utility ensuring consistent branding and status-based colors.
/// - Success: Vibrant green (`AppColors.successGreen`)
/// - Error / Failed: Bright error red (`AppColors.errorRed`)
/// - Warning: Warm amber (`AppColors.warningOrange`)
/// - Info: Rich blue (`AppColors.pendingBlue`)
class AppSnackbar {
  AppSnackbar._();

  /// Show a success snackbar with green background and check icon.
  static void success(
    String title,
    String message, {
    SnackPosition snackPosition = SnackPosition.TOP,
    Duration duration = const Duration(seconds: 3),
    Widget? icon,
    EdgeInsets? margin,
  }) {
    show(
      title: title,
      message: message,
      type: SnackbarType.success,
      snackPosition: snackPosition,
      duration: duration,
      icon: icon,
      margin: margin,
    );
  }

  /// Show an error / failed snackbar with red background and error icon.
  static void error(
    String title,
    String message, {
    SnackPosition snackPosition = SnackPosition.TOP,
    Duration duration = const Duration(seconds: 3),
    Widget? icon,
    EdgeInsets? margin,
  }) {
    show(
      title: title,
      message: message,
      type: SnackbarType.error,
      snackPosition: snackPosition,
      duration: duration,
      icon: icon,
      margin: margin,
    );
  }

  /// Show a warning snackbar with orange background and alert icon.
  static void warning(
    String title,
    String message, {
    SnackPosition snackPosition = SnackPosition.TOP,
    Duration duration = const Duration(seconds: 3),
    Widget? icon,
    EdgeInsets? margin,
  }) {
    show(
      title: title,
      message: message,
      type: SnackbarType.warning,
      snackPosition: snackPosition,
      duration: duration,
      icon: icon,
      margin: margin,
    );
  }

  /// Show an info snackbar with blue background and info icon.
  static void info(
    String title,
    String message, {
    SnackPosition snackPosition = SnackPosition.TOP,
    Duration duration = const Duration(seconds: 3),
    Widget? icon,
    EdgeInsets? margin,
  }) {
    show(
      title: title,
      message: message,
      type: SnackbarType.info,
      snackPosition: snackPosition,
      duration: duration,
      icon: icon,
      margin: margin,
    );
  }

  /// Generic display method with automatic status detection if [type] is omitted.
  static void show({
    required String title,
    required String message,
    SnackbarType? type,
    SnackPosition snackPosition = SnackPosition.TOP,
    Duration duration = const Duration(seconds: 3),
    Widget? icon,
    EdgeInsets? margin,
  }) {
    final resolvedType = type ?? _inferType(title, message);

    final (Color bgColor, Widget defaultIcon) = switch (resolvedType) {
      SnackbarType.success => (
        AppColors.successGreen,
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
      ),
      SnackbarType.error => (
        AppColors.errorRed,
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
      ),
      SnackbarType.warning => (
        AppColors.warningOrange,
        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
      ),
      SnackbarType.info => (
        AppColors.pendingBlue,
        const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
      ),
    };

    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    Get.snackbar(
      title,
      message,
      backgroundColor: bgColor,
      colorText: Colors.white,
      icon: icon ?? defaultIcon,
      snackPosition: snackPosition,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 12,
      duration: duration,
      shouldIconPulse: false,
      titleText: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      messageText: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w400,
          fontSize: 13,
        ),
      ),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static SnackbarType _inferType(String title, String message) {
    final lowerTitle = title.toLowerCase();
    final lowerMessage = message.toLowerCase();

    if (lowerTitle.contains('fail') ||
        lowerTitle.contains('error') ||
        lowerTitle.contains('invalid') ||
        lowerTitle.contains('wrong') ||
        lowerTitle.contains('unable') ||
        lowerTitle.contains('not found') ||
        lowerMessage.contains('fail') ||
        lowerMessage.contains('error') ||
        lowerMessage.contains('could not')) {
      return SnackbarType.error;
    }

    if (lowerTitle.contains('warning') ||
        lowerTitle.contains('required') ||
        lowerTitle.contains('missing') ||
        lowerTitle.contains('alert') ||
        lowerTitle.contains('loading') ||
        lowerMessage.contains('please')) {
      return SnackbarType.warning;
    }

    return SnackbarType.success;
  }
}
