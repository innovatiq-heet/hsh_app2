import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/forms/form_models.dart';
import '../../shared/widgets/status_badge.dart';

/// Active / Upcoming / Expired / Paused.
class FormStatusBadge extends StatelessWidget {
  final FormStatus status;

  const FormStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) => switch (status) {
        FormStatus.active => const StatusBadge(label: 'Active', color: AppColors.successGreen, icon: Icons.play_circle_rounded),
        FormStatus.upcoming => const StatusBadge(label: 'Upcoming', color: AppColors.pendingBlue, icon: Icons.schedule_rounded),
        FormStatus.expired => const StatusBadge(label: 'Ended', color: AppColors.textMuted, icon: Icons.event_busy_rounded),
        FormStatus.disabled => const StatusBadge(label: 'Paused', color: AppColors.warningOrange, icon: Icons.pause_circle_rounded),
        FormStatus.unknown => const SizedBox.shrink(),
      };
}

/// "Poll" or "Form" label.
class FormKindChip extends StatelessWidget {
  final FormKind kind;

  const FormKindChip({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final poll = kind == FormKind.poll;
    final color = poll ? const Color(0xFF7C3AED) : AppColors.primaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(poll ? Icons.how_to_vote_rounded : Icons.assignment_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(poll ? 'Poll' : 'Form', style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// One option's share as a labelled bar.
class BreakdownBar extends StatelessWidget {
  final OptionCount item;
  final bool isTop;

  const BreakdownBar({super.key, required this.item, this.isTop = false});

  @override
  Widget build(BuildContext context) {
    final color = isTop ? AppColors.successGreen : AppColors.primaryLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.option, style: AppTextStyles.bodyMd)),
              Text('${item.count} · ${item.percentage}%',
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            child: LinearProgressIndicator(
              value: (item.percentage.clamp(0, 100)) / 100,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Input for one question on the fill screen. [value] is held by the screen:
/// String for choices/text/number, `Set<String>` for checkbox, bool for
/// yes/no, int for rating.
class AnswerInput extends StatelessWidget {
  final FormFieldDef field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final TextEditingController? textController;

  const AnswerInput({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.textController,
  });

  @override
  Widget build(BuildContext context) {
    return switch (field.type) {
      FormFieldType.poll || FormFieldType.radio => Column(
          children: [
            for (final o in field.options)
              _ChoiceTile(
                label: o,
                selected: value == o,
                multi: false,
                onTap: () => onChanged(o),
              ),
          ],
        ),
      FormFieldType.checkbox => Column(
          children: [
            for (final o in field.options)
              _ChoiceTile(
                label: o,
                selected: (value as Set<String>? ?? const {}).contains(o),
                multi: true,
                onTap: () {
                  final next = {...(value as Set<String>? ?? const <String>{})};
                  if (!next.remove(o)) next.add(o);
                  onChanged(next);
                },
              ),
          ],
        ),
      FormFieldType.select => DropdownButtonFormField<String>(
          initialValue: field.options.contains(value) ? value as String : null,
          items: [for (final o in field.options) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: onChanged,
          decoration: const InputDecoration(hintText: 'Choose'),
        ),
      FormFieldType.boolean => Row(
          children: [
            Expanded(child: _ChoiceTile(label: 'Yes', selected: value == true, multi: false, onTap: () => onChanged(true))),
            const SizedBox(width: AppDimens.gapSm),
            Expanded(child: _ChoiceTile(label: 'No', selected: value == false, multi: false, onTap: () => onChanged(false))),
          ],
        ),
      FormFieldType.rating => Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i',
                onPressed: () => onChanged(i),
                icon: Icon(
                  (value is int && value >= i) ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFF59E0B),
                  size: 34,
                ),
              ),
          ],
        ),
      FormFieldType.number => TextField(
          controller: textController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          onChanged: onChanged,
          decoration: const InputDecoration(hintText: 'Enter a number'),
        ),
      FormFieldType.text || FormFieldType.textarea => TextField(
          controller: textController,
          minLines: field.type == FormFieldType.textarea ? 3 : 1,
          maxLines: field.type == FormFieldType.textarea ? 8 : 1,
          textCapitalization: TextCapitalization.sentences,
          onChanged: onChanged,
          decoration: const InputDecoration(hintText: 'Your answer'),
        ),
    };
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  const _ChoiceTile({required this.label, required this.selected, required this.multi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapMd, vertical: AppDimens.gapMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: selected ? AppColors.primaryLight : AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  multi
                      ? (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                      : (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                  color: selected ? AppColors.primaryLight : AppColors.textLight,
                ),
                const SizedBox(width: AppDimens.gapMd),
                Expanded(child: Text(label, style: AppTextStyles.bodyMd)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A submitted answer shown read-only.
String describeAnswer(FormFieldDef field, dynamic value) {
  if (value == null || (value is String && value.trim().isEmpty) || (value is List && value.isEmpty)) {
    return '—';
  }
  return switch (field.type) {
    FormFieldType.checkbox => value is List ? value.join(', ') : value.toString(),
    FormFieldType.boolean =>
      (value == true || value.toString().toLowerCase() == 'yes' || value.toString() == 'true') ? 'Yes' : 'No',
    FormFieldType.rating => '$value / 5',
    _ => value.toString(),
  };
}
