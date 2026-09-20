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
import '../shared/widgets/app_refresh_indicator.dart';
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
            return AppRefreshIndicator(
              onRefresh: controller.load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverGradientHeader(
                    overline: 'Laundry Service',
                    title: 'Wash & Wear',
                    expandedHeight: 280.0,
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
                              label: '${controller.activeCount} in progress',
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.gapMd,
                        AppDimens.screenPadding,
                        100,
                      ),
                    child: Obx(() {
                      final displayedTickets = controller.filteredTickets;
                      final currentFilter =
                          controller.selectedStatusFilter.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Status Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                  label: 'All',
                                  count: controller.tickets.length,
                                  isSelected: currentFilter == null,
                                  onSelected: () => controller.setFilter(null),
                                ),
                                const SizedBox(width: AppDimens.gapSm),
                                ...LaundryStatus.values.map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.only(
                                      right: AppDimens.gapSm,
                                    ),
                                    child: _FilterChip(
                                      label: s.label,
                                      count: controller.countForStatus(s),
                                      isSelected: currentFilter == s,
                                      statusColor: s.color,
                                      onSelected: () =>
                                          controller.setFilter(s),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapLg),
                          if (displayedTickets.isEmpty)
                            EmptyState(
                              icon: Icons.checkroom_outlined,
                              title: currentFilter == null
                                  ? 'No laundry tickets found'
                                  : 'No ${currentFilter.label.toLowerCase()} tickets',
                              message: currentFilter == null
                                  ? 'Drop your clothes off and create a ticket to track them.'
                                  : 'You currently have no tickets marked as ${currentFilter.label}.',
                            )
                          else ...[
                            SectionHeader(
                              title: currentFilter == null
                                  ? 'Your tickets (${displayedTickets.length})'
                                  : '${currentFilter.label} tickets (${displayedTickets.length})',
                            ),
                            const SizedBox(height: AppDimens.gapSm),
                            for (final t in displayedTickets)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppDimens.gapMd,
                                ),
                                child: _TicketCard(ticket: t),
                              ),
                          ],
                        ],
                      );
                    }),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onSelected;
  final Color? statusColor;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onSelected,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isSelected ? AppColors.primary : AppColors.surfaceMuted;
    final activeText = isSelected ? Colors.white : AppColors.textPrimary;
    final countBg = isSelected
        ? Colors.white.withValues(alpha: 0.22)
        : AppColors.border;

    return Material(
      color: activeBg,
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (statusColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: activeText,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: countBg,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    color: activeText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

