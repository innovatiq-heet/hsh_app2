import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/request/laundry/submit_laundry_request.dart';
import '../shared/widgets/app_button.dart';

class SubmitLaundryTicketSheet extends StatefulWidget {
  final VoidCallback? onSuccess;

  const SubmitLaundryTicketSheet({super.key, this.onSuccess});

  @override
  State<SubmitLaundryTicketSheet> createState() =>
      _SubmitLaundryTicketSheetState();
}

class _SubmitLaundryTicketSheetState extends State<SubmitLaundryTicketSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  final LaundryRepository _repository = Get.find();
  bool _isSubmitting = false;

  // Wash counts
  int _pants = 0;
  int _shirts = 0;
  int _tShirts = 0;
  int _towels = 0;
  int _others = 0;

  // Press counts
  int _pressPants = 0;
  int _pressShirts = 0;
  int _pressTShirts = 0;
  int _pressTowels = 0;
  int _pressOthers = 0;

  // Special counts
  int _blanket = 0;
  int _jacket = 0;
  int _bedSheet = 0;

  int get _totalWash =>
      _pants + _shirts + _tShirts + _towels + _others;
  int get _totalPress =>
      _pressPants + _pressShirts + _pressTShirts + _pressTowels + _pressOthers;
  int get _totalSpecial => _blanket + _jacket + _bedSheet;
  int get _totalAll => _totalWash + _totalPress + _totalSpecial;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_totalAll <= 0) {
      Get.snackbar(
        'No items selected',
        'Please add at least 1 garment to submit a ticket.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _repository.submit(
        SubmitLaundryTicketRequest(
          pants: _pants,
          pressPants: _pressPants,
          shirts: _shirts,
          pressShirts: _pressShirts,
          tShirts: _tShirts,
          pressTShirts: _pressTShirts,
          towels: _towels,
          pressTowels: _pressTowels,
          others: _others,
          pressOthers: _pressOthers,
          blanket: _blanket,
          jacket: _jacket,
          bedSheet: _bedSheet,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess?.call();
        Get.snackbar(
          'Ticket Created',
          'Your laundry ticket with $_totalAll items was submitted successfully.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.successGreen.withValues(alpha: 0.15),
          colorText: AppColors.textPrimary,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.gapLg,
              AppDimens.screenPadding,
              AppDimens.gapSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Laundry Drop-off', style: AppTextStyles.headline),
                      const SizedBox(height: 2),
                      Text(
                        'Select garment counts for wash, press, and special care',
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Segmented Tabs for Wash, Press, Special
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.screenPadding,
              vertical: AppDimens.gapSm,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
              child: TabBar(
                controller: _tabController,
                tabAlignment: TabAlignment.fill,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: AppTextStyles.subtitle.copyWith(fontSize: 13),
                tabs: [
                  Tab(text: 'Wash ($_totalWash)'),
                  Tab(text: 'Press ($_totalPress)'),
                  Tab(text: 'Special ($_totalSpecial)'),
                ],
              ),
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Wash Items List
                ListView(
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  children: [
                    _garmentCounter(
                      label: 'Pants (Wash)',
                      icon: Icons.dry_cleaning_outlined,
                      count: _pants,
                      onChanged: (v) => setState(() => _pants = v),
                    ),
                    _garmentCounter(
                      label: 'Shirts (Wash)',
                      icon: Icons.checkroom_outlined,
                      count: _shirts,
                      onChanged: (v) => setState(() => _shirts = v),
                    ),
                    _garmentCounter(
                      label: 'T-Shirts (Wash)',
                      icon: Icons.accessibility_new_outlined,
                      count: _tShirts,
                      onChanged: (v) => setState(() => _tShirts = v),
                    ),
                    _garmentCounter(
                      label: 'Towels (Wash)',
                      icon: Icons.beach_access_outlined,
                      count: _towels,
                      onChanged: (v) => setState(() => _towels = v),
                    ),
                    _garmentCounter(
                      label: 'Others (Wash)',
                      icon: Icons.more_horiz_rounded,
                      count: _others,
                      onChanged: (v) => setState(() => _others = v),
                    ),
                  ],
                ),

                // Press Items List
                ListView(
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  children: [
                    _garmentCounter(
                      label: 'Pants (Press)',
                      icon: Icons.iron_outlined,
                      count: _pressPants,
                      onChanged: (v) => setState(() => _pressPants = v),
                    ),
                    _garmentCounter(
                      label: 'Shirts (Press)',
                      icon: Icons.iron_outlined,
                      count: _pressShirts,
                      onChanged: (v) => setState(() => _pressShirts = v),
                    ),
                    _garmentCounter(
                      label: 'T-Shirts (Press)',
                      icon: Icons.iron_outlined,
                      count: _pressTShirts,
                      onChanged: (v) => setState(() => _pressTShirts = v),
                    ),
                    _garmentCounter(
                      label: 'Towels (Press)',
                      icon: Icons.iron_outlined,
                      count: _pressTowels,
                      onChanged: (v) => setState(() => _pressTowels = v),
                    ),
                    _garmentCounter(
                      label: 'Others (Press)',
                      icon: Icons.iron_outlined,
                      count: _pressOthers,
                      onChanged: (v) => setState(() => _pressOthers = v),
                    ),
                  ],
                ),

                // Special Items List
                ListView(
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  children: [
                    _garmentCounter(
                      label: 'Blanket',
                      icon: Icons.single_bed_outlined,
                      count: _blanket,
                      onChanged: (v) => setState(() => _blanket = v),
                    ),
                    _garmentCounter(
                      label: 'Jacket',
                      icon: Icons.wb_twilight_outlined,
                      count: _jacket,
                      onChanged: (v) => setState(() => _jacket = v),
                    ),
                    _garmentCounter(
                      label: 'Bed Sheet',
                      icon: Icons.bed_outlined,
                      count: _bedSheet,
                      onChanged: (v) => setState(() => _bedSheet = v),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom sticky summary bar and submit button
          Container(
            padding: const EdgeInsets.all(AppDimens.screenPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.checkroom_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Total items:',
                            style: AppTextStyles.subtitle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusPill),
                        ),
                        child: Text(
                          '$_totalAll garments',
                          style: AppTextStyles.subtitle.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  AppButton(
                    label: 'Submit Laundry Ticket',
                    icon: Icons.check_circle_outline_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _garmentCounter({
    required String label,
    required IconData icon,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.gapMd),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.gapMd,
        vertical: AppDimens.gapSm + 2,
      ),
      decoration: BoxDecoration(
        color: count > 0
            ? AppColors.primarySoft.withValues(alpha: 0.4)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: count > 0
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: count > 0 ? AppColors.primary : AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: count > 0 ? Colors.white : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: count > 0 ? FontWeight.w700 : FontWeight.w500,
                color: count > 0
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          IconButton.filled(
            onPressed: count > 0 ? () => onChanged(count - 1) : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              disabledBackgroundColor:
                  AppColors.surface.withValues(alpha: 0.5),
            ),
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(
                color: count > 0 ? AppColors.primary : AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton.filled(
            onPressed: count < 50 ? () => onChanged(count + 1) : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
