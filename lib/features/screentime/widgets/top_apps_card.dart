import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../controllers/screen_time_utils.dart';
import 'app_brand_icon.dart';
import 'student_detail_widget.dart';

/// The five apps that took the most time on the selected day, most first,
/// with a link to the full list on the usage screen.
class TopAppsCard extends StudentDetailWidget {
  final VoidCallback onSeeAll;
  const TopAppsCard({super.key, required super.controller, required this.onSeeAll});

  static const int maxApps = 5;

  /// (package, name, minutes) for every app with time on the selected day.
  static List<({String pkg, String name, int minutes})> topApps(Iterable<dynamic> raw) {
    final byPkg = <String, ({String pkg, String name, int minutes})>{};
    for (final a in raw) {
      if (a is! Map) continue;
      final pkg = (a['packageName'] ?? a['package_name'] ?? '').toString();
      final name = (a['appName'] ?? a['app_name'] ?? pkg).toString();
      final minutes = extractAppMinutes(a);
      if (pkg.isEmpty || minutes <= 0) continue;
      final prev = byPkg[pkg];
      byPkg[pkg] = (
        pkg: pkg,
        name: prev != null && prev.name.isNotEmpty && prev.name != pkg ? prev.name : name,
        minutes: (prev?.minutes ?? 0) + minutes,
      );
    }
    final list = byPkg.values.toList()..sort((a, b) => b.minutes.compareTo(a.minutes));
    return list.take(maxApps).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final apps = topApps(controller.currentDayRawApps);
      final total = controller.selectedDayTotalMinutes;
      final isToday = controller.isTodaySelected;

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top apps', style: AppTextStyles.title),
                      const SizedBox(height: 2),
                      Text(
                        isToday ? 'Most used today' : 'Most used on ${controller.effectiveSelectedDate}',
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: onSeeAll, child: const Text('See all')),
              ],
            ),
            const SizedBox(height: AppDimens.gapSm),
            if (apps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.gapMd),
                child: Text(
                  'No app usage recorded yet. It appears once the phone reports in.',
                  style: AppTextStyles.bodySm,
                ),
              )
            else
              for (var i = 0; i < apps.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.borderLight),
                _TopAppRow(app: apps[i], dayTotal: total),
              ],
          ],
        ),
      );
    });
  }
}

class _TopAppRow extends StatelessWidget {
  final ({String pkg, String name, int minutes}) app;
  final int dayTotal;
  const _TopAppRow({required this.app, required this.dayTotal});

  @override
  Widget build(BuildContext context) {
    final share = dayTotal > 0 ? (app.minutes / dayTotal).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          AppBrandIcon(packageName: app.pkg, appName: app.name, size: 38, showBadge: false),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 5,
                    backgroundColor: AppColors.primarySoft,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.gapMd),
          Text(
            formatMinutes(app.minutes),
            style: AppTextStyles.subtitle.copyWith(fontSize: 13.5, color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }
}
