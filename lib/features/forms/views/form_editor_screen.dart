import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/utils/string_formatting.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/screens/student_picker_screen.dart';
import '../../shared/widgets/tag_choice_chip.dart';
import '../controllers/form_editor_controller.dart';

/// Poll = blue, Form = indigo, so the choice reads at a glance.
const _pollColor = PhonebookTheme.blue;
const _formColor = Color(0xFF6366F1);

/// Operator → Forms & Polls → New / Edit.
///
/// Kept simple: pick Poll or Form, write it, say who can answer and until
/// when. A poll is one question with options; a form can have several.
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

  Color get _accent => controller.kind.value == FormKind.poll ? _pollColor : _formColor;

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
              child: Obx(() {
                final busy = controller.isLoadingForm.value || controller.isSaving.value;
                final poll = controller.kind.value == FormKind.poll;
                return SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : () => _save(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: PhonebookTheme.border,
                      disabledForegroundColor: PhonebookTheme.muted,
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
                      controller.isEditing ? 'Save changes' : (poll ? 'Create poll' : 'Create form'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }),
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
          final poll = controller.kind.value == FormKind.poll;
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: PhonebookHeaderDelegate(
                  overline: 'Forms & Polls',
                  title: controller.isEditing
                      ? (poll ? 'Edit poll' : 'Edit form')
                      : (poll ? 'New poll' : 'New form'),
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
                      _KindToggle(selected: controller.kind.value, onSelect: controller.setKind),
                      const SizedBox(height: 16),
                      PhonebookCard(
                        child: Column(
                          children: [
                            TextField(
                              controller: controller.titleController,
                              maxLength: 200,
                              buildCounter: _noCounter,
                              textCapitalization: TextCapitalization.sentences,
                              style: _fieldText,
                              decoration: phonebookInputDecoration(
                                label: 'Title',
                                hint: poll ? 'e.g. Dinner poll' : 'e.g. Hostel feedback',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: controller.descriptionController,
                              minLines: 1,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              style: _fieldText,
                              decoration: phonebookInputDecoration(
                                label: 'Description (optional)',
                                hint: 'e.g. Vote before 7 PM',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      PhonebookSectionHeader(
                        title: poll ? 'Question' : 'Questions',
                        actionLabel: poll ? null : 'Add question',
                        actionIcon: Icons.add_rounded,
                        onAction: poll ? null : controller.addQuestion,
                      ),
                      for (var i = 0; i < controller.questions.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _QuestionCard(
                            // The type is part of the key: a card rebuilds from its question when
                            // the type changes, e.g. when a poll takes over a text question.
                            key: ValueKey('${controller.questions[i].id}-${controller.questions[i].type.name}'),
                            index: i,
                            count: controller.questions.length,
                            draft: controller.questions[i],
                            controller: controller,
                            simple: poll,
                          ),
                        ),
                      const SizedBox(height: 8),
                      const PhonebookSectionHeader(title: 'Who can answer'),
                      _AudiencePicker(controller: controller),
                      const SizedBox(height: 20),
                      const PhonebookSectionHeader(title: 'Open from – until'),
                      IntrinsicHeight(
                        child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _TimeTile(
                              label: 'Opens',
                              icon: Icons.play_circle_outline_rounded,
                              color: PhonebookTheme.green,
                              value: DateFormatting.dateTime(controller.startTime.value.toUtc()),
                              onTap: () => _pick(context, controller.startTime),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TimeTile(
                              label: 'Closes',
                              icon: Icons.stop_circle_outlined,
                              color: PhonebookTheme.red,
                              value: DateFormatting.dateTime(controller.endTime.value.toUtc()),
                              onTap: () => _pick(context, controller.endTime),
                            ),
                          ),
                        ],
                      ),
                      ),
                      const SizedBox(height: 20),
                      PhonebookCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        child: Column(
                          children: [
                            _SwitchRow(
                              title: 'Active',
                              subtitle: 'Turn off to pause it',
                              value: controller.isActive.value,
                              onChanged: (v) => controller.isActive.value = v,
                            ),
                            const Divider(height: 1, color: PhonebookTheme.border),
                            _SwitchRow(
                              title: 'Required',
                              subtitle: 'Shown first and marked required',
                              value: controller.isMandatory.value,
                              onChanged: (v) => controller.isMandatory.value = v,
                            ),
                          ],
                        ),
                      ),
                      if (controller.validationError case final problem?) ...[
                        const SizedBox(height: 14),
                        NoticeBanner(icon: Icons.info_outline_rounded, color: PhonebookTheme.slate, message: problem),
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

const _fieldText = TextStyle(color: PhonebookTheme.ink, fontSize: 14);

Widget? _noCounter(BuildContext context, {required int currentLength, required bool isFocused, required int? maxLength}) =>
    null;

IconData _typeIcon(FormFieldType t) => switch (t) {
  FormFieldType.poll => Icons.how_to_vote_rounded,
  FormFieldType.radio => Icons.radio_button_checked_rounded,
  FormFieldType.checkbox => Icons.check_box_rounded,
  FormFieldType.boolean => Icons.toggle_on_rounded,
  FormFieldType.rating => Icons.star_rounded,
  FormFieldType.select => Icons.arrow_drop_down_circle_rounded,
  FormFieldType.text => Icons.short_text_rounded,
  FormFieldType.textarea => Icons.notes_rounded,
  FormFieldType.number => Icons.pin_rounded,
};

/// Poll or Form: two big coloured tabs.
class _KindToggle extends StatelessWidget {
  final FormKind selected;
  final ValueChanged<FormKind> onSelect;

  const _KindToggle({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget tab(FormKind kind, IconData icon, String label, String hint, Color color) {
      final isSel = selected == kind;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(kind),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: isSel ? color : color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSel ? color : color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: isSel ? Colors.white : color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isSel ? Colors.white : color,
                          ),
                        ),
                        Text(
                          hint,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSel ? Colors.white.withValues(alpha: 0.85) : PhonebookTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(FormKind.poll, Icons.how_to_vote_rounded, 'Poll', 'One quick question', _pollColor),
        const SizedBox(width: 10),
        tab(FormKind.form, Icons.assignment_rounded, 'Form', 'Several questions', _formColor),
      ],
    );
  }
}

/// One question. A poll shows only the text and its options; a form also
/// shows the answer type, a Required toggle and a menu to move or remove it.
class _QuestionCard extends StatefulWidget {
  final int index;
  final int count;
  final QuestionDraft draft;
  final FormEditorController controller;
  final bool simple;

  const _QuestionCard({
    super.key,
    required this.index,
    required this.count,
    required this.draft,
    required this.controller,
    required this.simple,
  });

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
    final showTools = !widget.simple;
    return PhonebookCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTools) ...[
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _formColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _formColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _TypeMenu(type: d.type, onChanged: (t) => _push(type: t))),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: PhonebookTheme.muted),
                  onSelected: (v) {
                    switch (v) {
                      case 'up':
                        widget.controller.moveQuestion(widget.index, widget.index - 1);
                      case 'down':
                        widget.controller.moveQuestion(widget.index, widget.index + 1);
                      default:
                        widget.controller.removeQuestion(widget.index);
                    }
                  },
                  itemBuilder: (_) => [
                    if (widget.index > 0) _menuItem('up', Icons.arrow_upward_rounded, 'Move up'),
                    if (widget.index < widget.count - 1) _menuItem('down', Icons.arrow_downward_rounded, 'Move down'),
                    _menuItem('remove', Icons.delete_outline_rounded, 'Remove', color: PhonebookTheme.red),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _label,
            onChanged: (_) => _push(),
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: _fieldText,
            decoration: phonebookInputDecoration(
              label: widget.simple ? 'Your question' : 'Question',
              hint: 'e.g. Tonight dinner preference?',
            ),
          ),
          if (d.type.hasOptions) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _options[i],
                  onChanged: (_) => _push(),
                  style: _fieldText,
                  decoration: phonebookInputDecoration(
                    hint: 'Option ${i + 1}',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: Icon(
                      d.type == FormFieldType.checkbox
                          ? Icons.check_box_outline_blank_rounded
                          : Icons.radio_button_off_rounded,
                      size: 20,
                      color: PhonebookTheme.muted,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Remove option',
                      icon: const Icon(Icons.close_rounded, size: 18, color: PhonebookTheme.muted),
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
                style: TextButton.styleFrom(
                  foregroundColor: PhonebookTheme.blue,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add option'),
              ),
            ),
          ],
          if (showTools) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: PhonebookTintChip(
                label: 'Answer required',
                selected: d.required,
                color: PhonebookTheme.red,
                icon: Icons.priority_high_rounded,
                onTap: () => _push(required: !d.required),
              ),
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color? color}) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color ?? PhonebookTheme.slate),
        const SizedBox(width: 10),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    ),
  );
}

