import '../controllers/student_detail_controller.dart';
import 'app_limit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../controllers/screen_time_utils.dart';
import 'student_detail_widget.dart';
import 'app_brand_icon.dart';
import '../views/restrict_apps_screen.dart';

/// Per-app usage for the selected day, with explicit allow/block status pills
/// and daily time-limit controls.
class AppUsageCard extends StudentDetailWidget {
  const AppUsageCard({super.key, required super.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = controller.displayAppsList;
      final filter = controller.selectedAppFilter.value;
      final isToday = controller.isTodaySelected;
      final total = controller.selectedDayTotalMinutes;
      final activeFilter = filter == 'Restricted'
          ? 'Restricted'
          : (filter == 'Limited' ? 'Limited' : 'All');

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
                      Text('App activity', style: AppTextStyles.title),
                      const SizedBox(height: 2),
                      Text(
                        isToday
                            ? 'Used today, most first'
                            : 'Used on ${controller.effectiveSelectedDate}, most first',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => RestrictAppsScreen.open(context, controller),
                  icon: const Icon(Icons.shield_outlined, size: 17),
                  label: const Text('Block presets'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.cancelledRed,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: controller.appSearchController,
              onChanged: (v) => controller.appSearchQuery.value = v,
              decoration: InputDecoration(
                hintText: 'Search apps',
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceMuted,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                suffixIcon: controller.appSearchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          controller.appSearchController.clear();
                          controller.appSearchQuery.value = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Full-width pill tabs with equal segments so labels never clip.
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  _FilterPillTab(
                    label: 'All (${controller.totalAvailableAppsCount})',
                    selected: activeFilter == 'All',
                    onTap: () => controller.selectedAppFilter.value = 'All',
                  ),
                  _FilterPillTab(
                    label: 'Blocked (${controller.blockedPackages.length})',
                    selected: activeFilter == 'Restricted',
                    activeColor: AppColors.cancelledRed,
                    onTap: () => controller.selectedAppFilter.value = 'Restricted',
                  ),
                  _FilterPillTab(
                    label: 'Limits (${controller.limitedAppsCount})',
                    selected: activeFilter == 'Limited',
                    onTap: () => controller.selectedAppFilter.value = 'Limited',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap an app row for a daily limit • Tap Allowed / Blocked to change access',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppDimens.gapMd),

            if (controller.isLoadingDateUsage.value && list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            else if (list.isEmpty)
              EmptyState(
                icon: activeFilter == 'Restricted'
                    ? Icons.verified_user_outlined
                    : (activeFilter == 'Limited' ? Icons.hourglass_bottom_rounded : Icons.apps_outlined),
                title: activeFilter == 'Restricted'
                    ? 'No blocked apps yet'
                    : (activeFilter == 'Limited'
                        ? 'No app limits set'
                        : (isToday ? 'No app usage recorded' : 'No per-app breakdown for this day')),
                message: activeFilter == 'Restricted'
                    ? 'Tap "Allowed" on any app or open "Block presets" to restrict distracting apps.'
                    : (activeFilter == 'Limited'
                        ? 'Tap any app row or its timer icon to set a daily limit.'
                        : (isToday
                            ? 'Usage appears once the phone reports in (every ~5 minutes).'
                            : (total > 0
                                ? 'Daily total is ${formatMinutes(total)}. Individual app breakdown is logged live during each day.'
                                : 'No usage was logged on this day.'))),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _AppRow(item: list[i], dayTotal: total, controller: controller),
              ),
          ],
        ),
      );
    });
  }
}

class _FilterPillTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _FilterPillTab({
    required this.label,
    required this.selected,
    this.activeColor = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppRow extends StudentDetailWidget {
  final Map<String, dynamic> item;
  final int dayTotal;
  const _AppRow({required this.item, required this.dayTotal, required super.controller});

  /// Own [Obx]: list rows are built outside the card's Obx, and a limit set or
  /// removed must show at once.
  @override
  Widget build(BuildContext context) => Obx(() => _row(context));

  Widget _row(BuildContext context) {
    final pkg = (item['packageName'] ?? '').toString();
    final name = (item['appName'] ?? pkg).toString();
    final mins = extractAppMinutes(item);
    final blocked = item['isBlocked'] == true;
    // The policy's limit, not the row's: the server sends 0 for every app
    // without a rule, which hid a limit just set until the next refresh.
    final limit = controller.appLimitFor(pkg, rowValue: item['dailyLimitMinutes']);
    final isLimitReached = limit > 0 && mins >= limit;
    final share = limit > 0
        ? (mins / limit).clamp(0.0, 1.0)
        : (dayTotal > 0 ? (mins / dayTotal).clamp(0.0, 1.0) : 0.0);

    return InkWell(
      onTap: () => AppLimitSheet.show(
        context,
        controller: controller,
        packageName: pkg,
        appName: name,
        currentLimit: limit,
        currentUsage: mins,
      ),
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: blocked
              ? AppColors.cancelledRed.withValues(alpha: 0.05)
              : (isLimitReached ? Colors.amber.withValues(alpha: 0.06) : Colors.transparent),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Row(
          children: [
            AppBrandIcon(packageName: pkg, appName: name, size: 42, isBlocked: blocked),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                            color: blocked ? AppColors.cancelledRed : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        mins > 0
                            ? formatMinutes(mins)
                            : (blocked ? 'Blocked' : '0m'),
                        style: AppTextStyles.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: blocked
                              ? AppColors.cancelledRed
                              : (isLimitReached ? Colors.amber.shade900 : AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  if (limit > 0) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLimitReached
                            ? AppColors.cancelledRed.withValues(alpha: 0.12)
                            : AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_bottom_rounded,
                            size: 11,
                            color: isLimitReached ? AppColors.cancelledRed : AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isLimitReached
                                ? '${formatMinutes(limit)} limit reached'
                                : '${formatMinutes(limit)} limit',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isLimitReached ? AppColors.cancelledRed : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 4,
                      backgroundColor: AppColors.borderLight,
                      valueColor: AlwaysStoppedAnimation(
                        blocked
                            ? AppColors.cancelledRed.withValues(alpha: 0.6)
                            : (isLimitReached
                                ? AppColors.cancelledRed
                                : (limit > 0 && mins >= 0.8 * limit
                                    ? Colors.amber.shade700
                                    : AppColors.primary)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (StudentDetailController.isCoreAndroidService(pkg) && !blocked)
              Tooltip(
                message: 'Essential Android service — protected so Google Pay and alerts keep working',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'System',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Tooltip(
                message: limit > 0
                    ? 'Edit time limit (${formatMinutes(limit)})'
                    : 'Set time limit',
                child: IconButton(
                  constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    limit > 0 ? Icons.hourglass_top_rounded : Icons.timer_outlined,
                    size: 19,
                    color: limit > 0 ? AppColors.primary : AppColors.textMuted,
                  ),
                  onPressed: () => AppLimitSheet.show(
                    context,
                    controller: controller,
                    packageName: pkg,
                    appName: name,
                    currentLimit: limit,
                    currentUsage: mins,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                toggled: !blocked,
                label: blocked ? 'Allow $name' : 'Block $name',
                child: Tooltip(
                  message: blocked ? 'Tap to allow $name' : 'Tap to block $name',
                  child: InkWell(
                    onTap: () => controller.toggleAppBlock(pkg, name, !blocked),
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: blocked
                            ? AppColors.cancelledRed.withValues(alpha: 0.12)
                            : AppColors.successGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                        border: Border.all(
                          color: blocked
                              ? AppColors.cancelledRed.withValues(alpha: 0.45)
                              : AppColors.successGreen.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            blocked ? Icons.block_rounded : Icons.check_circle_rounded,
                            size: 14,
                            color: blocked ? AppColors.cancelledRed : AppColors.successGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            blocked ? 'Blocked' : 'Allowed',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: blocked ? AppColors.cancelledRed : AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
