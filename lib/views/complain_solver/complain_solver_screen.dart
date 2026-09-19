import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/complaint_status.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/status_badge.dart';
import 'complain_solver_controller.dart';

/// Complaint Solver dashboard — reachable by complainsolver, admin and
/// warden alike (spec §5.13); not solver-only.
class ComplainSolverScreen extends GetView<ComplainSolverController> {
  const ComplainSolverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaints — Dashboard')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimens.screenPadding),
            child: Obx(
              () => Wrap(
                spacing: AppDimens.gapSm,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: controller.statusFilter.value == null,
                    onSelected: (_) => controller.statusFilter.value = null,
                  ),
                  ...ComplaintStatus.values.map(
                    (s) => ChoiceChip(
                      label: Text(s.label),
                      selected: controller.statusFilter.value == s,
                      onSelected: (_) => controller.statusFilter.value = s,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => AsyncStateView(
                isLoading: controller.isLoading.value,
                hasError: controller.hasError.value,
                errorMessage: controller.errorMessage.value,
                onRetry: controller.load,
                builder: (context) {
                  final list = controller.filtered;
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No complaints found',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: controller.load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppDimens.screenPadding),
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppDimens.gapMd),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return AppCard(
                          onTap: () => Get.toNamed(
                            Routes.complainAdminDetail,
                            arguments: c.id,
                          )?.then((_) => controller.load()),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${c.studentName} · ${c.room}',
                                    style: AppTextStyles.label,
                                  ),
                                  StatusBadge(
                                    label: c.status.label,
                                    color: c.status.color,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimens.gapXs),
                              Text(c.title, style: AppTextStyles.subtitle),
                              const SizedBox(height: 4),
                              Text(
                                DateFormatting.dateTime(c.submittedAt),
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
