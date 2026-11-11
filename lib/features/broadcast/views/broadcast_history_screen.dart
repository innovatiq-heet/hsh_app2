import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../controllers/broadcast_history_controller.dart';
import '../widgets/broadcast_widgets.dart';

/// Admin → Broadcast: sent broadcasts and a button to write a new one.
class BroadcastHistoryScreen extends GetView<BroadcastHistoryController> {
  const BroadcastHistoryScreen({super.key});

  Future<void> _compose() async {
    final sent = await Get.toNamed(Routes.operatorBroadcastCompose);
    if (sent is Broadcast) controller.addSent(sent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('New broadcast'),
      ),
      body: AppRefreshIndicator(
        onRefresh: () => controller.load(showLoading: false),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 300) controller.loadMore();
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverGradientHeader(
                overline: 'Admin',
                title: 'Broadcasts',
                subtitle: 'Messages sent to students',
                leading: HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                child: Obx(() => HeaderPill(
                      icon: Icons.campaign_rounded,
                      label: '${controller.total.value} sent',
                    )),
              ),
              Obx(() {
                if (controller.isLoading.value) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (controller.hasError.value) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load broadcasts',
                      message: controller.errorMessage.value,
                      actionLabel: 'Retry',
                      onAction: controller.load,
                    ),
                  );
                }
                final items = controller.broadcasts;
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No broadcasts yet',
                      message: 'Send a message to students by tag or pick them one by one.',
                      actionLabel: 'New broadcast',
                      actionIcon: Icons.add_rounded,
                      onAction: _compose,
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapXl,
                    AppDimens.screenPadding,
                    110,
                  ),
                  sliver: SliverList.builder(
                    itemCount: items.length + (controller.hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppDimens.gapLg),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final b = items[i];
                      final card = Padding(
                        padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                        child: BroadcastCard(
                          broadcast: b,
                          onTap: () => Get.toNamed(Routes.operatorBroadcastDetail, arguments: b),
                        ),
                      );
                      return i < 8 ? StaggeredSlideFade(index: i, child: card) : card;
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
