import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/laundry_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/laundry/laundry_responses.dart';
import '../../storage/session_store.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/status_badge.dart';
import 'laundry_orders_controller.dart';

class LaundryOrdersScreen extends GetView<LaundryOrdersController> {
  const LaundryOrdersScreen({super.key});

  Future<void> _logout() async {
    await SessionStore.instance.clear();
    Get.offAllNamed(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AsyncStateView(
        isLoading: controller.isLoading.value,
        hasError: controller.hasError.value,
        errorMessage: controller.errorMessage.value,
        onRetry: controller.load,
        builder: (context) => Obx(() {
          final list = controller.filtered;
          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Hero Gradient Header
                GradientHeader(
                  overline: 'Staff Operations',
                  title: 'Laundry Desk',
                  subtitle: 'Manage garment intake, pricing & deliveries',
                  actions: [
                    HeaderIconButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh',
                      onPressed: controller.load,
                    ),
                    HeaderIconButton(
                      icon: Icons.logout_rounded,
                      tooltip: 'Log out',
                      onPressed: _logout,
                    ),
                  ],
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            controller.statusFilter.value =
                                controller.statusFilter.value ==
                                        LaundryStatus.pending
                                    ? null
                                    : LaundryStatus.pending;
                          },
                          child: HeaderPill(
                            icon: Icons.hourglass_top_rounded,
                            label: '${controller.pendingCount} Pending',
                          ),
                        ),
                        const SizedBox(width: AppDimens.gapSm),
                        GestureDetector(
                          onTap: () {
                            controller.statusFilter.value =
                                controller.statusFilter.value ==
                                        LaundryStatus.accepted
                                    ? null
                                    : LaundryStatus.accepted;
                          },
                          child: HeaderPill(
                            icon: Icons.local_laundry_service_rounded,
                            label: '${controller.acceptedCount + controller.washedCount} In Process',
                          ),
                        ),
                        const SizedBox(width: AppDimens.gapSm),
                        GestureDetector(
                          onTap: () {
                            controller.statusFilter.value =
                                controller.statusFilter.value ==
                                        LaundryStatus.received
                                    ? null
                                    : LaundryStatus.received;
                          },
                          child: HeaderPill(
                            icon: Icons.check_circle_rounded,
                            label: '${controller.receivedCount} Delivered',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapLg,
                    AppDimens.screenPadding,
                    100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search & Quick Filter Card
                      AppCard(
                        padding: const EdgeInsets.all(AppDimens.gapMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              label: 'Search Orders',
                              hint: 'Search by Aadhar, name, room or ID...',
                              prefixIcon: Icons.search_rounded,
                              onChanged: (val) =>
                                  controller.searchQuery.value = val,
                            ),
                            const SizedBox(height: AppDimens.gapMd),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChip(
                                    label: 'All',
                                    count: controller.tickets.length,
                                    isSelected:
                                        controller.statusFilter.value == null,
                                    onSelected: () =>
                                        controller.statusFilter.value = null,
                                  ),
                                  const SizedBox(width: AppDimens.gapSm),
                                  ...LaundryStatus.values.map(
                                    (status) => Padding(
                                      padding: const EdgeInsets.only(
                                        right: AppDimens.gapSm,
                                      ),
                                      child: _FilterChip(
                                        label: status.label,
                                        count:
                                            controller.countForStatus(status),
                                        isSelected:
                                            controller.statusFilter.value ==
                                                status,
                                        statusColor: status.color,
                                        onSelected: () {
                                          if (controller.statusFilter.value ==
                                              status) {
                                            controller.statusFilter.value =
                                                null;
                                          } else {
                                            controller.statusFilter.value =
                                                status;
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapLg),

                      // Section Header with count
                      SectionHeader(
                        title: controller.statusFilter.value == null
                            ? 'All Orders (${list.length})'
                            : '${controller.statusFilter.value!.label} Orders (${list.length})',
                      ),
                      const SizedBox(height: AppDimens.gapSm),

                      // Orders List
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: EmptyState(
                            icon: Icons.checkroom_outlined,
                            title: 'No tickets found',
                            message: controller.searchQuery.value.isNotEmpty ||
                                    controller.statusFilter.value != null
                                ? 'No orders match your current filters. Try changing or clearing them.'
                                : 'There are currently no laundry tickets in the system.',
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppDimens.gapMd),
                          itemBuilder: (context, i) {
                            final t = list[i];
                            return _StaffTicketCard(
                              ticket: t,
                              controller: controller,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
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
    final activeBg = isSelected
        ? AppColors.primary
        : AppColors.surfaceMuted;
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
              color: isSelected
                  ? AppColors.primary
                  : AppColors.border,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

class _StaffTicketCard extends StatelessWidget {
  final LaundryTicketModel ticket;
  final LaundryOrdersController controller;

  const _StaffTicketCard({
    required this.ticket,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () =>
          Get.toNamed(Routes.laundryTicketDetail, arguments: ticket.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Info & Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ticket.studentName.isNotEmpty
                                ? ticket.studentName
                                : 'Student #${ticket.aadhar}',
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ticket.room.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusSm),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.meeting_room_outlined,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  ticket.room,
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'Ticket #${ticket.id}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (ticket.aadhar.isNotEmpty) ...[
                          const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
                          Text(
                            ticket.aadhar,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: ticket.status.label,
                color: ticket.status.color,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),

          // Garment Category Pills
          Container(
            padding: const EdgeInsets.all(AppDimens.gapSm + 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Row(
              children: [
                _ItemBadge(
                  icon: Icons.local_laundry_service_outlined,
                  label: 'Wash',
                  count: ticket.totalWash,
                ),
                const SizedBox(width: AppDimens.gapSm),
                _ItemBadge(
                  icon: Icons.iron_outlined,
                  label: 'Press',
                  count: ticket.totalPress,
                ),
                const SizedBox(width: AppDimens.gapSm),
                _ItemBadge(
                  icon: Icons.hotel_outlined,
                  label: 'Special',
                  count: ticket.totalSpecial,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: Text(
                    '${ticket.totalItems} total',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapMd),

          // Total Pricing & Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    ticket.totalAmount > 0
                        ? '₹${ticket.totalAmount.toStringAsFixed(0)}'
                        : 'Pricing pending',
                    style: AppTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ticket.totalAmount > 0
                          ? AppColors.primary
                          : AppColors.warningOrange,
                    ),
                  ),
                ],
              ),
              Text(
                'Submitted: ${DateFormatting.dateTime(ticket.submittedAt)}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const Divider(height: AppDimens.gapLg),

          // Actions Row based on Lifecycle
          Obx(() {
            final isAdvancing =
                controller.advancingTicketId.value == ticket.id.toString();
            if (isAdvancing) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            return Row(
              children: [
                // Lifecycle Action Button
                Expanded(
                  child: _buildLifecycleButton(context),
                ),

                // Admin Delete Button
                if (controller.isAdmin.value) ...[
                  const SizedBox(width: AppDimens.gapSm),
                  IconButton(
                    tooltip: 'Delete Ticket',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.cancelledRed,
                    ),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLifecycleButton(BuildContext context) {
    switch (ticket.status) {
      case LaundryStatus.pending:
        return AppButton(
          label: 'Accept Order',
          icon: Icons.check_circle_outline_rounded,
          onPressed: () => controller.acceptTicket(ticket.id.toString()),
        );
      case LaundryStatus.accepted:
        return AppButton(
          label: 'Mark Washed & Price',
          icon: Icons.local_laundry_service_outlined,
          onPressed: () => _showMarkWashedSheet(context),
        );
      case LaundryStatus.washed:
        return AppButton(
          label: 'Mark Delivered',
          icon: Icons.done_all_rounded,
          onPressed: () => controller.markReceived(ticket.id.toString()),
        );
      case LaundryStatus.received:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.successGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: AppColors.successGreen.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.successGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Delivered & Completed',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
    }
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Ticket'),
        content: Text(
          'Are you sure you want to permanently delete ticket #${ticket.id}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.cancelledRed),
            onPressed: () {
              Get.back();
              controller.deleteTicket(ticket.id.toString());
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMarkWashedSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MarkWashedSheet(
        ticket: ticket,
        onConfirm: (washP, pressP, blanketP, jacketP, bedP) {
          controller.markWashed(
            ticket.id.toString(),
            washPrice: washP,
            pressPrice: pressP,
            blanketPrice: blanketP,
            jacketPrice: jacketP,
            bedSheetPrice: bedP,
          );
        },
      ),
    );
  }
}

class _ItemBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _ItemBadge({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: count > 0 ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _MarkWashedSheet extends StatefulWidget {
  final LaundryTicketModel ticket;
  final void Function(
    double washP,
    double pressP,
    double blanketP,
    double jacketP,
    double bedP,
  ) onConfirm;

  const _MarkWashedSheet({
    required this.ticket,
    required this.onConfirm,
  });

  @override
  State<_MarkWashedSheet> createState() => _MarkWashedSheetState();
}

class _MarkWashedSheetState extends State<_MarkWashedSheet> {
  late final TextEditingController _washPriceController;
  late final TextEditingController _pressPriceController;
  late final TextEditingController _blanketPriceController;
  late final TextEditingController _jacketPriceController;
  late final TextEditingController _bedSheetPriceController;

  @override
  void initState() {
    super.initState();
    _washPriceController = TextEditingController(
      text: (widget.ticket.washPrice ?? 0) > 0
          ? widget.ticket.washPrice!.toStringAsFixed(0)
          : '10',
    );
    _pressPriceController = TextEditingController(
      text: (widget.ticket.pressPrice ?? 0) > 0
          ? widget.ticket.pressPrice!.toStringAsFixed(0)
          : '8',
    );
    _blanketPriceController = TextEditingController(
      text: (widget.ticket.blanketPrice ?? 0) > 0
          ? widget.ticket.blanketPrice!.toStringAsFixed(0)
          : '50',
    );
    _jacketPriceController = TextEditingController(
      text: (widget.ticket.jacketPrice ?? 0) > 0
          ? widget.ticket.jacketPrice!.toStringAsFixed(0)
          : '40',
    );
    _bedSheetPriceController = TextEditingController(
      text: (widget.ticket.bedSheetPrice ?? 0) > 0
          ? widget.ticket.bedSheetPrice!.toStringAsFixed(0)
          : '20',
    );
  }

  @override
  void dispose() {
    _washPriceController.dispose();
    _pressPriceController.dispose();
    _blanketPriceController.dispose();
    _jacketPriceController.dispose();
    _bedSheetPriceController.dispose();
    super.dispose();
  }

  double get _calculatedTotal {
    final wp = double.tryParse(_washPriceController.text.trim()) ?? 0;
    final pp = double.tryParse(_pressPriceController.text.trim()) ?? 0;
    final bp = double.tryParse(_blanketPriceController.text.trim()) ?? 0;
    final jp = double.tryParse(_jacketPriceController.text.trim()) ?? 0;
    final bsp = double.tryParse(_bedSheetPriceController.text.trim()) ?? 0;

    return (widget.ticket.totalWash * wp) +
        (widget.ticket.totalPress * pp) +
        (widget.ticket.blanket * bp) +
        (widget.ticket.jacket * jp) +
        (widget.ticket.bedSheet * bsp);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        AppDimens.gapLg,
        AppDimens.screenPadding,
        MediaQuery.viewInsetsOf(context).bottom + AppDimens.gapLg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Set Pricing & Mark Washed',
                  style: AppTextStyles.title,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              'Ticket #${widget.ticket.id} · ${widget.ticket.studentName}',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimens.gapLg),

            if (widget.ticket.totalWash > 0) ...[
              _priceField(
                controller: _washPriceController,
                label: 'Wash Rate (${widget.ticket.totalWash} items)',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: AppDimens.gapMd),
            ],

            if (widget.ticket.totalPress > 0) ...[
              _priceField(
                controller: _pressPriceController,
                label: 'Press Rate (${widget.ticket.totalPress} items)',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: AppDimens.gapMd),
            ],

            if (widget.ticket.blanket > 0) ...[
              _priceField(
                controller: _blanketPriceController,
                label: 'Blanket Rate (${widget.ticket.blanket} items)',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: AppDimens.gapMd),
            ],

            if (widget.ticket.jacket > 0) ...[
              _priceField(
                controller: _jacketPriceController,
                label: 'Jacket Rate (${widget.ticket.jacket} items)',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: AppDimens.gapMd),
            ],

            if (widget.ticket.bedSheet > 0) ...[
              _priceField(
                controller: _bedSheetPriceController,
                label: 'Bed Sheet Rate (${widget.ticket.bedSheet} items)',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: AppDimens.gapMd),
            ],

            // Calculated total preview card
            Container(
              padding: const EdgeInsets.all(AppDimens.gapMd),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Calculated Total Amount',
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '₹${_calculatedTotal.toStringAsFixed(0)}',
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),

            AppButton(
              label: 'Confirm & Mark Washed',
              icon: Icons.check_rounded,
              onPressed: () {
                final wp =
                    double.tryParse(_washPriceController.text.trim()) ?? 0;
                final pp =
                    double.tryParse(_pressPriceController.text.trim()) ?? 0;
                final bp =
                    double.tryParse(_blanketPriceController.text.trim()) ?? 0;
                final jp =
                    double.tryParse(_jacketPriceController.text.trim()) ?? 0;
                final bsp =
                    double.tryParse(_bedSheetPriceController.text.trim()) ?? 0;

                Navigator.of(context).pop();
                widget.onConfirm(wp, pp, bp, jp, bsp);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onChanged,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      prefixIcon: Icons.currency_rupee,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
    );
  }
}
