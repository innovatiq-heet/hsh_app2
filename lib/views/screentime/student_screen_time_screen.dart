import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/user_role.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import 'student_screen_time_controller.dart';

class StudentScreenTimeScreen extends GetView<StudentScreenTimeController> {
  const StudentScreenTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: CustomScrollView(
        slivers: [
          SliverGradientHeader(
            title: 'Screen Time Monitor',
            subtitle: '10-minute live device activity',
            leading: HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Get.back(),
            ),
            actions: [
              HeaderIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onPressed: () {
                  controller.fetchLiveStatus();
                  controller.fetchHistory();
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Obx(() {
              final isLeader = controller.currentRole.value.canViewScreenTime;

              return Padding(
                padding: const EdgeInsets.all(AppDimens.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leader Aadhar Search Bar
                    if (isLeader) ...[
                      AppCard(
                        padding: const EdgeInsets.all(AppDimens.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Leader Monitoring Section',
                                  style: AppTextStyles.title,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller.searchAadharController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 12,
                                    decoration: InputDecoration(
                                      hintText: 'Enter Student Aadhar (12 digits)',
                                      counterText: '',
                                      isDense: true,
                                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: controller.searchStudent,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  child: const Text('View'),
                                ),
                                if (controller.targetedAadhar.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    tooltip: 'Clear search',
                                    onPressed: controller.clearSearch,
                                  ),
                                ],
                              ],
                            ),
                            if (controller.targetedAadhar.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Showing data for Aadhar: ${controller.targetedAadhar.value}',
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                    ],

                    // Live Status Card
                    _buildLiveCard(),
                    const SizedBox(height: AppDimens.gapMd),

                    // Daily Screen Time Card
                    _buildTodayUsageCard(),
                    const SizedBox(height: AppDimens.gapMd),

                    // Top Apps Breakdown
                    _buildAppBreakdownCard(),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard() {
    return Obx(() {
      final online = controller.isOnline.value;
      final screenOn = controller.isScreenOn.value;
      final app = controller.currentApp.value;

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? (screenOn ? Colors.green : Colors.amber) : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    online
                        ? (screenOn ? 'Screen Active Now' : 'Device Idle (Standby)')
                        : 'Device Offline',
                    style: AppTextStyles.title,
                  ),
                  if (app.isNotEmpty)
                    Text(
                      'Foreground: $app',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.mainBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('10m ping', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTodayUsageCard() {
    return Obx(() {
      final total = controller.totalMinutesToday.value;
      final hours = total ~/ 60;
      final minutes = total % 60;
      final night = controller.nightMinutesToday.value;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7A3723), Color(0xFFC44D28)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "TODAY'S SCREEN TIME",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$hours', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
                const Text('h ', style: TextStyle(color: Colors.white70, fontSize: 18)),
                Text('$minutes', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
                const Text('m', style: TextStyle(color: Colors.white70, fontSize: 18)),
              ],
            ),
            if (night > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.nightlight_round, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Curfew phone usage: $night mins (11 PM - 5 AM)',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildAppBreakdownCard() {
    return Obx(() {
      final list = controller.appBreakdown;
      if (list.isEmpty) return const SizedBox.shrink();

      final total = controller.totalMinutesToday.value > 0 ? controller.totalMinutesToday.value : 1;

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Top App Breakdown'),
            const SizedBox(height: 12),
            ...list.map((item) {
              final mins = item['minutes'] as int? ?? 0;
              final name = item['appName'] ?? item['packageName'] ?? 'App';
              final progress = (mins / total).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                        Text('$mins mins', style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 6,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    });
  }
}
