import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../controllers/student_screen_time_controller.dart';
import 'curfew_settings_sheet.dart';
import 'restrict_app_sheet.dart';

/// The warden's control panel: current enforcement state, the three actions
/// they actually take (lock, restrict, curfew), and whether the phone has
/// picked up the latest rules yet.
class ParentalControlsCard extends GetView<StudentScreenTimeController> {
  const ParentalControlsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final locked = controller.isDeviceLocked.value;
      final limit = controller.dailyLimitMinutes.value;
      final start = controller.bedtimeStart.value;
      final end = controller.bedtimeEnd.value;
      final blocked = controller.blockedPackages.length;
      final busy = controller.isUpdatingPolicy.value;

      return AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // State strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardPadding, vertical: 14),
              decoration: BoxDecoration(
                color: locked ? AppColors.cancelledRed : AppColors.primarySoft,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
              ),
              child: Row(
                children: [
                  Icon(
                    locked ? Icons.lock_rounded : Icons.verified_user_rounded,
                    color: locked ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locked ? 'Phone is locked' : 'Parental controls',
                          style: AppTextStyles.title.copyWith(color: locked ? Colors.white : AppColors.textPrimary),
                        ),
                        Text(
                          locked
                              ? 'Only calls and this app work until you unlock'
                              : _summary(blocked, limit, start, end),
                          style: AppTextStyles.bodySm.copyWith(
                            color: locked ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AppliedBadge(dark: locked),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppDimens.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Rule tiles
                  Row(
                    children: [
                      _RuleTile(
                        icon: Icons.nightlight_round,
                        label: 'Curfew',
                        value: start.isEmpty || end.isEmpty ? 'Off' : '$start–$end',
                        color: AppColors.secondary,
                        onTap: () => CurfewSettingsSheet.show(context),
                      ),
                      const SizedBox(width: AppDimens.gapSm),
                      _RuleTile(
                        icon: Icons.hourglass_bottom_rounded,
                        label: 'Daily limit',
                        value: limit > 0 ? StudentScreenTimeController.formatMinutes(limit) : 'None',
                        color: AppColors.primary,
                        onTap: () => CurfewSettingsSheet.show(context),
                      ),
                      const SizedBox(width: AppDimens.gapSm),
                      _RuleTile(
                        icon: Icons.block_rounded,
                        label: 'Blocked',
                        value: '$blocked app${blocked == 1 ? '' : 's'}',
                        color: AppColors.cancelledRed,
                        onTap: () => RestrictAppSheet.show(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapLg),

                  // Primary action
                  AppButton(
                    label: locked ? 'Unlock phone' : 'Lock phone now',
                    icon: locked ? Icons.lock_open_rounded : Icons.lock_rounded,
                    variant: locked ? AppButtonVariant.outline : AppButtonVariant.danger,
                    isLoading: busy,
                    onPressed: () => _confirmLock(context, !locked),
                  ),
                  const SizedBox(height: AppDimens.gapSm),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Restrict app',
                          icon: Icons.add_moderator_rounded,
                          variant: AppButtonVariant.outline,
                          onPressed: () => RestrictAppSheet.show(context),
                        ),
                      ),
                      const SizedBox(width: AppDimens.gapSm),
                      Expanded(
                        child: AppButton(
                          label: 'Curfew & limit',
                          icon: Icons.tune_rounded,
                          variant: AppButtonVariant.outline,
                          onPressed: () => CurfewSettingsSheet.show(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  String _summary(int blocked, int limit, String start, String end) {
    final parts = <String>[
      if (blocked > 0) '$blocked app${blocked == 1 ? '' : 's'} blocked',
      if (limit > 0) '${StudentScreenTimeController.formatMinutes(limit)} per day',
      if (start.isNotEmpty && end.isNotEmpty) 'curfew $start–$end',
    ];
    return parts.isEmpty ? 'No restrictions' : parts.join(' • ');
  }

  Future<void> _confirmLock(BuildContext context, bool lock) async {
    final name = controller.selectedStudent.value is Map
        ? (controller.selectedStudent.value['name'] ?? 'this student').toString()
        : 'this student';
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusLg)),
        title: Text(lock ? 'Lock $name\'s phone?' : 'Unlock $name\'s phone?'),
        content: Text(
          lock
              ? 'Every app except calls and the hostel app will be blocked within about 30 seconds. '
                  'The student will see a lock screen explaining why.'
              : 'Normal use resumes. Blocked apps, curfew and the daily limit still apply.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          AppButton(
            label: lock ? 'Lock now' : 'Unlock',
            icon: lock ? Icons.lock_rounded : Icons.lock_open_rounded,
            variant: lock ? AppButtonVariant.danger : AppButtonVariant.primary,
            expand: false,
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );
    if (ok == true) controller.toggleDeviceLock(lock);
  }
}

/// "Applied on phone 2 min ago" vs "Waiting for phone": compares the version
/// the device last reported against what the warden has saved.
class _AppliedBadge extends GetView<StudentScreenTimeController> {
  final bool dark;
  const _AppliedBadge({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final comp = controller.compliance;
      final appliedAtRaw = comp['policyAppliedAt'];
      final deviceVersion = (comp['policyVersion'] ?? '').toString();
      final saved = controller.policyVersion.value;

      DateTime? appliedAt;
      if (appliedAtRaw is num && appliedAtRaw > 0) {
        appliedAt = DateTime.fromMillisecondsSinceEpoch(appliedAtRaw.toInt());
      }
      final pending = saved.isNotEmpty && deviceVersion != saved;

      final fg = dark ? Colors.white : (pending ? AppColors.warningOrange : AppColors.successGreen);
      final text = appliedAt == null
          ? 'Not applied yet'
          : pending
              ? 'Syncing…'
              : 'On phone ${StudentScreenTimeController.relativeTime(appliedAt)}';

      return Tooltip(
        message: 'Whether the student\'s phone has received the latest rules',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: fg.withValues(alpha: dark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(pending ? Icons.sync_rounded : Icons.check_circle_rounded, size: 12, color: fg),
              const SizedBox(width: 4),
              Text(text, style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    });
  }
}

class _RuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _RuleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
