import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/utils/string_formatting.dart';
import '../../shared/widgets/date_time_picker_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/student_picker_sheet.dart';
import '../../shared/widgets/tag_choice_chip.dart';
import '../controllers/form_editor_controller.dart';

/// Operator → Forms & Polls → New / Edit.
class FormEditorScreen extends GetView<FormEditorController> {
  const FormEditorScreen({super.key});

  Future<void> _pick(BuildContext context, Rx<DateTime> target) async {
    final current = target.value;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null) return;
    target.value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save(BuildContext context) async {
    final editing = controller.isEditing;
    if (!await controller.save() || !context.mounted) return;
    AppSnackbar.success(editing ? 'Saved' : 'Created', '"${controller.title.value.trim()}" is saved.');
    // Close with Navigator, not Get.back(): that would close the snackbar.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PhonebookTheme.bg,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: PhonebookTheme.ink.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Obx(
                () => SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: (controller.isLoadingForm.value || controller.isSaving.value)
                        ? null
                        : () => _save(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PhonebookTheme.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: controller.isSaving.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      controller.isEditing ? 'Save changes' : 'Create',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Obx(() {
          if (controller.loadError.value != null) {
            return Center(
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load this form',
                message: controller.loadError.value,
              ),
            );
          }
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: PhonebookHeaderDelegate(
                  overline: 'Forms & Polls',
                  title: controller.isEditing ? 'Edit' : 'New poll or form',
                  topPadding: MediaQuery.of(context).padding.top,
                  leadingIcon: Icons.close_rounded,
                  leadingTooltip: 'Close',
                  onLeadingTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              if (controller.isLoadingForm.value && !controller.isEditing)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: PhonebookTheme.blue)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  sliver: SliverList.list(
                    children: [
                      if (controller.isEditing && (controller.original.value?.totalResponded ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: NoticeBanner(
                            icon: Icons.warning_amber_rounded,
                            color: AppColors.warningOrange,
                            message:
                                '${controller.original.value!.totalResponded} students already answered. '
                                'Changing questions or options can make their answers no longer match.',
                          ),
                        ),
                      _KindToggle(
                        selected: controller.kind.value,
                        onSelect: controller.setKind,
                      ),
                      const SizedBox(height: 16),
                      PhonebookCard(
                        child: Column(
                          children: [
                            TextField(
                              controller: controller.titleController,
                              maxLength: 200,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Dinner Poll'),
                            ),
                            const SizedBox(height: AppDimens.gapSm),
                            TextField(
                              controller: controller.descriptionController,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Description (optional)',
                                hintText: 'e.g. Vote before 7 PM',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      PhonebookSectionHeader(
                        title: controller.kind.value == FormKind.poll ? 'Question' : 'Questions',
                        actionLabel: 'Add question',
                        actionIcon: Icons.add_rounded,
                        onAction: controller.addQuestion,
                      ),
                      for (var i = 0; i < controller.questions.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _QuestionCard(
                            key: ValueKey(controller.questions[i].id),
                            index: i,
                            count: controller.questions.length,
                            draft: controller.questions[i],
                            controller: controller,
                          ),
                        ),
                      const SizedBox(height: 10),
                      const PhonebookSectionHeader(title: 'Who can answer'),
                      _AudiencePicker(controller: controller),
                      const SizedBox(height: 18),
                      const PhonebookSectionHeader(title: 'Open from – until'),
                      DateTimePickerField(
                        label: 'Opens',
                        icon: Icons.play_circle_outline_rounded,
                        displayValue: DateFormatting.dateTime(controller.startTime.value.toUtc()),
                        onTap: () => _pick(context, controller.startTime),
                      ),
                      const SizedBox(height: AppDimens.gapSm),
                      DateTimePickerField(
                        label: 'Closes',
                        icon: Icons.stop_circle_outlined,
                        displayValue: DateFormatting.dateTime(controller.endTime.value.toUtc()),
                        onTap: () => _pick(context, controller.endTime),
                      ),
                      const SizedBox(height: 18),
                      const PhonebookSectionHeader(title: 'Settings'),
                      PhonebookCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Column(
                          children: [
                            _SwitchRow(
                              icon: Icons.play_circle_outline_rounded,
                              title: 'Active',
                              subtitle: 'Off = paused, students can’t answer',
                              value: controller.isActive.value,
                              onChanged: (v) => controller.isActive.value = v,
                            ),
                            const Divider(height: 1, color: PhonebookTheme.border),
                            _SwitchRow(
                              icon: Icons.priority_high_rounded,
                              title: 'Required',
                              subtitle: 'Shown first and marked required for students',
                              value: controller.isMandatory.value,
                              onChanged: (v) => controller.isMandatory.value = v,
                            ),
                          ],
                        ),
                      ),
                      if (controller.validationError case final problem?) ...[
                        const SizedBox(height: 14),
                        NoticeBanner(icon: Icons.info_outline_rounded, color: AppColors.textSecondary, message: problem),
                      ],
                    ],
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  final FormKind selected;
  final ValueChanged<FormKind> onSelect;

  const _KindToggle({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget tab(FormKind kind, IconData icon, String label) {
      final isSel = selected == kind;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(kind),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isSel ? PhonebookTheme.blue : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: PhonebookTheme.blue.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: isSel ? Colors.white : PhonebookTheme.slate),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : PhonebookTheme.slate,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhonebookTheme.border),
        boxShadow: [
          BoxShadow(
            color: PhonebookTheme.ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          tab(FormKind.poll, Icons.how_to_vote_rounded, 'Poll'),
          const SizedBox(width: 4),
          tab(FormKind.form, Icons.assignment_rounded, 'Form'),
        ],
      ),
    );
  }
}

/// Edits one question: text, type, required, options.
class _QuestionCard extends StatefulWidget {
  final int index;
  final int count;
  final QuestionDraft draft;
  final FormEditorController controller;

  const _QuestionCard({super.key, required this.index, required this.count, required this.draft, required this.controller});

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final _label = TextEditingController(text: widget.draft.label);
  late final List<TextEditingController> _options = [
    for (final o in widget.draft.options) TextEditingController(text: o),
  ];

  QuestionDraft get d => widget.draft;

  void _push({FormFieldType? type, bool? required}) {
    final t = type ?? d.type;
    if (t.hasOptions && _options.length < t.minOptions) {
      while (_options.length < t.minOptions) {
        _options.add(TextEditingController());
      }
    }
    widget.controller.updateQuestion(
      widget.index,
      d.copyWith(
        label: _label.text,
        type: t,
        required: required,
        options: [for (final c in _options) c.text],
      ),
    );
    setState(() {});
  }

  @override
  void dispose() {
    _label.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = widget.index == 0;
    final isLast = widget.index == widget.count - 1;
    return PhonebookCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PhonebookTheme.blueSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.index + 1}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: PhonebookTheme.blue),
              ),
            ),
            const SizedBox(width: AppDimens.gapSm),
            Expanded(
              child: Text(d.type.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.subtitle),
            ),
            _CardAction(
              tooltip: 'Move up',
              icon: Icons.arrow_upward_rounded,
              onPressed: isFirst ? null : () => widget.controller.moveQuestion(widget.index, widget.index - 1),
            ),
            _CardAction(
              tooltip: 'Move down',
              icon: Icons.arrow_downward_rounded,
              onPressed: isLast ? null : () => widget.controller.moveQuestion(widget.index, widget.index + 1),
            ),
            _CardAction(
              tooltip: 'Remove question',
              icon: Icons.delete_outline_rounded,
              color: AppColors.errorRed,
              onPressed: () => widget.controller.removeQuestion(widget.index),
            ),
          ]),
          const SizedBox(height: AppDimens.gapMd),
          TextField(
            controller: _label,
            onChanged: (_) => _push(),
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Question', hintText: 'e.g. Tonight dinner preference?'),
          ),
          const SizedBox(height: AppDimens.gapMd),
          DropdownButtonFormField<FormFieldType>(
            initialValue: d.type,
            isExpanded: true,
            style: AppTextStyles.bodyLg,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            decoration: const InputDecoration(labelText: 'Answer type'),
            items: [for (final t in FormFieldType.values) DropdownMenuItem(value: t, child: Text(t.label))],
            onChanged: (t) => _push(type: t),
          ),
          const SizedBox(height: AppDimens.gapXs),
          Row(children: [
            Expanded(child: Text('Answer required', style: AppTextStyles.bodyMd)),
            Switch(value: d.required, onChanged: (v) => _push(required: v)),
          ]),
          if (d.type.hasOptions) ...[
            const SizedBox(height: AppDimens.gapXs),
            Text('Options', style: AppTextStyles.label),
            const SizedBox(height: AppDimens.gapSm),
            for (var i = 0; i < _options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
                child: TextField(
                  controller: _options[i],
                  onChanged: (_) => _push(),
                  style: AppTextStyles.bodyMd,
                  decoration: InputDecoration(
                    hintText: 'Option ${i + 1}',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    prefixIcon: Icon(
                      d.type == FormFieldType.checkbox ? Icons.check_box_outline_blank_rounded : Icons.radio_button_off_rounded,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Remove option',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: _options.length <= d.type.minOptions
                          ? null
                          : () {
                              _options.removeAt(i).dispose();
                              _push();
                            },
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  _options.add(TextEditingController());
                  _push();
                },
                style: TextButton.styleFrom(textStyle: AppTextStyles.label, visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add option'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small icon button in a card header; all the same size.
class _CardAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _CardAction({required this.tooltip, required this.icon, required this.onPressed, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 20, color: onPressed == null ? AppColors.textLight : color),
    );
  }
}

/// Icon, title, explanation and a switch: one setting.
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.gapMd),
      child: Row(children: [
        IconBadge(icon: icon, size: 36, color: value ? AppColors.primaryLight : AppColors.textMuted),
        const SizedBox(width: AppDimens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.bodySm),
            ],
          ),
        ),
        const SizedBox(width: AppDimens.gapSm),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

class _AudiencePicker extends StatelessWidget {
  final FormEditorController controller;

  const _AudiencePicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final a = controller.audience.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final option in FormAudience.values)
                  PhonebookPillTab(
                    label: option.label,
                    selected: a == option,
                    color: PhonebookTheme.blue,
                    onTap: () => controller.audience.value = option,
                  ),
              ],
            ),
          ),
          if (a == FormAudience.selected) ...[
            const SizedBox(height: 12),
            PhonebookCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Students matching any of these', style: AppTextStyles.bodySm),
                  const SizedBox(height: AppDimens.gapLg),
                  const _GroupLabel(icon: Icons.layers_outlined, title: 'Floors'),
                  Wrap(spacing: AppDimens.gapSm, runSpacing: AppDimens.gapSm, children: [
                    for (final f in FormEditorController.floorIds)
                      FilterChip(
                        label: Text(f == 0 ? 'Ground' : 'Floor $f'),
                        selected: controller.selectedFloors.contains(f),
                        onSelected: (_) => controller.toggleFloor(f),
                      ),
                  ]),
                  if (controller.tags.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.symmetric(vertical: AppDimens.gapLg), child: Divider()),
                    const _GroupLabel(icon: Icons.sell_outlined, title: 'Tags'),
                    Wrap(spacing: AppDimens.gapSm, runSpacing: AppDimens.gapSm, children: [
                      for (final t in controller.tags)
                        TagChoiceChip(
                          tag: t,
                          selected: controller.selectedTagIds.contains(t.id),
                          onTap: () => controller.toggleTag(t.id),
                        ),
                    ]),
                  ],
                  const Padding(padding: EdgeInsets.symmetric(vertical: AppDimens.gapLg), child: Divider()),
                  _GroupLabel(
                    icon: Icons.person_outline_rounded,
                    title: 'Students',
                    action: TextButton.icon(
                      onPressed: () => StudentPickerSheet.show(context, controller),
                      style: TextButton.styleFrom(textStyle: AppTextStyles.label, visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                  ),
                  if (controller.selectedStudents.isEmpty)
                    Text('None picked.', style: AppTextStyles.bodySm)
                  else
                    Wrap(spacing: AppDimens.gapSm, runSpacing: AppDimens.gapSm, children: [
                      for (final s in controller.selectedStudents)
                        InputChip(
                          label: Text(s.room.isEmpty ? formatPersonName(s.name) : '${formatPersonName(s.name)} · ${s.room}'),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                          deleteIconColor: AppColors.textMuted,
                          onDeleted: () => controller.removeStudent(s),
                        ),
                    ]),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}

/// Icon + label above a chip group, with an optional action.
class _GroupLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? action;

  const _GroupLabel({required this.icon, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
      child: SizedBox(
        height: 32,
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primaryLight),
          const SizedBox(width: AppDimens.gapSm),
          Expanded(child: Text(title, style: AppTextStyles.subtitle)),
          ?action,
        ]),
      ),
    );
  }
}
