import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/payment_type.dart';
import '../../common_enums/transaction_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/fees/fee_responses.dart';
import '../../utils/currency_formatting.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/icon_badge.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/stat_tile.dart';
import '../shared/widgets/status_badge.dart';
import 'fees_controller.dart';

class FeesScreen extends GetView<FeesController> {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: Obx(
          () => AsyncStateView(
            isLoading: controller.isLoading.value,
            hasError: controller.hasError.value,
            errorMessage: controller.errorMessage.value,
            onRetry: controller.load,
            builder: (context) {
              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: GradientHeader(
                        overline: 'Fee Ledger & Billing',
                        title: 'Hostel Payments',
                        subtitle: 'Academic Year 2025–26',
                        leading: HeaderIconButton(
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => Get.back(),
                        ),
                        actions: [
                          HeaderIconButton(
                            icon: Icons.refresh_rounded,
                            tooltip: 'Refresh',
                            onPressed: controller.load,
                          ),
                        ],
                        child: _HeroNetDueCard(controller: controller),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        TabBar(
                          isScrollable: true,
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textSecondary,
                          indicatorColor: AppColors.primary,
                          indicatorWeight: 3,
                          labelStyle: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelStyle: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          tabs: const [
                            Tab(text: 'Summary'),
                            Tab(text: 'Invoices'),
                            Tab(text: 'Deposit Ledger'),
                            Tab(text: 'Transactions'),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  children: [
                    _SummaryTab(controller: controller),
                    _DebitsTab(controller: controller),
                    _DepositsTab(controller: controller),
                    _TransactionsTab(controller: controller),
                  ],
                ),
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              Get.toNamed(Routes.feesPayNow)?.then((_) => controller.load()),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.bolt_rounded),
          label: Text(
            'Pay Now',
            style: AppTextStyles.subtitle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => 48.0;

  @override
  double get maxExtent => 48.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.mainBackground,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}

/// Hero Net Due Card with progress ring and fast action button
class _HeroNetDueCard extends StatelessWidget {
  final FeesController controller;

  const _HeroNetDueCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary.value;
    if (summary == null) return const SizedBox.shrink();

    final paidRatio = summary.totalBilled == 0
        ? 0.0
        : (summary.totalApproved / summary.totalBilled).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppDimens.gapLg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'OUTSTANDING NET DUE',
                style: AppTextStyles.overline.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.netDue > 0
                      ? AppColors.warningOrange.withValues(alpha: 0.3)
                      : AppColors.successGreen.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  border: Border.all(
                    color: summary.netDue > 0
                        ? AppColors.warningOrange
                        : AppColors.successGreen,
                  ),
                ),
                child: Text(
                  summary.netDue > 0 ? 'Pending Dues' : 'Fully Paid',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.format(summary.netDue),
                style: AppTextStyles.displayXl.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: Text(
                  'Pay Now',
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => Get.toNamed(Routes.feesPayNow)
                    ?.then((_) => controller.load()),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapLg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            child: LinearProgressIndicator(
              value: paidRatio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppDimens.gapSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(paidRatio * 100).round()}% of fees cleared',
                style: AppTextStyles.bodySm.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              Text(
                'Approved: ${Money.format(summary.totalApproved)}',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 1. Summary Tab
class _SummaryTab extends StatelessWidget {
  final FeesController controller;

  const _SummaryTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary.value;
    if (summary == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        AppDimens.gapLg,
        AppDimens.screenPadding,
        100,
      ),
      children: [
        // 3 Key Stats
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.receipt_long_outlined,
                value: Money.format(summary.totalBilled),
                label: 'Total Billed',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppDimens.gapMd),
            Expanded(
              child: StatTile(
                icon: Icons.verified_outlined,
                value: Money.format(summary.totalApproved),
                label: 'Total Paid',
                color: AppColors.successGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.gapMd),
        StatTile(
          icon: Icons.savings_outlined,
          value: Money.format(summary.depositBalance),
          label: 'Security Deposit (Refundable on Checkout)',
          color: AppColors.secondary,
        ),

        const SizedBox(height: AppDimens.gapXl),

        // Fee Heads Breakdown
        const SectionHeader(
          title: 'Fee Distribution',
          actionLabel: 'Active Year',
        ),
        const SizedBox(height: AppDimens.gapMd),
        _FeeBreakdownCard(controller: controller),

        const SizedBox(height: AppDimens.gapXl),

        // Recent Payments Section
        SectionHeader(
          title: 'Recent Payments',
          actionLabel: 'View All',
          onAction: () => DefaultTabController.of(context).animateTo(3),
        ),
        const SizedBox(height: AppDimens.gapMd),
        Obx(() {
          final txns = controller.transactions.take(2).toList();
          if (txns.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_outlined,
              title: 'No payments yet',
            );
          }
          return Column(
            children: txns
                .map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                    child: _TransactionCard(
                      transaction: t,
                      onTap: () =>
                          Get.toNamed(Routes.feeReceipt, arguments: t),
                    ),
                  ),
                )
                .toList(),
          );
        }),

        const SizedBox(height: AppDimens.gapLg),

        // Support Notice Card
        AppCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need Payment Assistance?',
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hostel Accounts Office: Mon-Sat 9 AM - 5 PM\nFor RTGS/NEFT slips or cheque verification.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Visual distribution of fee heads (Hostel Fee, Electricity, Maintenance, etc.)
class _FeeBreakdownCard extends StatelessWidget {
  final FeesController controller;

  const _FeeBreakdownCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final debits = controller.debits;
      if (debits.isEmpty) return const SizedBox.shrink();

      final total = debits.fold<double>(0.0, (acc, e) => acc + e.amount);

      return AppCard(
        child: Column(
          children: debits.map((d) {
            final percent = total > 0 ? (d.amount / total) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(d.label, style: AppTextStyles.subtitle),
                      Text(
                        Money.format(d.amount),
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceMuted,
                      color: _colorForLabel(d.label),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(percent * 100).round()}% of total charges · ${d.academicYear}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  Color _colorForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('hostel')) return AppColors.primary;
    if (lower.contains('electric')) return AppColors.warningOrange;
    if (lower.contains('maintenance')) return AppColors.secondary;
    return AppColors.cancelledRed;
  }
}

/// 2. Debits (Invoices) Tab
class _DebitsTab extends StatelessWidget {
  final FeesController controller;

  const _DebitsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final years = controller.academicYears;
      final filtered = controller.filteredDebits;

      return Column(
        children: [
          if (years.isNotEmpty)
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.screenPadding,
                  vertical: AppDimens.gapSm,
                ),
                children: [
                  ChoiceChip(
                    label: const Text('All Years'),
                    selected: controller.academicYearFilter.value == null,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: controller.academicYearFilter.value == null
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => controller.academicYearFilter.value = null,
                  ),
                  for (final y in years) ...[
                    const SizedBox(width: AppDimens.gapSm),
                    ChoiceChip(
                      label: Text(y),
                      selected: controller.academicYearFilter.value == y,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: controller.academicYearFilter.value == y
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) =>
                          controller.academicYearFilter.value = y,
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No invoices found',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      AppDimens.gapSm,
                      AppDimens.screenPadding,
                      100,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDimens.gapMd),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return AppCard(
                        child: Row(
                          children: [
                            IconBadge(
                              icon: Icons.receipt_long_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppDimens.gapMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: AppTextStyles.subtitle.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.academicYear} · Billed on ${DateFormatting.dateOnly(item.billedAt)}',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Money.format(item.amount),
                              style: AppTextStyles.subtitle.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

/// 3. Deposits Tab
class _DepositsTab extends StatelessWidget {
  final FeesController controller;

  const _DepositsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final deposits = controller.deposits;
      final summary = controller.summary.value;

      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.gapLg,
          AppDimens.screenPadding,
          100,
        ),
        children: [
          // Current Security Balance Banner
          if (summary != null)
            AppCard(
              gradient: AppColors.heroGradient,
              padding: const EdgeInsets.all(AppDimens.gapLg),
              radius: AppDimens.radiusLg,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.savings_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SECURITY DEPOSIT BALANCE',
                          style: AppTextStyles.overline.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          Money.format(summary.depositBalance),
                          style: AppTextStyles.displayMd.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppDimens.gapLg),
          const SectionHeader(
            title: 'Deposit Ledger Activity',
            actionLabel: 'Credits & Deductions',
          ),
          const SizedBox(height: AppDimens.gapMd),

          if (deposits.isEmpty)
            const EmptyState(
              icon: Icons.savings_outlined,
              title: 'No deposit activity',
              message: 'Security deposit credits and debits will appear here.',
            )
          else
            ...deposits.map((d) {
              final color = d.isCredit
                  ? AppColors.successGreen
                  : AppColors.cancelledRed;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                child: AppCard(
                  child: Row(
                    children: [
                      IconBadge(
                        icon: d.isCredit
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: color,
                      ),
                      const SizedBox(width: AppDimens.gapMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.narration,
                              style: AppTextStyles.subtitle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormatting.dateOnly(d.date),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${d.isCredit ? '+' : '−'}${Money.format(d.amount)}',
                        style: AppTextStyles.subtitle.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      );
    });
  }
}

/// 4. Transactions Tab
class _TransactionsTab extends StatelessWidget {
  final FeesController controller;

  const _TransactionsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final filtered = controller.filteredTransactions;
      final selectedFilter = controller.transactionStatusFilter.value;

      return Column(
        children: [
          // Filter Chips
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.screenPadding,
                vertical: AppDimens.gapSm,
              ),
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: selectedFilter == null,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selectedFilter == null
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) =>
                      controller.transactionStatusFilter.value = null,
                ),
                for (final status in TransactionStatus.values) ...[
                  const SizedBox(width: AppDimens.gapSm),
                  ChoiceChip(
                    label: Text(status.label),
                    selected: selectedFilter == status,
                    selectedColor: status.color,
                    labelStyle: TextStyle(
                      color: selectedFilter == status
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) =>
                        controller.transactionStatusFilter.value = status,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_outlined,
                    title: 'No transactions found',
                    message: 'Payment slips and receipts will appear here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      AppDimens.gapSm,
                      AppDimens.screenPadding,
                      100,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDimens.gapMd),
                    itemBuilder: (context, i) {
                      final t = filtered[i];
                      return _TransactionCard(
                        transaction: t,
                        onTap: () =>
                            Get.toNamed(Routes.feeReceipt, arguments: t),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

/// Transaction card with method icon, amount, status badge, and click action
class _TransactionCard extends StatelessWidget {
  final FeeTransactionResponse transaction;
  final VoidCallback onTap;

  const _TransactionCard({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      if (transaction.receiptNumber != null) transaction.receiptNumber!,
      if (transaction.transactionRef != null) transaction.transactionRef!,
      if (transaction.chequeNumber != null)
        'Cheque #${transaction.chequeNumber}',
      if (transaction.bankName != null) transaction.bankName!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                IconBadge(
                  icon: transaction.type.icon,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppDimens.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Money.format(transaction.amount),
                        style: AppTextStyles.title.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${transaction.type.label} · ${DateFormatting.dateOnly(transaction.submittedAt)}',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: transaction.status.label,
                  color: transaction.status.color,
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: AppDimens.gapSm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        details,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
