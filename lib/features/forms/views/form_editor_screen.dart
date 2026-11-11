import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/utils/string_formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/date_time_picker_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/student_picker_sheet.dart';
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
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapSm, AppDimens.screenPadding, AppDimens.gapMd),
          child: Obx(() => AppButton(
                label: controller.isEditing ? 'Save changes' : 'Create',
                icon: Icons.check_rounded,
                isLoading: controller.isSaving.value,
                onPressed: controller.isLoadingForm.value ? null : () => _save(context),
              )),
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
            SliverGradientHeader(
              overline: 'Forms & Polls',
              title: controller.isEditing ? 'Edit' : 'New poll or form',
              leading: HeaderIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            if (controller.isLoadingForm.value && !controller.isEditing)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapXl, AppDimens.screenPadding, AppDimens.gapXl),
                sliver: SliverList.list(children: [
                  if (controller.isEditing && (controller.original.value?.totalResponded ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.gapLg),
                      child: Text(
                        '${controller.original.value!.totalResponded} students already answered. '
                        'Changing questions or options can make their answers no longer match.',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.warningOrange),
                      ),
                    ),
                  SegmentedButton<FormKind>(
                    segments: const [
                      ButtonSegment(value: FormKind.poll, icon: Icon(Icons.how_to_vote_rounded), label: Text('Poll')),
                      ButtonSegment(value: FormKind.form, icon: Icon(Icons.assignment_rounded), label: Text('Form')),
                    ],
                    selected: {controller.kind.value},
                    onSelectionChanged: (s) => controller.setKind(s.first),
                  ),
                  const SizedBox(height: AppDimens.gapLg),
                  AppCard(
                    child: Column(children: [
                      TextField(
                        controller: controller.titleController,
                        maxLength: 200,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Dinner Poll'),
                      ),
                      TextField(
                        controller: controller.descriptionController,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'e.g. Vote before 7 PM'),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppDimens.gapXl),
                  SectionHeader(
                    title: controller.kind.value == FormKind.poll ? 'Question' : 'Questions',
                    actionLabel: 'Add question',
                    onAction: controller.addQuestion,
                  ),
                  for (var i = 0; i < controller.questions.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                      child: _QuestionCard(
                        key: ValueKey(controller.questions[i].id),
                        index: i,
                        count: controller.questions.length,
                        draft: controller.questions[i],
                        controller: controller,
                      ),
                    ),
                  const SizedBox(height: AppDimens.gapLg),
                  const SectionHeader(title: 'Who can answer'),
                  _AudiencePicker(controller: controller),
                  const SizedBox(height: AppDimens.gapXl),
                  const SectionHeader(title: 'Open from – until'),
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
                  const SizedBox(height: AppDimens.gapLg),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapMd),
                    child: Column(children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        subtitle: const Text('Off = paused, students can’t answer'),
                        value: controller.isActive.value,
                        onChanged: (v) => controller.isActive.value = v,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Required'),
                        subtitle: const Text('Shown first and marked required for students'),
                        value: controller.isMandatory.value,
                        onChanged: (v) => controller.isMandatory.value = v,
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  if (controller.validationError case final problem?)
                    Text(problem, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                ]),
              ),
          ],
        );
      }),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Q${widget.index + 1}', style: AppTextStyles.label.copyWith(color: AppColors.primaryLight)),
            const Spacer(),
            IconButton(
              tooltip: 'Move up',
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              onPressed: widget.index == 0 ? null : () => widget.controller.moveQuestion(widget.index, widget.index - 1),
            ),
            IconButton(
              tooltip: 'Move down',
              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              onPressed: widget.index == widget.count - 1
                  ? null
                  : () => widget.controller.moveQuestion(widget.index, widget.index + 1),
            ),
            IconButton(
              tooltip: 'Remove question',
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.errorRed),
              onPressed: () => widget.controller.removeQuestion(widget.index),
            ),
          ]),
          TextField(
            controller: _label,
            onChanged: (_) => _push(),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Question', hintText: 'e.g. Tonight dinner preference?'),
          ),
          const SizedBox(height: AppDimens.gapSm),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<FormFieldType>(
                initialValue: d.type,
                decoration: const InputDecoration(labelText: 'Answer type'),
                items: [for (final t in FormFieldType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                onChanged: (t) => _push(type: t),
              ),
            ),
            const SizedBox(width: AppDimens.gapSm),
            Column(children: [
              Text('Required', style: AppTextStyles.caption),
              Switch(value: d.required, onChanged: (v) => _push(required: v)),
            ]),
          ]),
          if (d.type.hasOptions) ...[
            const SizedBox(height: AppDimens.gapSm),
            for (var i = 0; i < _options.length; i++)
              Row(children: [
                Icon(
                  d.type == FormFieldType.checkbox ? Icons.check_box_outline_blank_rounded : Icons.radio_button_off_rounded,
                  size: 18,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: AppDimens.gapSm),
                Expanded(
                  child: TextField(
                    controller: _options[i],
                    onChanged: (_) => _push(),
                    decoration: InputDecoration(hintText: 'Option ${i + 1}', isDense: true),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove option',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: _options.length <= d.type.minOptions
                      ? null
                      : () {
                          _options.removeAt(i).dispose();
                          _push();
                        },
                ),
              ]),
            TextButton.icon(
              onPressed: () {
                _options.add(TextEditingController());
                _push();
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add option'),
            ),
          ],
        ],
      ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: AppDimens.gapSm, runSpacing: AppDimens.gapSm, children: [
            for (final option in FormAudience.values)
              ChoiceChip(
                label: Text(option.label),
                selected: a == option,
                onSelected: (_) => controller.audience.value = option,
              ),
          ]),
          if (a == FormAudience.selected) ...[
            const SizedBox(height: AppDimens.gapLg),
            Text('Students with any of these, combined', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppDimens.gapSm),
            Text('Floors', style: AppTextStyles.label),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final f in FormEditorController.floorIds)
                FilterChip(
                  label: Text(f == 0 ? 'Ground' : 'Floor $f'),
                  selected: controller.selectedFloors.contains(f),
                  onSelected: (_) => controller.toggleFloor(f),
                ),
            ]),
            if (controller.tags.isNotEmpty) ...[
              const SizedBox(height: AppDimens.gapMd),
              Text('Tags', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in controller.tags)
                  FilterChip(
                    avatar: Icon(Icons.label_rounded, size: 16, color: t.color),
                    label: Text('${t.name} · ${t.studentCount}'),
                    selected: controller.selectedTagIds.contains(t.id),
                    selectedColor: t.backgroundColor,
                    onSelected: (_) => controller.toggleTag(t.id),
                  ),
              ]),
            ],
            const SizedBox(height: AppDimens.gapMd),
            Row(children: [
              Expanded(child: Text('Students', style: AppTextStyles.label)),
              TextButton.icon(
                onPressed: () => StudentPickerSheet.show(context, controller),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add students'),
              ),
            ]),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in controller.selectedStudents)
                InputChip(
                  label: Text(s.room.isEmpty ? formatPersonName(s.name) : '${formatPersonName(s.name)} · ${s.room}'),
                  onDeleted: () => controller.removeStudent(s),
                ),
            ]),
          ],
        ],
      );
    });
  }
}
