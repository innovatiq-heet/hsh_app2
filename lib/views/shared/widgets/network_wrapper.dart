import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../network/network_controller.dart';
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
        // 1. Primary content or offline screen with smooth crossfade
        Obx(() {
          final isOnline = controller.isConnected.value;

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isOnline
                ? KeyedSubtree(
                    key: const ValueKey('app_content'),
                    child: child,
                  )
                : const KeyedSubtree(
                    key: ValueKey('no_internet_screen'),
                    child: NoInternetScreen(),
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
