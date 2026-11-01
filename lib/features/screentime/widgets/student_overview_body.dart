import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../views/student_apps_screen.dart';
import '../views/student_history_screen.dart';
import '../views/student_usage_screen.dart';
import 'app_requests_banner.dart';
import 'live_status_card.dart';
import 'parental_controls_card.dart';
import 'student_detail_widget.dart';
import 'top_apps_card.dart';
import 'usage_hero_card.dart';

/// A student's overview: what the phone is doing now, today against the
/// allowance, the controls, the top apps, and a way into the full usage &
/// trends screen. A short set of cards; anything long lives on its own screen.
class StudentOverviewBody extends StudentDetailWidget {
  const StudentOverviewBody({super.key, required super.controller});

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final firstLoad = controller.isLoading.value &&
        controller.totalMinutesToday.value == 0 &&
        controller.historyRecords.isEmpty;
    if (firstLoad) {
      return const Column(
        children: [
          SkeletonLoader(height: 72, borderRadius: BorderRadius.all(Radius.circular(16))),
          SizedBox(height: 12),
          SkeletonLoader(height: 180, borderRadius: BorderRadius.all(Radius.circular(16))),
          SizedBox(height: 12),
          SkeletonLoader(height: 220, borderRadius: BorderRadius.all(Radius.circular(16))),
        ],
      );
    }

    void openUsage() => StudentUsageScreen.open(context, controller);
    void openApps() => StudentAppsScreen.open(context, controller);
    void openHistory() => StudentHistoryScreen.open(context, controller);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppRequestsBanner(host: controller),
        if (!controller.isSelectedStudentEnrolled) const _NotSetUpNotice(),

        // 1. What's happening now
        LiveStatusCard(controller: controller),
        const SizedBox(height: AppDimens.gapMd),

        // 2. How much, against the allowance
        UsageHeroCard(controller: controller),
        const SizedBox(height: AppDimens.gapMd),

        // 3. What the warden can do about it
        ParentalControlsCard(controller: controller),
        const SizedBox(height: AppDimens.gapMd),

        // 4. Where the time went
        TopAppsCard(controller: controller, onSeeAll: openApps),
        const SizedBox(height: AppDimens.gapMd),

        // 5. More
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _NavTile(
                icon: Icons.insights_rounded,
                color: AppColors.primary,
                title: 'Usage & trends',
                subtitle: 'Daily charts and averages',
                onTap: openUsage,
              ),
              const Divider(height: 1, color: AppColors.borderLight),
              _NavTile(
                icon: Icons.apps_rounded,
                color: AppColors.secondaryDark,
                title: 'Apps',
                subtitle: 'Time per app, block or limit',
                onTap: openApps,
              ),
              const Divider(height: 1, color: AppColors.borderLight),
              _NavTile(
                icon: Icons.history_rounded,
                color: AppColors.accentLight,
                title: 'Requests & history',
                subtitle: 'App requests and past days',
                onTap: openHistory,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown when the student has a room but has not finished phone onboarding.
class _NotSetUpNotice extends StatelessWidget {
  const _NotSetUpNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.gapMd),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.secondaryDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device not set up yet',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                    color: AppColors.secondaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'This student has a hostel room but has not finished phone setup. '
                  'Live data starts once they sign in to the HSH app.',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.secondaryDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the overview's "more" card: icon, title, subtitle, chevron.
class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardPadding, vertical: 14),
        child: Row(
          children: [
            IconBadge(icon: icon, color: color),
            const SizedBox(width: AppDimens.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.title),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySm),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