/// The answer type as a coloured pill that opens a menu of the nine types.
class _TypeMenu extends StatelessWidget {
  final FormFieldType type;
  final ValueChanged<FormFieldType> onChanged;

  const _TypeMenu({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<FormFieldType>(
        tooltip: 'Answer type',
        onSelected: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        itemBuilder: (_) => [
          for (final t in FormFieldType.values)
            PopupMenuItem(
              value: t,
              child: Row(
                children: [
                  Icon(_typeIcon(t), size: 20, color: t == type ? PhonebookTheme.blue : PhonebookTheme.slate),
                  const SizedBox(width: 10),
                  Text(
                    t.label,
                    style: TextStyle(fontWeight: t == type ? FontWeight.w800 : FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: PhonebookTheme.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PhonebookTheme.blue.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_typeIcon(type), size: 16, color: PhonebookTheme.blue),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: PhonebookTheme.blue),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: PhonebookTheme.blue),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Opens" / "Closes": a label, the date and time, tap to change.
class _TimeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String value;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PhonebookCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // "21 Nov 2026, 07:44 PM" on two lines, so both tiles are the same
          // size whatever the time.
          Text(
            value.split(', ').first,
            maxLines: 1,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: PhonebookTheme.ink),
          ),
          const SizedBox(height: 2),
          Text(
            value.contains(', ') ? value.split(', ').last : '',
            maxLines: 1,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PhonebookTheme.muted),
          ),
        ],
      ),
    );
  }
}

