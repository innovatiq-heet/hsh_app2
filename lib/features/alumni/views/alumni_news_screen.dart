import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/alumni/alumni_models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../controllers/alumni_controller.dart';

class AlumniNewsScreen extends StatefulWidget {
  const AlumniNewsScreen({super.key});

  @override
  State<AlumniNewsScreen> createState() => _AlumniNewsScreenState();
}

class _AlumniNewsScreenState extends State<AlumniNewsScreen> {
  final AlumniController controller = Get.find<AlumniController>();

  @override
  void initState() {
    super.initState();
    controller.loadNews();
  }

  void _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: CustomScrollView(
        slivers: [
          SliverGradientHeader(
            overline: 'Hostel Community',
            title: 'Giving Back & News',
            subtitle: 'Renovations, achievements & voluntary initiatives',
            expandedHeight: 180,
            leading: HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Get.back(),
            ),
          ),
          SliverToBoxAdapter(
            child: Obx(() {
              if (controller.isNewsLoading.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final newsList = controller.newsList;
              if (newsList.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'No News or Initiatives',
                    message: 'Hostel renovation updates and voluntary contribution initiatives will appear here.',
                  ),
                );
              }

              return AppRefreshIndicator(
                onRefresh: controller.loadNews,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapLg,
                    AppDimens.screenPadding,
                    AppDimens.gapXxl,
                  ),
                  itemCount: newsList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppDimens.gapMd),
                  itemBuilder: (context, index) {
                    final news = newsList[index];
                    return _buildNewsCard(news);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(HostelNewsModel news) {
    Color badgeColor;
    IconData badgeIcon;
    switch (news.category.toLowerCase()) {
      case 'renovation':
        badgeColor = const Color(0xFFF59E0B);
        badgeIcon = Icons.home_repair_service_rounded;
        break;
      case 'achievement':
        badgeColor = const Color(0xFF10B981);
        badgeIcon = Icons.military_tech_rounded;
        break;
      case 'initiative':
        badgeColor = const Color(0xFFEC4899);
        badgeIcon = Icons.volunteer_activism_rounded;
        break;
      default:
        badgeColor = AppColors.primary;
        badgeIcon = Icons.article_rounded;
    }

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: badgeIcon, color: badgeColor, size: 38),
              const SizedBox(width: AppDimens.gapSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  news.categoryDisplay,
                  style: AppTextStyles.caption.copyWith(color: badgeColor, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Text(
                '${news.createdAt.day}/${news.createdAt.month}/${news.createdAt.year}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          Text(news.title, style: AppTextStyles.headline.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(news.content, style: AppTextStyles.bodySm),

          if (news.targetAmount != null && news.targetAmount! > 0) ...[
            const SizedBox(height: AppDimens.gapLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Raised ₹${news.raisedAmount.toInt()}',
                  style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700, color: badgeColor),
                ),
                Text(
                  'Goal ₹${news.targetAmount!.toInt()}',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: news.progressPercentage,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(badgeColor),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(news.progressPercentage * 100).toInt()}% Funded',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: badgeColor),
              ),
            ),
          ],

          if (news.initiativeLink != null && news.initiativeLink!.isNotEmpty) ...[
            const SizedBox(height: AppDimens.gapMd),
            AppButton(
              label: news.category == 'initiative' ? 'Support & Contribute' : 'Learn More',
              icon: Icons.open_in_new_rounded,
              onPressed: () => _openLink(news.initiativeLink!),
            ),
          ],
        ],
      ),
    );
  }
}
