import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/laundry_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
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
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Hero Gradient Header
              GradientHeader(
                overline: 'Ticket #${t.id}',
                title: 'Ticket Details',
                subtitle: t.studentName.isNotEmpty
                    ? '${t.studentName}${t.room.isNotEmpty ? ' · Room ${t.room}' : ''}'
                    : 'Aadhar: ${t.aadhar}',
                leading: Material(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
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
              // 4-Stage Lifecycle Stepper
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Progress', style: AppTextStyles.subtitle),
                    const SizedBox(height: AppDimens.gapMd),
                    StepperTimeline(
                      stages: [
                        TimelineStage(
                          label: 'Submitted',
                          timestamp: t.submittedAt,
                          isDone: true,
                        ),
                        TimelineStage(
                          label: 'Accepted',
                          timestamp: t.acceptedAt,
                          isDone: t.acceptedAt != null,
                        ),
                        TimelineStage(
                          label: 'Washed',
                          timestamp: t.washedAt,
                          isDone: t.washedAt != null,
                        ),
                        TimelineStage(
                          label: 'Received',
                          timestamp: t.receivedAt,
                          isDone: t.receivedAt != null,
                        ),
                      ],
                    ),
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
                    if (t.acceptedAt != null)
                      _row('Accepted At', DateFormatting.dateTime(t.acceptedAt!)),
                    if (t.washedAt != null)
                      _row('Washed At', DateFormatting.dateTime(t.washedAt!)),
                    if (t.receivedAt != null)
                      _row('Received At', DateFormatting.dateTime(t.receivedAt!)),
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
                    const Divider(height: AppDimens.gapLg),
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
              ],
            ),
          );
        }),
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
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySm),
          Text(
            value,
            style: AppTextStyles.bodySm.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (unitPrice != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
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
