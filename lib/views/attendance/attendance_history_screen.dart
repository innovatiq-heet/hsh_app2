import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/skeleton_loader.dart';
import 'attendance_history_controller.dart';

class AttendanceHistoryScreen extends GetView<AttendanceHistoryController> {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimens.screenPadding),
            child: Obx(
              () => Wrap(
                spacing: AppDimens.gapSm,
                runSpacing: AppDimens.gapSm,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: controller.typeFilter.value == null,
                    onSelected: (_) => controller.setTypeFilter(null),
                  ),
                  ...AttendanceType.values.map(
                    (t) => ChoiceChip(
                      label: Text(t.label),
                      selected: controller.typeFilter.value == t,
                      onSelected: (_) => controller.setTypeFilter(t),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      controller.fromDate.value == null
                          ? 'Date range'
                          : '${DateFormatting.dateOnly(controller.fromDate.value!)} - ${controller.toDate.value != null ? DateFormatting.dateOnly(controller.toDate.value!) : '...'}',
                    ),
                    onPressed: () => _pickRange(context),
                  ),
                  if (controller.typeFilter.value != null ||
                      controller.fromDate.value != null)
                    ActionChip(
                      label: const Text('Clear'),
                      onPressed: controller.clearFilters,
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) return const SkeletonList();
              if (controller.entries.isEmpty) {
                return const EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'No attendance found',
                  message: 'Try a different filter or date range.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppDimens.screenPadding),
                itemCount: controller.entries.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppDimens.gapSm),
                itemBuilder: (context, i) {
                  final entry = controller.entries[i];
                  return ListTile(
                    tileColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    leading: Icon(entry.type.icon, color: AppColors.primary),
                    title: Text(
                      entry.type.label,
                      style: AppTextStyles.subtitle,
                    ),
                    subtitle: Text(DateFormatting.dateTime(entry.markedAt)),
                    trailing: Icon(
                      entry.viaCode
                          ? Icons.qr_code_scanner_outlined
                          : Icons.touch_app_outlined,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (range != null) {
      controller.setDateRange(range.start, range.end);
    }
  }
}
