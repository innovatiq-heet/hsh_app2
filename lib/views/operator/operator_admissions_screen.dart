import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import 'operator_admissions_controller.dart';

class OperatorAdmissionsScreen extends GetView<OperatorAdmissionsController> {
  const OperatorAdmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admission Approvals')),
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          builder: (context) {
            if (controller.requests.isEmpty) {
              return const EmptyState(
                icon: Icons.how_to_reg_outlined,
                title: 'No pending admissions',
              );
            }
            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppDimens.screenPadding),
                itemCount: controller.requests.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppDimens.gapMd),
                itemBuilder: (context, i) {
                  final r = controller.requests[i];
                  final isApproving = controller.approvingId.value == r.id;
                  return AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.fullName, style: AppTextStyles.subtitle),
                              Text(r.email, style: AppTextStyles.bodySm),
                              Text(r.phone, style: AppTextStyles.bodySm),
                              Text(
                                'Requested ${DateFormatting.dateTime(r.requestedAt)}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        AppButton(
                          label: 'Approve',
                          expand: false,
                          isLoading: isApproving,
                          onPressed: () => controller.approve(r.id),
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
    );
  }
}
