import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/network_controller.dart';
import '../screens/no_internet_screen.dart';

/// Wraps the root application or individual screens to monitor internet availability.
/// - Shows [NoInternetScreen] with smooth animated transition when disconnected.
/// - Displays a floating "Back Online" notification banner when connectivity is restored.
class NetworkWrapper extends StatelessWidget {
  final Widget child;

  const NetworkWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<NetworkController>()) {
      return child;
    }

    final controller = NetworkController.to;

    return Stack(
      children: [
        // 1. Primary app content (keeps cached schedules accessible)
        child,

        // 2. Persistent non-intrusive offline banner using Warning Orange (#8A5A1F)
        Obx(() {
          final isOnline = controller.isConnected.value;
          if (isOnline) return const SizedBox.shrink();

          return Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warningOrange,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warningOrange.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No Internet Connection • Running in offline mode',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        // 2. Floating "Back Online" banner
        Obx(() {
          final showBanner = controller.showRestoredBanner.value;

          return AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            top: showBanner ? MediaQuery.of(context).padding.top + 10 : -80,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: showBanner ? 1.0 : 0.0,
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.successGreen.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppColors.successGreen,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Back Online • Connection restored',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
