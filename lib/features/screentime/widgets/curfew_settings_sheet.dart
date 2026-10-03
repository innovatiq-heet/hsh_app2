import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';
import '../controllers/student_screen_time_controller.dart';
import 'sheet_scaffold.dart';

/// Bottom sheet for the daily allowance and curfew window.
class CurfewSettingsSheet extends StatefulWidget {
  const CurfewSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => Get.bottomSheet(
        const CurfewSettingsSheet(),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );

  @override
  State<CurfewSettingsSheet> createState() => _CurfewSettingsSheetState();
}

class _CurfewSettingsSheetState extends State<CurfewSettingsSheet> {
  static const _limitPresets = <int>[0, 60, 120, 180, 240, 360];

  final controller = Get.find<StudentScreenTimeController>();
  late int _limit = controller.dailyLimitMinutes.value;
  late TimeOfDay _start = _parse(controller.bedtimeStart.value) ?? const TimeOfDay(hour: 23, minute: 0);
  late TimeOfDay _end = _parse(controller.bedtimeEnd.value) ?? const TimeOfDay(hour: 5, minute: 0);
  late final _customCtrl = TextEditingController(
    text: _limitPresets.contains(_limit) || _limit == 0 ? '' : '$_limit',
  );

  bool get _isCustom => _limit > 0 && !_limitPresets.contains(_limit);

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sameTime = _start == _end;
    final duration = _curfewMinutes();

    return SheetScaffold(
      title: 'Curfew & daily limit',
      subtitle: 'Enforced on the phone itself, even offline.',
      children: [
        // ---- Daily limit ----
        _label('Daily screen-time allowance'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _limitPresets)
              ChoiceChip(
                label: Text(m == 0 ? 'No limit' : StudentScreenTimeController.formatMinutes(m)),
                selected: _limit == m,
                onSelected: (_) => setState(() {
                  _limit = m;
                  _customCtrl.clear();
                }),
                selectedColor: AppColors.primary,
                labelStyle: AppTextStyles.label.copyWith(
                  color: _limit == m ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppColors.surfaceMuted,
                side: BorderSide(color: _limit == m ? AppColors.primary : AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusPill)),
                showCheckmark: false,
              ),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _customCtrl,
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => _limit = int.tryParse(v) ?? 0),
                decoration: InputDecoration(
                  hintText: 'Custom min',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimens.radiusPill)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    borderSide: BorderSide(color: _isCustom ? AppColors.primary : AppColors.border),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _limit > 0
              ? 'Apps stop opening after ${StudentScreenTimeController.formatMinutes(_limit)} of use in a day. Calls still work.'
              : 'The student can use the phone as long as they like outside curfew.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppDimens.gapXl),

        // ---- Curfew ----
        _label('Curfew hours'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _timeField('From', _start, (t) => setState(() => _start = t))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted),
            ),
            Expanded(child: _timeField('Until', _end, (t) => setState(() => _end = t))),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: sameTime ? AppColors.cancelledRed.withValues(alpha: 0.08) : AppColors.secondarySoft,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: Row(
            children: [
              Icon(
                sameTime ? Icons.error_outline_rounded : Icons.nightlight_round,
                size: 18,
                color: sameTime ? AppColors.cancelledRed : AppColors.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sameTime
                      ? 'Start and end can\'t be the same time.'
                      : 'Phone blocked for ${StudentScreenTimeController.formatMinutes(duration)} every night'
                          '${_end.hour < _start.hour ? ' (crosses midnight)' : ''}.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: sameTime ? AppColors.cancelledRed : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapXl),

        AppButton(
          label: 'Save rules',
          icon: Icons.check_rounded,
          onPressed: sameTime
              ? null
              : () {
                  controller.updateCurfewAndLimit(
                    limitMinutes: _limit,
                    startBedtime: _fmt(_start),
                    endBedtime: _fmt(_end),
                  );
                  Get.back();
                },
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text, style: AppTextStyles.subtitle);

  Widget _timeField(String label, TimeOfDay value, ValueChanged<TimeOfDay> onPicked) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: value);
        if (t != null) onPicked(t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(_fmt(value), style: AppTextStyles.headline.copyWith(fontSize: 20)),
                const Spacer(),
                const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _curfewMinutes() {
    final s = _start.hour * 60 + _start.minute;
    final e = _end.hour * 60 + _end.minute;
    return e > s ? e - s : (24 * 60 - s) + e;
  }

  static TimeOfDay? _parse(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
