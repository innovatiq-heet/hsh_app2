import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../controllers/student_screen_time_controller.dart';
import 'app_brand_icon.dart';
import 'restrict_app_sheet.dart';

/// Per-app usage for the selected day, with a block/allow toggle on each row.
class AppUsageCard extends GetView<StudentScreenTimeController> {
  const AppUsageCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = controller.displayAppsList;
      final filter = controller.selectedAppFilter.value;
      final isToday = controller.isTodaySelected;
      final total = controller.selectedDayTotalMinutes;

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
                      Text('Apps', style: AppTextStyles.title),
                      const SizedBox(height: 2),
                      Text(
                        isToday ? 'Used today, most first' : 'Used on this day',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => RestrictAppSheet.show(context),
                  icon: const Icon(Icons.add_moderator_rounded, size: 18),
                  label: const Text('Restrict'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.cancelledRed),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search + filter on one line
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
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'All', label: Text('All (${list.length})')),
                ButtonSegment(
                  value: isToday ? 'Used Today' : 'Used on Day',
                  label: Text('Used (${controller.currentDayRawApps.length})'),
                ),
                ButtonSegment(
                  value: 'Restricted',
                  label: Text('Blocked (${controller.blockedPackages.length})'),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (s) => controller.selectedAppFilter.value = s.first,
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
                side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? AppColors.primary : AppColors.surface,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),

            if (list.isEmpty)
              EmptyState(
                icon: filter == 'Restricted' ? Icons.verified_user_outlined : Icons.apps_outlined,
                title: filter == 'Restricted' ? 'Nothing blocked yet' : 'No app usage recorded',
                message: filter == 'Restricted'
                    ? 'Use "Restrict" to block distracting apps on this phone.'
                    : 'Usage appears once the phone reports in (every ~5 minutes).',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _AppRow(item: list[i], dayTotal: total),
              ),
          ],
        ),
      );
    });
  }
}

class _AppRow extends GetView<StudentScreenTimeController> {
  final Map<String, dynamic> item;
  final int dayTotal;
  const _AppRow({required this.item, required this.dayTotal});

  @override
  Widget build(BuildContext context) {
    final pkg = (item['packageName'] ?? '').toString();
    final name = (item['appName'] ?? pkg).toString();
    final mins = StudentScreenTimeController.toInt(item['minutes']);
    final blocked = item['isBlocked'] == true;
    final share = dayTotal > 0 ? (mins / dayTotal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: blocked ? AppColors.cancelledRed.withValues(alpha: 0.05) : Colors.transparent,
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
                      mins > 0 ? StudentScreenTimeController.formatMinutes(mins) : '—',
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: blocked ? AppColors.cancelledRed : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 4,
                    backgroundColor: AppColors.borderLight,
                    valueColor: AlwaysStoppedAnimation(
                      blocked ? AppColors.cancelledRed.withValues(alpha: 0.6) : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: blocked ? 'Allow $name' : 'Block $name',
            child: Switch.adaptive(
              value: !blocked,
              activeTrackColor: AppColors.successGreen,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppColors.cancelledRed,
              trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
              onChanged: (allowed) => controller.toggleAppBlock(pkg, name, !allowed),
            ),
          ),
        ],
      ),
    );
  }
}
