import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';
import '../../../network/network_controller.dart';
import '../widgets/app_button.dart';
import '../widgets/no_internet_animation.dart';

/// Full-screen or overlay view presented when network connectivity is lost.
class NoInternetScreen extends StatefulWidget {
  final VoidCallback? onRetry;
  final bool showBackButton;

  const NoInternetScreen({
    super.key,
    this.onRetry,
    this.showBackButton = false,
  });

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool _showTips = false;

  NetworkController? get _controller {
    return Get.isRegistered<NetworkController>()
        ? Get.find<NetworkController>()
        : null;
  }

  Future<void> _handleRetry() async {
    if (widget.onRetry != null) {
      widget.onRetry!();
      return;
    }
    if (_controller != null) {
      final success = await _controller!.checkConnection();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Still offline. Please check your network and try again.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.cancelledRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.screenPadding,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Bar / Spacer
                      Align(
                        alignment: Alignment.topLeft,
                        child: widget.showBackButton
                            ? IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: AppColors.textPrimary,
                                ),
                                onPressed: () => Navigator.of(context).maybePop(),
                              )
                            : const SizedBox(height: 16),
                      ),

                      // Central Content
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const NoInternetAnimation(size: 210),
                          const SizedBox(height: AppDimens.gapLg),

                          // Offline badge pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusPill,
                              ),
                              border: Border.all(
                                color: AppColors.primaryLight.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.cancelledRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Connection Lost',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapMd),

                          // Title
                          Text(
                            'No Internet Connection',
                            style: AppTextStyles.headline.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimens.gapSm),

                          // Description
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Please check your Wi-Fi or mobile data settings. The app will automatically restore once connection is back.',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapXl),

                          // Retry Button
                          Obx(() {
                            final isChecking = _controller?.isChecking.value ?? false;
                            return AppButton(
                              label: isChecking ? 'Checking Connection...' : 'Try Again',
                              icon: Icons.refresh_rounded,
                              isLoading: isChecking,
                              onPressed: isChecking ? null : _handleRetry,
                            );
                          }),
                          const SizedBox(height: AppDimens.gapLg),

                          // Troubleshooting Expandable Guide
                          _buildTroubleshootingCard(),
                        ],
                      ),

                      // Bottom listening indicator
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Auto-reconnecting when network is detected...',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTroubleshootingCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          onTap: () {
            setState(() {
              _showTips = !_showTips;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.secondarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.help_outline_rounded,
                            size: 18,
                            color: AppColors.secondaryDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Troubleshooting Tips',
                          style: AppTextStyles.title.copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                    Icon(
                      _showTips
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      children: [
                        const Divider(height: 1, color: AppColors.borderLight),
                        const SizedBox(height: 12),
                        _buildTipItem(
                          icon: Icons.airplanemode_inactive_rounded,
                          title: 'Airplane Mode',
                          subtitle: 'Make sure Airplane Mode is turned off.',
                        ),
                        const SizedBox(height: 10),
                        _buildTipItem(
                          icon: Icons.wifi_rounded,
                          title: 'Wi-Fi / Mobile Data',
                          subtitle: 'Confirm that your device is connected to a network.',
                        ),
                        const SizedBox(height: 10),
                        _buildTipItem(
                          icon: Icons.router_rounded,
                          title: 'Router / Hotspot',
                          subtitle: 'If on Wi-Fi, verify if other devices can access the internet.',
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: _showTips
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 260),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryLight),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
