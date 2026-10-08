import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../../../core/storage/session_store.dart';
import '../controllers/alumni_controller.dart';

class AlumniHubScreen extends GetView<AlumniController> {
  const AlumniHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: false,
          errorMessage: 'Unable to load alumni data',
          onRetry: controller.loadDashboard,
          builder: (context) {
            return AppRefreshIndicator(
              onRefresh: controller.loadDashboard,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                slivers: [
                  SliverGradientHeader(
                    overline: 'Hari Saurabh Hostel',
                    title: 'Alumni Network',
                    subtitle: 'Connect, mentor, reunions & career referrals',
                    expandedHeight: 230,
                    leading: Navigator.canPop(context)
                        ? HeaderIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onPressed: () => Get.back(),
                          )
                        : null,
                    actions: [
                      HeaderIconButton(
                        icon: Icons.person_pin_rounded,
                        tooltip: 'My Alumni Profile',
                        onPressed: () => Get.toNamed(Routes.alumniProfile),
                      ),
                      HeaderIconButton(
                        icon: Icons.logout_rounded,
                        tooltip: 'Logout',
                        onPressed: () async {
                          await Get.find<SessionStore>().logout();
                          Get.offAllNamed(Routes.login);
                        },
                      ),
                    ],
                    child: Row(
                      children: [
                        Expanded(
                          child: HeaderPill(
                            icon: Icons.groups_rounded,
                            label: '${controller.directoryList.isNotEmpty ? controller.directoryList.length : '50+'} Alumni',
                          ),
                        ),
                        const SizedBox(width: AppDimens.gapSm),
                        Expanded(
                          child: HeaderPill(
                            icon: Icons.school_rounded,
                            label: '${controller.eventsList.length} Events',
                          ),
                        ),
                        const SizedBox(width: AppDimens.gapSm),
                        Expanded(
                          child: HeaderPill(
                            icon: Icons.work_outline_rounded,
                            label: '${controller.jobsList.length} Referrals',
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.gapLg,
                        AppDimens.screenPadding,
                        AppDimens.gapXxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileCard(),
                          const SizedBox(height: AppDimens.gapXl),

                          const SectionHeader(title: 'Network & Portals'),
                          const SizedBox(height: AppDimens.gapSm),
                          _buildFeatureGrid(),
                          const SizedBox(height: AppDimens.gapXl),

                          SectionHeader(
                            title: 'Upcoming Events & Reunions',
                            actionLabel: 'View all',
                            onAction: () => Get.toNamed(Routes.alumniEvents),
                          ),
                          _buildEventsPreview(),
                          const SizedBox(height: AppDimens.gapXl),

                          SectionHeader(
                            title: 'Alumni Job & Internship Referrals',
                            actionLabel: 'View all',
                            onAction: () => Get.toNamed(Routes.alumniJobs),
                          ),
                          _buildJobsPreview(),
                          const SizedBox(height: AppDimens.gapXl),

                          SectionHeader(
                            title: 'Giving Back & Hostel News',
                            actionLabel: 'View all',
                            onAction: () => Get.toNamed(Routes.alumniNews),
                          ),
                          _buildNewsPreview(),
                        ],
                      ),
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

  Widget _buildProfileCard() {
    final profile = controller.myProfile.value;
    final isSetup = profile != null && (profile.graduationYear != null || profile.currentCompany.isNotEmpty);

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      onTap: () => Get.toNamed(Routes.alumniProfile),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              profile?.initials ?? 'ME',
              style: AppTextStyles.title.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile?.name.isNotEmpty == true ? profile!.name : 'My Alumni Profile',
                        style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile?.isMentor == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'MENTOR',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isSetup
                      ? '${profile.batchLabel} • ${profile.currentRoleLine.isNotEmpty ? profile.currentRoleLine : profile.degree}'
                      : 'Tap to update graduation year, room stayed & workplace',
                  style: AppTextStyles.bodySm.copyWith(
                    color: isSetup ? AppColors.textSecondary : AppColors.primary,
                    fontWeight: isSetup ? FontWeight.normal : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid() {
    final items = [
      _FeatureTile(
        title: 'Alumni Directory',
        subtitle: 'Search by Batch, Degree, Company or City',
        icon: Icons.people_alt_outlined,
        color: AppColors.primary,
        onTap: () => Get.toNamed(Routes.alumniDirectory),
      ),
      _FeatureTile(
        title: 'Mentorship',
        subtitle: 'Guide hostel juniors or request career advice',
        icon: Icons.psychology_outlined,
        color: const Color(0xFF8B5CF6),
        onTap: () => Get.toNamed(Routes.alumniMentorship),
      ),
      _FeatureTile(
        title: 'Reunions & Sabha',
        subtitle: 'Annual functions, sabhas & RSVP',
        icon: Icons.event_available_rounded,
        color: AppColors.warningOrange,
        onTap: () => Get.toNamed(Routes.alumniEvents),
      ),
      _FeatureTile(
        title: 'Job Board',
        subtitle: 'Explore openings & referral opportunities',
        icon: Icons.work_outline_rounded,
        color: AppColors.successGreen,
        onTap: () => Get.toNamed(Routes.alumniJobs),
      ),
      _FeatureTile(
        title: 'Giving Back',
        subtitle: 'Renovations & contribution initiatives',
        icon: Icons.volunteer_activism_outlined,
        color: const Color(0xFFEC4899),
        onTap: () => Get.toNamed(Routes.alumniNews),
      ),
      _FeatureTile(
        title: 'My Profile',
        subtitle: 'Degree, past room & LinkedIn link',
        icon: Icons.badge_outlined,
        color: AppColors.secondary,
        onTap: () => Get.toNamed(Routes.alumniProfile),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppDimens.gapMd,
        crossAxisSpacing: AppDimens.gapMd,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return AppCard(
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          onTap: item.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconBadge(icon: item.icon, color: item.color, size: 44),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.title.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventsPreview() {
    if (controller.eventsList.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Center(
          child: Text('No upcoming events scheduled yet.', style: AppTextStyles.bodySm),
        ),
      );
    }

    final event = controller.eventsList.first;
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      onTap: () => Get.toNamed(Routes.alumniEvents),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.eventTypeDisplay,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          Text(event.title, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  event.venue,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobsPreview() {
    if (controller.jobsList.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Center(
          child: Text('No referral openings posted yet.', style: AppTextStyles.bodySm),
        ),
      );
    }

    final job = controller.jobsList.first;
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      onTap: () => Get.toNamed(Routes.alumniJobs),
      child: Row(
        children: [
          const IconBadge(icon: Icons.work_rounded, color: AppColors.successGreen, size: 44),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${job.company} • ${job.location}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(job.jobTypeDisplay, style: AppTextStyles.caption),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsPreview() {
    if (controller.newsList.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Center(
          child: Text('No hostel initiatives posted yet.', style: AppTextStyles.bodySm),
        ),
      );
    }

    final news = controller.newsList.first;
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      onTap: () => Get.toNamed(Routes.alumniNews),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.volunteer_activism_rounded, color: Color(0xFFEC4899), size: 36),
              const SizedBox(width: AppDimens.gapSm),
              Expanded(
                child: Text(
                  news.title,
                  style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          Text(
            news.content,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (news.targetAmount != null && news.targetAmount! > 0) ...[
            const SizedBox(height: AppDimens.gapSm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: news.progressPercentage,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFEC4899)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
