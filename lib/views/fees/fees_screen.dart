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
import '../shared/widgets/icon_badge.dart';
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
        appBar: AppBar(
          title: const Text('Payments'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'Debits'),
              Tab(text: 'Deposits'),
              Tab(text: 'Transactions'),
            ],
          ),
        ),
        body: Obx(
          () => AsyncStateView(
            isLoading: controller.isLoading.value,
            hasError: controller.hasError.value,
            errorMessage: controller.errorMessage.value,
            onRetry: controller.load,
            builder: (context) => TabBarView(
              children: [
                _SummaryTab(controller: controller),
                _DebitsTab(controller: controller),
                _DepositsTab(controller: controller),
                _TransactionsTab(controller: controller),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              Get.toNamed(Routes.feesPayNow)?.then((_) => controller.load()),
          icon: const Icon(Icons.bolt_rounded),
          label: const Text('Pay now'),
        ),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final FeesController controller;

  const _SummaryTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary.value;
    if (summary == null) return const SizedBox.shrink();
    final paidRatio = summary.totalBilled == 0
        ? 0.0
        : (summary.totalApproved / summary.totalBilled).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        AppDimens.gapLg,
        AppDimens.screenPadding,
        100,
      ),
      children: [
        AppCard(
          gradient: AppColors.heroGradient,
          padding: const EdgeInsets.all(AppDimens.gapXl),
          radius: AppDimens.radiusXl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'NET DUE',
                    style: AppTextStyles.overline.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.gapSm),
              Text(
                Money.format(summary.netDue),
                style: AppTextStyles.displayXl.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppDimens.gapXl),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                child: LinearProgressIndicator(
                  value: paidRatio,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppDimens.gapSm),
              Text(
                '${(paidRatio * 100).round()}% of ${Money.format(summary.totalBilled)} paid',
                style: AppTextStyles.bodySm.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapLg),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.receipt_long_outlined,
                value: Money.format(summary.totalBilled),
                label: 'Total billed',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppDimens.gapMd),
            Expanded(
              child: StatTile(
                icon: Icons.verified_outlined,
                value: Money.format(summary.totalApproved),
                label: 'Approved',
                color: AppColors.successGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.gapMd),
        StatTile(
          icon: Icons.savings_outlined,
          value: Money.format(summary.depositBalance),
          label: 'Security deposit balance',
          color: AppColors.secondary,
        ),
      ],
    );
  }
}

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
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.screenPadding,
                  vertical: AppDimens.gapMd,
                ),
                children: [
                  ChoiceChip(
                    label: const Text('All years'),
                    selected: controller.academicYearFilter.value == null,
                    onSelected: (_) =>
                        controller.academicYearFilter.value = null,
                  ),
                  for (final y in years) ...[
                    const SizedBox(width: AppDimens.gapSm),
                    ChoiceChip(
                      label: Text(y),
                      selected: controller.academicYearFilter.value == y,
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
                    title: 'No debits found',
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
                    itemBuilder: (context, i) => _LedgerRow(
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.primary,
                      title: filtered[i].label,
                      subtitle:
                          '${filtered[i].academicYear} · ${DateFormatting.dateOnly(filtered[i].billedAt)}',
                      amount: Money.format(filtered[i].amount),
                    ),
                  ),
          ),
        ],
      );
    });
  }
}

class _DepositsTab extends StatelessWidget {
  final FeesController controller;

  const _DepositsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.deposits.isEmpty) {
        return const EmptyState(
          icon: Icons.savings_outlined,
          title: 'No deposit activity',
          message: 'Security deposit credits and debits will appear here.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.gapLg,
          AppDimens.screenPadding,
          100,
        ),
        itemCount: controller.deposits.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppDimens.gapMd),
        itemBuilder: (context, i) {
          final DepositEntryResponse d = controller.deposits[i];
          final color = d.isCredit
              ? AppColors.successGreen
              : AppColors.cancelledRed;
          return _LedgerRow(
            icon: d.isCredit
                ? Icons.south_west_rounded
                : Icons.north_east_rounded,
            color: color,
            title: d.narration,
            subtitle: DateFormatting.dateOnly(d.date),
            amount: '${d.isCredit ? '+' : '−'}${Money.format(d.amount)}',
            amountColor: color,
          );
        },
      );
    });
  }
}

class _TransactionsTab extends StatelessWidget {
  final FeesController controller;

  const _TransactionsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.transactions.isEmpty) {
        return const EmptyState(
          icon: Icons.receipt_outlined,
          title: 'No transactions yet',
          message: 'Your submitted payment slips will appear here.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.gapLg,
          AppDimens.screenPadding,
          100,
        ),
        itemCount: controller.transactions.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppDimens.gapMd),
        itemBuilder: (context, i) {
          final t = controller.transactions[i];
          final details = [
            if (t.chequeNumber != null) 'Cheque #${t.chequeNumber}',
            if (t.bankName != null) t.bankName!,
          ].join(' · ');
          return AppCard(
            child: Row(
              children: [
                IconBadge(icon: t.type.icon, color: AppColors.primary),
                const SizedBox(width: AppDimens.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Money.format(t.amount), style: AppTextStyles.title),
                      const SizedBox(height: 2),
                      Text(
                        '${t.type.label} · ${DateFormatting.dateOnly(t.submittedAt)}',
                        style: AppTextStyles.bodySm,
                      ),
                      if (details.isNotEmpty)
                        Text(details, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                StatusBadge(label: t.status.label, color: t.status.color),
              ],
            ),
          );
        },
      );
    });
  }
}

class _LedgerRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String amount;
  final Color? amountColor;

  const _LedgerRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          IconBadge(icon: icon, color: color),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.subtitle),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySm),
              ],
            ),
          ),
          Text(
            amount,
            style: AppTextStyles.subtitle.copyWith(
              color: amountColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
