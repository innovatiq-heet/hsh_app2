import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../controllers/student_screen_time_controller.dart';
import 'app_brand_icon.dart';

/// Displays pending app installation requests from students.
/// Wardens can approve or reject each request directly from here.
class AppRequestsBanner extends GetView<StudentScreenTimeController> {
  final bool compact;
  const AppRequestsBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final requests = controller.pendingAppRequests;
      if (requests.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: AppDimens.gapMd),
        child: AppCard(
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.app_registration_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('App Requests', style: AppTextStyles.title),
                        const SizedBox(height: 2),
                        Text(
                          'Students requesting approval to install apps',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warningOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${requests.length} Pending',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.gapMd),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (ctx, i) {
                  final req = requests[i];
                  final id = req['id'] as int? ?? 0;
                  final appName = (req['appName'] ?? req['packageName'] ?? 'App').toString();
                  final pkg = (req['packageName'] ?? '').toString();
                  final studentName = (req['studentName'] ?? 'Student').toString();
                  final room = (req['room'] ?? '').toString();

                  final reason = (req['reason'] ?? '').toString();

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AppBrandIcon(
                        packageName: pkg,
                        appName: appName,
                        size: 38,
                        showBadge: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appName,
                              style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$studentName ${room.isNotEmpty ? '• Room $room' : ''}',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (reason.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Reason: "$reason"',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Reject Button
                      IconButton(
                        onPressed: () => controller.reviewAppRequest(id, 'reject'),
                        tooltip: 'Reject',
                        icon: const Icon(Icons.close_rounded, color: AppColors.errorRed, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.errorRed.withValues(alpha: 0.1),
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Approve Button with 15-Minute Window
                      FilledButton.icon(
                        onPressed: () => controller.reviewAppRequest(id, 'approve', durationMinutes: 15),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Allow (15m)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
    });
  }
}
