import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../controllers/phonebook_controller.dart';

/// "Know who's calling" — status + one button, with platform-specific copy
/// because Android shows a popup and iOS only shows a label.
class CallerIdCard extends GetView<PhonebookController> {
  const CallerIdCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = controller.callerId.value;
      final busy = controller.isEnablingCallerId.value;
      final isIOS = GetPlatform.isIOS;

      if (!s.supported) {
        return _shell(
          icon: Icons.phone_disabled_rounded,
          color: AppColors.textMuted,
          title: 'Caller ID not available',
          body: 'Needs Android 10 or newer.',
        );
      }

      if (s.isWorking) {
        return _shell(
          icon: Icons.phone_callback_rounded,
          color: AppColors.successGreen,
          title: 'Caller ID is on',
          body: isIOS
              ? 'Incoming calls from students or parents show "HSH · Name · Room · Relation".'
              : 'A card with the student\'s name, room and relation pops up when they call.',
          trailing: TextButton(onPressed: controller.disableCallerId, child: const Text('Turn off')),
          footer: !isIOS && !s.overlayGranted
              ? _hint(
                  'Popup blocked — allow "Display over other apps" to see the card during calls. '
                  'You still get a notification.',
                  action: 'Allow',
                  onTap: controller.enableCallerId,
                )
              : null,
        );
      }

      // Not working yet: role/extension missing, or warden turned it off.
      final body = isIOS
          ? (s.iosState == 'disabled'
              ? 'Turn on "HSH App" under Settings → Phone → Call Blocking & Identification.'
              : 'See which student or parent is calling, right on the call screen.')
          : 'See who\'s calling — name, room and whether it\'s the student or a parent — before you pick up.';
      return _shell(
        icon: Icons.phone_in_talk_rounded,
        color: AppColors.primary,
        title: 'Know who\'s calling',
        body: body,
        trailing: AppButton(
          label: isIOS ? 'Open Settings' : 'Enable',
          icon: isIOS ? Icons.settings_rounded : Icons.check_rounded,
          expand: false,
          isLoading: busy,
          onPressed: controller.enableCallerId,
        ),
      );
    });
  }

  Widget _shell({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    Widget? trailing,
    Widget? footer,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.title),
                    const SizedBox(height: 2),
                    Text(body, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 10), footer],
        ],
      ),
    );
  }

  Widget _hint(String text, {required String action, required VoidCallback onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined, size: 16, color: AppColors.warningOrange),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.caption)),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}
