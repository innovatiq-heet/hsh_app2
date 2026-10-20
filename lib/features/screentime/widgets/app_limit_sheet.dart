import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';
import '../controllers/student_screen_time_controller.dart';
import 'app_brand_icon.dart';
import '../../shared/widgets/sheet_scaffold.dart';

/// Bottom sheet to view and configure the daily screen-time limit for a specific app.
class AppLimitSheet extends StatefulWidget {
  final String packageName;
  final String appName;
  final int initialLimitMinutes;
  final int currentUsageMinutes;

  const AppLimitSheet({
    super.key,
    required this.packageName,
    required this.appName,
    this.initialLimitMinutes = 0,
    this.currentUsageMinutes = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required String packageName,
    required String appName,
    int currentLimit = 0,
    int currentUsage = 0,
  }) {
    return Get.bottomSheet(
      AppLimitSheet(
        packageName: packageName,
        appName: appName,
        initialLimitMinutes: currentLimit,
        currentUsageMinutes: currentUsage,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<AppLimitSheet> createState() => _AppLimitSheetState();
}

class _AppLimitSheetState extends State<AppLimitSheet> {
  static const _limitPresets = <int>[0, 15, 30, 45, 60, 90, 120, 180, 240];

  final controller = Get.find<StudentScreenTimeController>();
  late int _selectedLimit = widget.initialLimitMinutes;
  late final TextEditingController _customCtrl = TextEditingController(
    text: _limitPresets.contains(_selectedLimit) || _selectedLimit == 0
        ? ''
        : '$_selectedLimit',
  );
  bool _isSaving = false;

  bool get _isCustom => _selectedLimit > 0 && !_limitPresets.contains(_selectedLimit);

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(int limit) async {
    setState(() => _isSaving = true);
    try {
      await controller.setAppLimit(widget.packageName, widget.appName, limit);
      if (mounted) Get.back();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final used = widget.currentUsageMinutes;
    final isExceeded = _selectedLimit > 0 && used >= _selectedLimit;
    final remaining = _selectedLimit > used ? _selectedLimit - used : 0;

    return SheetScaffold(
      title: 'App time limit',
      subtitle: 'Enforced automatically on the student\'s phone.',
      children: [
        // App header summary card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              AppBrandIcon(
                packageName: widget.packageName,
                appName: widget.appName,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.appName,
                      style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Used today: ${used > 0 ? StudentScreenTimeController.formatMinutes(used) : "None"}',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (widget.initialLimitMinutes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: Text(
                    'Active: ${StudentScreenTimeController.formatMinutes(widget.initialLimitMinutes)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapLg),

        Text('Daily allowance for this app', style: AppTextStyles.subtitle),
        const SizedBox(height: 8),

        // Presets wrap
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _limitPresets)
              ChoiceChip(
                label: Text(m == 0 ? 'No limit' : StudentScreenTimeController.formatMinutes(m)),
                selected: _selectedLimit == m,
                onSelected: (_) => setState(() {
                  _selectedLimit = m;
                  _customCtrl.clear();
                }),
                selectedColor: AppColors.primary,
                labelStyle: AppTextStyles.label.copyWith(
                  color: _selectedLimit == m ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppColors.surfaceMuted,
                side: BorderSide(
                  color: _selectedLimit == m ? AppColors.primary : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                showCheckmark: false,
              ),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _customCtrl,
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final parsed = int.tryParse(v) ?? 0;
                  setState(() => _selectedLimit = parsed.clamp(0, 1440));
                },
                decoration: InputDecoration(
                  hintText: 'Custom min',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    borderSide: BorderSide(
                      color: _isCustom ? AppColors.primary : AppColors.border,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Context / helper note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isExceeded
                ? AppColors.cancelledRed.withValues(alpha: 0.08)
                : (_selectedLimit > 0 ? AppColors.primarySoft : AppColors.surfaceMuted),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            border: Border.all(
              color: isExceeded
                  ? AppColors.cancelledRed.withValues(alpha: 0.3)
                  : (_selectedLimit > 0 ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isExceeded
                    ? Icons.warning_amber_rounded
                    : (_selectedLimit > 0 ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded),
                size: 18,
                color: isExceeded
                    ? AppColors.cancelledRed
                    : (_selectedLimit > 0 ? AppColors.primary : AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedLimit == 0
                      ? 'No daily time limit for ${widget.appName}. It can be used freely unless blocked or inside curfew.'
                      : (isExceeded
                          ? 'Today\'s usage (${StudentScreenTimeController.formatMinutes(used)}) has already reached this limit. ${widget.appName} will be blocked immediately.'
                          : 'Allowed for ${StudentScreenTimeController.formatMinutes(_selectedLimit)} per day. ${StudentScreenTimeController.formatMinutes(remaining)} left today before automatic block.'),
                  style: AppTextStyles.caption.copyWith(
                    color: isExceeded
                        ? AppColors.cancelledRed
                        : (_selectedLimit > 0 ? AppColors.primary : AppColors.textSecondary),
                    fontWeight: isExceeded ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapXl),

        // Action buttons
        AppButton(
          label: _selectedLimit == 0 ? 'Remove time limit' : 'Save time limit',
          icon: _selectedLimit == 0 ? Icons.remove_circle_outline_rounded : Icons.timer_rounded,
          variant: _selectedLimit == 0 ? AppButtonVariant.outline : AppButtonVariant.primary,
          isLoading: _isSaving,
          onPressed: () => _save(_selectedLimit),
        ),
        if (widget.initialLimitMinutes > 0 && _selectedLimit > 0) ...[
          const SizedBox(height: AppDimens.gapSm),
          AppButton(
            label: 'Remove limit',
            icon: Icons.delete_outline_rounded,
            variant: AppButtonVariant.danger,
            isLoading: _isSaving,
            onPressed: () => _save(0),
          ),
        ],
      ],
    );
  }
}
