import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/chart_card.dart';
import 'laundry_home_controller.dart';

class LaundryHomeScreen extends GetView<LaundryHomeController> {
  const LaundryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AsyncStateView(
        isLoading: controller.isLoading.value,
        hasError: controller.hasError.value,
        errorMessage: controller.errorMessage.value,
        onRetry: controller.load,
        builder: (context) => RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(AppDimens.screenPadding),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Tickets', style: AppTextStyles.bodySm),
                    const SizedBox(height: 4),
                    Text(
                      '${controller.totalTickets.value}',
                      style: AppTextStyles.displayMd,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.gapLg),
              ChartCard(
                title: 'Tickets by Status',
                points: controller.statusCounts,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
