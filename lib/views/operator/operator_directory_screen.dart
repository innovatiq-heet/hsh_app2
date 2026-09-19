import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/admission_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/status_badge.dart';
import 'operator_directory_controller.dart';

class OperatorDirectoryScreen extends GetView<OperatorDirectoryController> {
  const OperatorDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Directory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimens.screenPadding),
            child: AppTextField(
              controller: controller.searchController,
              label: 'Search by name or room',
              prefixIcon: Icons.search,
              onChanged: controller.search,
            ),
          ),
          Expanded(
            child: Obx(
              () => AsyncStateView(
                isLoading: controller.isInitialLoading.value,
                hasError: controller.hasError.value,
                errorMessage: '',
                onRetry: controller.loadInitial,
                builder: (context) {
                  if (controller.items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.people_outline,
                      title: 'No students found',
                    );
                  }
                  return _DirectoryList(controller: controller);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectoryList extends StatelessWidget {
  final OperatorDirectoryController controller;

  const _DirectoryList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            controller.loadMore();
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          itemCount:
              controller.items.length + (controller.hasMore.value ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: AppDimens.gapSm),
          itemBuilder: (context, i) {
            if (i >= controller.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.gapLg),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final s = controller.items[i];
            return AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      s.fullName.isNotEmpty ? s.fullName[0] : '?',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.fullName, style: AppTextStyles.subtitle),
                        Text(
                          'Room ${s.room} · ${s.phone}',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(label: s.status.label, color: s.status.color),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}
