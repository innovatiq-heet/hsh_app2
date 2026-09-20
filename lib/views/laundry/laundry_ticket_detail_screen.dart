import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/laundry_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/laundry/laundry_responses.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_refresh_indicator.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/skeleton_loader.dart';
import '../shared/widgets/status_badge.dart';
import '../shared/widgets/stepper_timeline.dart';
import 'laundry_ticket_detail_controller.dart';

class LaundryTicketDetailScreen extends GetView<LaundryTicketDetailController> {
  const LaundryTicketDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: Obx(() {
        if (controller.isLoading.value) return const SkeletonList();
        final t = controller.ticket.value;
        if (t == null) {
          return const Center(child: Text('Ticket not found'));
        }
        return AppRefreshIndicator(
          onRefresh: controller.load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Hero Gradient Header
              SliverGradientHeader(
                overline: 'Ticket #${t.id}',
                title: 'Ticket Details',
                subtitle: t.studentName.isNotEmpty
                    ? '${t.studentName}${t.room.isNotEmpty ? ' · Room ${t.room}' : ''}'
                    : 'Aadhar: ${t.aadhar}',
                expandedHeight: 220.0,
                leading: HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Get.back(),
                ),
                child: Row(
                  children: [
                    HeaderPill(
                      label: t.status.label,
                    ),
                    const SizedBox(width: AppDimens.gapSm),
                    HeaderPill(
                      icon: Icons.checkroom_rounded,
                      label: '${t.totalItems} garments',
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.gapLg,
                  AppDimens.screenPadding,
                  100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 4-Stage Lifecycle Stepper & Progress Action
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Order Progress', style: AppTextStyles.subtitle),
                              StatusBadge(
                                label: t.status.label,
                                color: t.status.color,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.gapMd),
                          StepperTimeline(
                            stages: [
                              TimelineStage(
                                label: 'Submitted',
                                timestamp: t.submittedAt,
                                isDone: true,
                                isActive: t.status == LaundryStatus.pending,
                              ),
                              TimelineStage(
                                label: 'Accepted',
                                timestamp: t.status.stageIndex >= 1 ? t.acceptedAt : null,
                                isDone: t.status.stageIndex >= 1,
                                isActive: t.status == LaundryStatus.accepted,
                                onTap: controller.canOperate.value &&
                                        t.status == LaundryStatus.pending
                                    ? controller.acceptTicket
                                    : null,
                              ),
                              TimelineStage(
                                label: 'Washed',
                                timestamp: t.status.stageIndex >= 2 ? t.washTime : null,
                                isDone: t.status.stageIndex >= 2,
                                isActive: t.status == LaundryStatus.washed,
                                onTap: controller.canOperate.value &&
                                        t.status == LaundryStatus.accepted
                                    ? () => _showMarkWashedSheet(context, t)
                                    : null,
                              ),
                              TimelineStage(
                                label: 'Received',
                                timestamp: t.status.stageIndex >= 3 ? t.receiveTime : null,
                                isDone: t.status.stageIndex >= 3,
                                isActive: t.status == LaundryStatus.received,
                                onTap: controller.canOperate.value &&
                                        t.status == LaundryStatus.washed
                                    ? controller.markReceived
                                    : null,
                              ),
                            ],
                          ),

                          // Lifecycle Advance Action Button (for staff/admin)
                          Obx(() {
                            if (!controller.canOperate.value) {
                              return const SizedBox.shrink();
                            }
                            if (controller.isUpdating.value) {
                              return const Padding(
                                padding: EdgeInsets.only(top: AppDimens.gapMd),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: AppDimens.gapMd),
                                const Divider(),
                                const SizedBox(height: AppDimens.gapSm),
                                _buildLifecycleButton(context, t),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapLg),

                    // General Info Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Ticket #${t.id}', style: AppTextStyles.title),
                              StatusBadge(
                                label: t.status.label,
                                color: t.status.color,
                              ),
                            ],
                          ),
                          const Divider(height: AppDimens.gapLg),
                          _row('Student', t.studentName.isNotEmpty ? t.studentName : t.aadhar),
                          if (t.aadhar.isNotEmpty && t.studentName.isNotEmpty)
                            _row('Aadhar', t.aadhar),
                          if (t.room.isNotEmpty) _row('Room', t.room),
                          _row('Total Garments', '${t.totalItems} items'),
                          _row('Submitted At', DateFormatting.dateTime(t.submittedAt)),
                          if (t.status.stageIndex >= 1 && t.acceptedAt != null)
                            _row('Accepted At', DateFormatting.dateTime(t.acceptedAt!)),
                          if (t.status.stageIndex >= 2 && t.washTime != null)
                            _row('Washed At', DateFormatting.dateTime(t.washTime!)),
                          if (t.status.stageIndex >= 3 && t.receiveTime != null)
                            _row('Received At', DateFormatting.dateTime(t.receiveTime!)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapLg),

                    // Itemized Garments Breakdown
                    const SectionHeader(title: 'Garment Breakdown'),
                    const SizedBox(height: AppDimens.gapSm),

                    if (t.totalWash > 0) ...[
                      _CategoryDetailCard(
                        title: 'Wash (${t.totalWash} items)',
                        icon: Icons.local_laundry_service_outlined,
                        iconColor: AppColors.primary,
                        items: [
                          if (t.pants > 0) _ItemCountRow('Pants', t.pants),
                          if (t.shirts > 0) _ItemCountRow('Shirts', t.shirts),
                          if (t.tShirts > 0) _ItemCountRow('T-Shirts', t.tShirts),
                          if (t.towels > 0) _ItemCountRow('Towels', t.towels),
                          if (t.others > 0) _ItemCountRow('Others', t.others),
                        ],
                        unitPrice: (t.washPrice ?? 0) > 0
                            ? '₹${t.washPrice!.toStringAsFixed(0)}/item'
                            : null,
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                    ],

                    if (t.totalPress > 0) ...[
                      _CategoryDetailCard(
                        title: 'Press (${t.totalPress} items)',
                        icon: Icons.iron_outlined,
                        iconColor: Colors.deepOrange,
                        items: [
                          if (t.pressPants > 0) _ItemCountRow('Press Pants', t.pressPants),
                          if (t.pressShirts > 0) _ItemCountRow('Press Shirts', t.pressShirts),
                          if (t.pressTShirts > 0)
                            _ItemCountRow('Press T-Shirts', t.pressTShirts),
                          if (t.pressTowels > 0) _ItemCountRow('Press Towels', t.pressTowels),
                          if (t.pressOthers > 0) _ItemCountRow('Press Others', t.pressOthers),
                        ],
                        unitPrice: (t.pressPrice ?? 0) > 0
                            ? '₹${t.pressPrice!.toStringAsFixed(0)}/item'
                            : null,
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                    ],

                    if (t.totalSpecial > 0) ...[
                      _CategoryDetailCard(
                        title: 'Special Items (${t.totalSpecial} items)',
                        icon: Icons.star_outline_rounded,
                        iconColor: Colors.purple,
                        items: [
                          if (t.blanket > 0)
                            _ItemCountRow(
                              'Blanket',
                              t.blanket,
                              price: (t.blanketPrice ?? 0) > 0
                                  ? '₹${t.blanketPrice!.toStringAsFixed(0)} ea'
                                  : null,
                            ),
                          if (t.jacket > 0)
                            _ItemCountRow(
                              'Jacket',
                              t.jacket,
                              price: (t.jacketPrice ?? 0) > 0
                                  ? '₹${t.jacketPrice!.toStringAsFixed(0)} ea'
                                  : null,
                            ),
                          if (t.bedSheet > 0)
                            _ItemCountRow(
                              'Bed Sheet',
                              t.bedSheet,
                              price: (t.bedSheetPrice ?? 0) > 0
                                  ? '₹${t.bedSheetPrice!.toStringAsFixed(0)} ea'
                                  : null,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                    ],

                    // Pricing Summary Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pricing Summary', style: AppTextStyles.subtitle),
                          const SizedBox(height: AppDimens.gapMd),
                          if (t.totalWash > 0 && (t.washPrice ?? 0) > 0)
                            _pricingRow(
                              'Wash (${t.totalWash} x ₹${t.washPrice!.toStringAsFixed(0)})',
                              '₹${(t.totalWash * t.washPrice!).toStringAsFixed(0)}',
                            ),
                          if (t.totalPress > 0 && (t.pressPrice ?? 0) > 0)
                            _pricingRow(
                              'Press (${t.totalPress} x ₹${t.pressPrice!.toStringAsFixed(0)})',
                              '₹${(t.totalPress * t.pressPrice!).toStringAsFixed(0)}',
                            ),
                          if (t.blanket > 0 && (t.blanketPrice ?? 0) > 0)
                            _pricingRow(
                              'Blanket (${t.blanket} x ₹${t.blanketPrice!.toStringAsFixed(0)})',
                              '₹${(t.blanket * t.blanketPrice!).toStringAsFixed(0)}',
                            ),
                          if (t.jacket > 0 && (t.jacketPrice ?? 0) > 0)
                            _pricingRow(
                              'Jacket (${t.jacket} x ₹${t.jacketPrice!.toStringAsFixed(0)})',
                              '₹${(t.jacket * t.jacketPrice!).toStringAsFixed(0)}',
                            ),
                          if (t.bedSheet > 0 && (t.bedSheetPrice ?? 0) > 0)
                            _pricingRow(
                              'Bed Sheet (${t.bedSheet} x ₹${t.bedSheetPrice!.toStringAsFixed(0)})',
                              '₹${(t.bedSheet * t.bedSheetPrice!).toStringAsFixed(0)}',
                            ),
                          const Divider(height: AppDimens.gapLg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Payable',
                                style: AppTextStyles.subtitle.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '₹${t.totalPrice.toStringAsFixed(0)}',
                                style: AppTextStyles.title.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      }),
    );
  }

  Widget _buildLifecycleButton(BuildContext context, LaundryTicketModel ticket) {
    switch (ticket.status) {
      case LaundryStatus.pending:
        return AppButton(
          label: 'Accept Order (Advance to Stage 2)',
          icon: Icons.check_circle_outline_rounded,
          onPressed: controller.acceptTicket,
        );
      case LaundryStatus.accepted:
        return AppButton(
          label: 'Mark Washed & Enter Rates (Stage 3)',
          icon: Icons.local_laundry_service_outlined,
          onPressed: () => _showMarkWashedSheet(context, ticket),
        );
      case LaundryStatus.washed:
        return AppButton(
          label: 'Mark Delivered & Completed (Stage 4)',
          icon: Icons.done_all_rounded,
          onPressed: controller.markReceived,
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
                'Order Fully Completed & Delivered',
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

  void _showMarkWashedSheet(BuildContext context, LaundryTicketModel ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailMarkWashedSheet(
        ticket: ticket,
        onConfirm: (washP, pressP, blanketP, jacketP, bedP) {
          controller.markWashed(
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricingRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySm),
          Text(
            amount,
            style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CategoryDetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<_ItemCountRow> items;
  final String? unitPrice;

  const _CategoryDetailCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
    this.unitPrice,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: AppDimens.gapSm),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (unitPrice != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: Text(
                    unitPrice!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: AppDimens.gapLg),
          for (final it in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(it.label, style: AppTextStyles.bodySm),
                  Row(
                    children: [
                      if (it.price != null) ...[
                        Text(
                          '(${it.price})',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusPill),
                        ),
                        child: Text(
                          '${it.count}',
                          style: AppTextStyles.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemCountRow {
  final String label;
  final int count;
  final String? price;

  const _ItemCountRow(this.label, this.count, {this.price});
}

class _DetailMarkWashedSheet extends StatefulWidget {
  final LaundryTicketModel ticket;
  final void Function(
    double washP,
    double pressP,
    double blanketP,
    double jacketP,
    double bedP,
  ) onConfirm;

  const _DetailMarkWashedSheet({
    required this.ticket,
    required this.onConfirm,
  });

  @override
  State<_DetailMarkWashedSheet> createState() => _DetailMarkWashedSheetState();
}

class _DetailMarkWashedSheetState extends State<_DetailMarkWashedSheet> {
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
              AppTextField(
                controller: _washPriceController,
                label: 'Wash Rate (${widget.ticket.totalWash} items)',
                prefixIcon: Icons.currency_rupee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppDimens.gapMd),
            ],

            if (widget.ticket.totalPress > 0) ...[
              AppTextField(
                controller: _pressPriceController,
                label: 'Press Rate (${widget.ticket.totalPress} items)',
                prefixIcon: Icons.currency_rupee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppDimens.gapMd),
            ],

            if (widget.ticket.blanket > 0) ...[
              AppTextField(
                controller: _blanketPriceController,
                label: 'Blanket Rate (${widget.ticket.blanket} items)',
                prefixIcon: Icons.currency_rupee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppDimens.gapMd),
            ],

            if (widget.ticket.jacket > 0) ...[
              AppTextField(
                controller: _jacketPriceController,
                label: 'Jacket Rate (${widget.ticket.jacket} items)',
                prefixIcon: Icons.currency_rupee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppDimens.gapMd),
            ],

            if (widget.ticket.bedSheet > 0) ...[
              AppTextField(
                controller: _bedSheetPriceController,
                label: 'Bed Sheet Rate (${widget.ticket.bedSheet} items)',
                prefixIcon: Icons.currency_rupee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
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
                final wp = double.tryParse(_washPriceController.text.trim()) ?? 0;
                final pp = double.tryParse(_pressPriceController.text.trim()) ?? 0;
                final bp = double.tryParse(_blanketPriceController.text.trim()) ?? 0;
                final jp = double.tryParse(_jacketPriceController.text.trim()) ?? 0;
                final bsp = double.tryParse(_bedSheetPriceController.text.trim()) ?? 0;

                Navigator.of(context).pop();
                widget.onConfirm(wp, pp, bp, jp, bsp);
              },
            ),
          ],
        ),
      ),
    );
  }
}