/// One setting: title, one line of explanation and a switch.
class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: PhonebookTheme.blue,
          ),
        ],
      ),
    );
  }
}

/// Who can answer: four coloured choices, and for "Selected" floors, tags
/// and students.
class _AudiencePicker extends StatelessWidget {
  final FormEditorController controller;

  const _AudiencePicker({required this.controller});

  static const _colors = {
    FormAudience.all: PhonebookTheme.blue,
    FormAudience.current: PhonebookTheme.green,
    FormAudience.alumni: PhonebookTheme.purple,
    FormAudience.selected: PhonebookTheme.amber,
  };

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final a = controller.audience.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in FormAudience.values)
                PhonebookTintChip(
                  label: option.label,
                  selected: a == option,
                  color: _colors[option]!,
                  onTap: () => controller.audience.value = option,
                ),
            ],
          ),
          if (a == FormAudience.selected) ...[
            const SizedBox(height: 12),
            PhonebookCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GroupLabel('Floors'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in FormEditorController.floorIds)
                        PhonebookTintChip(
                          label: f == 0 ? 'Ground' : 'Floor $f',
                          selected: controller.selectedFloors.contains(f),
                          onTap: () => controller.toggleFloor(f),
                        ),
                    ],
                  ),
                  if (controller.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _GroupLabel('Tags'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in controller.tags)
                          TagChoiceChip(
                            tag: t,
                            selected: controller.selectedTagIds.contains(t.id),
                            onTap: () => controller.toggleTag(t.id),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _GroupLabel(
                    'Students',
                    action: TextButton.icon(
                      onPressed: () => StudentPickerScreen.open(context, controller),
                      style: TextButton.styleFrom(
                        foregroundColor: PhonebookTheme.blue,
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                  ),
                  if (controller.selectedStudents.isEmpty)
                    const Text(
                      'None picked. Students matching any floor, tag or name here can answer.',
                      style: TextStyle(fontSize: 12.5, color: PhonebookTheme.muted),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in controller.selectedStudents)
                          InputChip(
                            label: Text(
                              s.room.isEmpty ? formatPersonName(s.name) : '${formatPersonName(s.name)} · ${s.room}',
                            ),
                            labelStyle: const TextStyle(
                              color: PhonebookTheme.ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: PhonebookTheme.blueSoft,
                            side: BorderSide.none,
                            deleteIcon: const Icon(Icons.close_rounded, size: 16),
                            deleteIconColor: PhonebookTheme.muted,
                            onDeleted: () => controller.removeStudent(s),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}

/// Small heading above a chip group, with an optional action.
class _GroupLabel extends StatelessWidget {
  final String title;
  final Widget? action;

  const _GroupLabel(this.title, {this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 30,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: PhonebookTheme.ink),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
