import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/laundry_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/laundry/laundry_responses.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/icon_badge.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/status_badge.dart';
import 'laundry_controller.dart';
import 'submit_laundry_ticket_sheet.dart';

class LaundryScreen extends GetView<LaundryController> {
  const LaundryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          builder: (context) {
            final active = controller.tickets
                .where((t) => t.status != LaundryStatus.received)
                .length;
            final displayedTickets = controller.filteredTickets;
            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  GradientHeader(
                    overline: 'Laundry Service',
                    title: 'Wash & Wear',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Available balance',
                                    style: AppTextStyles.bodyMd.copyWith(
                                      color: Colors.white.withValues(alpha: 0.72),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${controller.balance.value.toStringAsFixed(0)}',
                                    style: AppTextStyles.displayXl.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            HeaderPill(
                              icon: Icons.autorenew_rounded,
                              label: '$active in progress',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.gapMd,
                            vertical: AppDimens.gapSm,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMd),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Recharges',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white.withValues(alpha: 0.75),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹${controller.totalRecharges.value.toStringAsFixed(0)}',
                                      style: AppTextStyles.subtitle.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 26,
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                              const SizedBox(width: AppDimens.gapMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Spend',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white.withValues(alpha: 0.75),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹${controller.totalSpend.value.toStringAsFixed(0)}',
                                      style: AppTextStyles.subtitle.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      AppDimens.gapMd,
                      AppDimens.screenPadding,
                      100,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Status Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('All'),
                                selected:
                                    controller.selectedStatusFilter.value ==
                                        null,
                                onSelected: (_) => controller.setFilter(null),
                              ),
                              const SizedBox(width: AppDimens.gapSm),
                              ...LaundryStatus.values.map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppDimens.gapSm,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(s.label),
                                    selected:
                                        controller.selectedStatusFilter.value ==
                                            s,
                                    onSelected: (_) =>
                                        controller.setFilter(s),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapLg),
                        if (displayedTickets.isEmpty)
                          const EmptyState(
                            icon: Icons.checkroom_outlined,
                            title: 'No laundry tickets found',
                            message:
                                'Drop your clothes off and create a ticket to track them.',
                          )
                        else ...[
                          SectionHeader(
                            title: 'Your tickets (${displayedTickets.length})',
                          ),
                          for (final t in displayedTickets)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppDimens.gapMd,
                              ),
                              child: _TicketCard(ticket: t),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => SubmitLaundryTicketSheet(
            onSuccess: controller.load,
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New ticket'),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final LaundryTicketModel ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () =>
          Get.toNamed(Routes.laundryTicketDetail, arguments: ticket.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.local_laundry_service_outlined,
                color: ticket.status.color,
              ),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${ticket.totalItems} items',
                          style: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (ticket.totalPrice > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '·  ₹${ticket.totalPrice.toStringAsFixed(0)}',
                            style: AppTextStyles.subtitle.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatting.dateTime(ticket.submittedAt),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: ticket.status.label,
                color: ticket.status.color,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (ticket.totalWash > 0)
                _categoryChip(
                  icon: Icons.local_laundry_service_outlined,
                  label: '${ticket.totalWash} Wash',
                ),
              if (ticket.totalPress > 0)
                _categoryChip(
                  icon: Icons.iron_outlined,
                  label: '${ticket.totalPress} Press',
                ),
              if (ticket.totalSpecial > 0)
                _categoryChip(
                  icon: Icons.star_outline_rounded,
                  label: '${ticket.totalSpecial} Special',
                ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          _StageBar(status: ticket.status),
        ],
      ),
    );
  }

  Widget _categoryChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Four-segment progress bar: pending → accepted → washed → received.
class _StageBar extends StatelessWidget {
  final LaundryStatus status;

  const _StageBar({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final stage in LaundryStatus.values) ...[
          if (stage != LaundryStatus.values.first) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              decoration: BoxDecoration(
                color: stage.stageIndex <= status.stageIndex
                    ? status.color
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
