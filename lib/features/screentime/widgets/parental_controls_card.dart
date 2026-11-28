import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../controllers/screen_time_utils.dart';
import 'student_detail_widget.dart';
import '../views/curfew_limit_screen.dart';
import '../views/restrict_apps_screen.dart';

/// The warden's control panel: current enforcement state, the three actions
/// they actually take (lock, restrict, curfew), and whether the phone has
/// picked up the latest rules yet.
class ParentalControlsCard extends StudentDetailWidget {
  const ParentalControlsCard({super.key, required super.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final locked = controller.isDeviceLocked.value;
      final limit = controller.dailyLimitMinutes.value;
      final start = controller.bedtimeStart.value;
      final end = controller.bedtimeEnd.value;
      final blocked = controller.blockedPackages.length;
      final busy = controller.isUpdatingPolicy.value;
      final playStoreBlocked = controller.playStoreBlocked.value;
      final browsersBlocked = controller.restrictBrowsers.value;

      return AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // State strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardPadding, vertical: 12),
              decoration: BoxDecoration(
                color: locked ? AppColors.cancelledRed : AppColors.primarySoft,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
              ),
              child: Row(
                children: [
                  Icon(
                    locked ? Icons.lock_rounded : Icons.verified_user_rounded,
                    size: 20,
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
                        if (locked)
                          Text(
                            'Calls & HSH Connect only',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AppliedBadge(dark: locked, controller: controller),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Rule tiles: one tap into bedtime/limit or blocked apps
                  Row(
                    children: [
                      _RuleTile(
                        icon: Icons.nightlight_round,
                        label: 'Bedtime & daily limit',
                        value: _bedtimeAndLimit(start, end, limit),
                        color: AppColors.secondary,
                        onTap: controller.isSelfDevice ? null : () => CurfewLimitScreen.open(context, controller),
                      ),
                      const SizedBox(width: 10),
                      _RuleTile(
                        icon: Icons.block_rounded,
                        label: 'Blocked apps',
                        value: blocked == 0 ? 'None' : '$blocked app${blocked == 1 ? '' : 's'}',
                        color: AppColors.cancelledRed,
                        onTap: controller.isSelfDevice ? null : () => RestrictAppsScreen.open(context, controller),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (controller.isSelfDevice) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This is your own profile. Device controls are managed by hostel supervisors.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Grouped quick controls (Phone lock, Play Store, Web browsers)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        _ActionControlRow(
                          icon: locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                          iconColor: locked ? AppColors.cancelledRed : AppColors.textSecondary,
                          title: 'Phone lock',
                          status: locked ? 'Locked (calls only)' : 'Unlocked',
                          statusColor: locked ? AppColors.cancelledRed : AppColors.textMuted,
                          trailing: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: locked ? AppColors.primarySoft : const Color(0xFFFEE2E2),
                              foregroundColor: locked ? AppColors.primaryDark : AppColors.cancelledRed,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: (controller.isSelfDevice || busy)
                                ? null
                                : () => _confirmLock(context, !locked),
                            icon: Icon(locked ? Icons.lock_open_rounded : Icons.lock_rounded, size: 15),
                            label: Text(
                              locked ? 'Unlock' : 'Lock',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.borderLight),
                        _PlayStoreRow(
                          blocked: playStoreBlocked,
                          passMinutesLeft: controller.hasActiveInstallPass
                              ? controller.installPassRemainingMinutes
                              : 0,
                          onChanged: controller.isSelfDevice
                              ? null
                              : (allow) => _confirmPlayStore(context, block: !allow),
                          onPassTap: (controller.isSelfDevice || !playStoreBlocked || busy)
                              ? null
                              : () => controller.hasActiveInstallPass
                                  ? controller.revokeInstallPass()
                                  : _confirmInstallPass(context),
                        ),
                        const Divider(height: 1, color: AppColors.borderLight),
                        _ToggleRow(
                          icon: Icons.public_rounded,
                          title: 'Web browsers',
                          status: browsersBlocked ? 'Blocked (Chrome, Brave, etc.)' : 'Allowed',
                          color: browsersBlocked ? AppColors.cancelledRed : AppColors.successGreen,
                          allowed: !browsersBlocked,
                          onChanged: controller.isSelfDevice
                              ? null
                              : (allow) => controller.setBrowsersRestricted(!allow),
                        ),
                      ],
                    ),
                  ),

                  if (controller.canIssueRemovalCode || controller.isSelectedStudentEnrolled) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (controller.canIssueRemovalCode)
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                                ),
                              ),
                              onPressed: (controller.isSelfDevice || controller.isGeneratingRemovalCode.value)
                                  ? null
                                  : () => _confirmRemovalCode(context),
                              icon: const Icon(Icons.vpn_key_rounded, size: 16),
                              label: Text(
                                controller.isGeneratingRemovalCode.value ? 'Generating…' : 'Removal code',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        if (controller.canIssueRemovalCode && controller.isSelectedStudentEnrolled)
                          const SizedBox(width: 8),
                        if (controller.isSelectedStudentEnrolled)
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                                ),
                              ),
                              onPressed: () => _openPolicyHistory(context),
                              icon: const Icon(Icons.history_rounded, size: 16),
                              label: const Text(
                                'Change history',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  /// "22:00–06:00 · 2h", "Off", or just the part that is set.
  String _bedtimeAndLimit(String start, String end, int limit) {
    final bedtime = start.isNotEmpty && end.isNotEmpty ? '$start–$end' : '';
    final allowance = limit > 0 ? formatMinutes(limit) : '';
    if (bedtime.isEmpty && allowance.isEmpty) return 'Off';
    return [bedtime, allowance].where((p) => p.isNotEmpty).join(' · ');
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

  /// Confirms, generates a one-time 6-digit code (`generateRemovalCode`),
  /// then shows it once so it can be read to the student directly. The code
  /// turns off removal protection on their phone when they enter it there —
  /// see `docs/PARENT_CONTROL_DOCS.md` §5.7.
  Future<void> _confirmRemovalCode(BuildContext context) async {
    final name = controller.selectedStudent.value is Map
        ? (controller.selectedStudent.value['name'] ?? 'this student').toString()
        : 'this student';
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusLg)),
        title: const Text('Generate removal code?'),
        content: Text(
          'This creates a one-time code that lets $name turn off removal protection on their own '
          'phone and uninstall the app. Only generate it for a genuine uninstall or phone handover — '
          'anyone who has the code can use it, so read it to $name directly rather than sending it '
          'where others could see it.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          AppButton(
            label: 'Generate code',
            icon: Icons.vpn_key_rounded,
            variant: AppButtonVariant.primary,
            expand: false,
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final result = await controller.generateRemovalCode();
      final code = (result['code'] ?? '').toString();
      final expiresAt = (result['expiresAt'] ?? result['expires_at'] ?? '').toString();
      if (code.isEmpty) throw StateError('removal code response had no code');
      if (!context.mounted) return;
      await Get.dialog<void>(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusLg)),
          title: const Text('Removal code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  code,
                  style: AppTextStyles.displayMd.copyWith(letterSpacing: 6, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: AppDimens.gapMd),
              if (expiresAt.isNotEmpty)
                Text(
                  'Expires $expiresAt · usable once.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                ),
              const SizedBox(height: AppDimens.gapSm),
              Text(
                'Read this to $name directly. Do not post or forward it.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            AppButton(label: 'Done', expand: false, onPressed: () => Get.back()),
          ],
        ),
      );
    } catch (e) {
      AppSnackbar.error('Failed', 'Could not generate a removal code.');
    }
  }

  Future<void> _confirmPlayStore(BuildContext context, {required bool block}) async {
    final name = controller.selectedStudent.value is Map
        ? (controller.selectedStudent.value['name'] ?? 'this student').toString()
        : 'this student';
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusLg)),
        title: Text(block ? 'Block Play Store for $name?' : 'Allow Play Store for $name?'),
        content: Text(
          block
              ? '$name will not be able to open the Play Store, other app stores or install APK files. '
                  'They can still send you a request from the block screen.'
                  '${controller.hasActiveInstallPass ? ' The running install pass ends now.' : ''}'
              : '$name will be able to open the Play Store and install or update apps until you block it again. '
                  'Apps you have blocked stay blocked.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          AppButton(
            label: block ? 'Block' : 'Allow',
            icon: block ? Icons.block_rounded : Icons.check_rounded,
            variant: block ? AppButtonVariant.danger : AppButtonVariant.primary,
            expand: false,
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );
    if (ok == true) controller.setPlayStoreBlocked(block);
  }

  Future<void> _confirmInstallPass(BuildContext context) async {
    final name = controller.selectedStudent.value is Map
        ? (controller.selectedStudent.value['name'] ?? 'this student').toString()
        : 'this student';
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusLg)),
        title: const Text('Grant 15-min install pass?'),
        content: Text(
          'Google Play Store will be temporarily unlocked on $name\'s phone for 15 minutes to allow downloading or updating apps. '
          'It will automatically lock again when the 15 minutes expire.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          AppButton(
            label: 'Grant 15 mins',
            icon: Icons.install_mobile_rounded,
            variant: AppButtonVariant.primary,
            expand: false,
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );
    if (ok == true) controller.grantInstallPass(minutes: 15);
  }

  Future<void> _openPolicyHistory(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.88,
        expand: false,
        builder: (_, scrollCtrl) => FutureBuilder<List<Map<String, dynamic>>>(
          future: controller.fetchPolicyHistory(),
          builder: (_, snap) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Policy change history', style: AppTextStyles.headline),
                  const SizedBox(height: 4),
                  Text(
                    'Immutable audit log of locks, limits, and app rules.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: snap.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : snap.hasError
                            ? Center(
                                child: Text(
                                  'Could not load change history.',
                                  style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                                ),
                              )
                            : (snap.data == null || snap.data!.isEmpty)
                                ? Center(
                                    child: Text(
                                      'No policy changes recorded yet.',
                                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                                    ),
                                  )
                                : ListView.separated(
                                    controller: scrollCtrl,
                                    itemCount: snap.data!.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1),
                                    itemBuilder: (_, i) {
                                      final row = snap.data![i];
                                      final msg = (row['message'] ?? '').toString();
                                      final actor = (row['actor_name'] ?? 'Supervisor').toString();
                                      final rawAt = row['created_at'];
                                      final dt = rawAt == null ? null : DateTime.tryParse(rawAt.toString())?.toLocal();
                                      final when = dt == null ? '' : relativeTime(dt);
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                                        title: Text(msg, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                                        subtitle: Text(
                                          when.isEmpty ? actor : '$actor · $when',
                                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "Applied on phone 2 min ago" vs "Waiting for phone": compares the version
/// the device last reported against what the warden has saved.
class _AppliedBadge extends StudentDetailWidget {
  final bool dark;
  const _AppliedBadge({required this.dark, required super.controller});

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
              : 'On phone ${relativeTime(appliedAt)}';

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

class _ActionControlRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String status;
  final Color statusColor;
  final Widget trailing;

  const _ActionControlRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
      child: Row(
        children: [
          Icon(icon, size: 19, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

/// "Play Store · Blocked / Allowed" with an inline 15-min pass action when blocked.
class _PlayStoreRow extends StatelessWidget {
  final bool blocked;
  final int passMinutesLeft;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onPassTap;

  const _PlayStoreRow({
    required this.blocked,
    required this.passMinutesLeft,
    this.onChanged,
    this.onPassTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = blocked ? AppColors.cancelledRed : AppColors.successGreen;
    final status = !blocked
        ? 'Allowed (install & update)'
        : passMinutesLeft > 0
            ? 'Blocked · ${passMinutesLeft}m pass left'
            : 'Blocked (stores & APKs)';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Icon(Icons.shop_rounded, size: 19, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Play Store', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: color),
                ),
              ],
            ),
          ),
          if (blocked && onPassTap != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onPassTap,
              child: Text(
                passMinutesLeft > 0 ? 'Revoke' : '15m pass',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          Switch(
            value: !blocked,
            activeThumbColor: AppColors.successGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final Color color;
  final bool allowed;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.status,
    required this.color,
    required this.allowed,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: color),
                ),
              ],
            ),
          ),
          Switch(
            value: allowed,
            activeThumbColor: AppColors.successGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _RuleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 11),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 17, color: color),
                  const Spacer(),
                  if (onTap != null)
                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700, fontSize: 13.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
