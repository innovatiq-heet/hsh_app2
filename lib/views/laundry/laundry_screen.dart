import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/laundry_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/laundry/laundry_responses.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/icon_badge.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/status_badge.dart';
import 'laundry_controller.dart';

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
            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  GradientHeader(
                    overline: 'Laundry',
                    title: 'Wash & Wear',
                    child: Row(
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
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      AppDimens.gapXl,
                      AppDimens.screenPadding,
                      100,
                    ),
                    child: controller.tickets.isEmpty
                        ? const EmptyState(
                            icon: Icons.checkroom_outlined,
                            title: 'No laundry tickets yet',
                            message:
                                'Drop your clothes off and create a ticket to track them.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SectionHeader(title: 'Your tickets'),
                              for (final t in controller.tickets)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppDimens.gapMd,
                                  ),
                                  child: _TicketCard(ticket: t),
                                ),
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
          builder: (_) => const _NewTicketSheet(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New ticket'),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final LaundryTicketResponse ticket;

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
                    Text(
                      '${ticket.itemCount} items  ·  ₹${ticket.totalAmount.toStringAsFixed(0)}',
                      style: AppTextStyles.subtitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatting.dateTime(ticket.submittedAt),
                      style: AppTextStyles.bodySm,
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
          const SizedBox(height: AppDimens.gapLg),
          _StageBar(status: ticket.status),
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

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet();

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  static const _pricePerItem = 10;

  final _noteController = TextEditingController();
  int _items = 1;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LaundryController>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        0,
        AppDimens.screenPadding,
        MediaQuery.viewInsetsOf(context).bottom + AppDimens.gapXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New laundry ticket', style: AppTextStyles.headline),
          const SizedBox(height: 4),
          Text(
            'Count the items you are dropping off.',
            style: AppTextStyles.bodySm,
          ),
          const SizedBox(height: AppDimens.gapXl),
          Container(
            padding: const EdgeInsets.all(AppDimens.gapLg),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Items', style: AppTextStyles.label),
                      Text(
                        'Total ₹${_items * _pricePerItem}',
                        style: AppTextStyles.subtitle,
                      ),
                    ],
                  ),
                ),
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onPressed: _items > 1 ? () => setState(() => _items--) : null,
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '$_items',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displayMd,
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onPressed: _items < 50
                      ? () => setState(() => _items++)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),
          AppTextField(
            controller: _noteController,
            label: 'Note (optional)',
            maxLines: 2,
          ),
          const SizedBox(height: AppDimens.gapXl),
          Obx(
            () => AppButton(
              label: 'Create ticket',
              icon: Icons.check_rounded,
              isLoading: controller.isSubmitting.value,
              onPressed: () async {
                await controller.submit(_items, _noteController.text.trim());
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepperButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.surface.withValues(alpha: 0.6),
      ),
      icon: Icon(icon),
    );
  }
}
