import 'package:flutter/material.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/utils/string_formatting.dart';
import 'phonebook_style_widgets.dart';

/// The students picked on a form; see [SelectedList].
class SelectedStudentsList extends StatelessWidget {
  final List<PickableStudent> students;
  final ValueChanged<PickableStudent> onRemove;
  final VoidCallback onClear;

  const SelectedStudentsList({
    super.key,
    required this.students,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SelectedList(
      noun: 'student',
      onClear: onClear,
      entries: [for (final s in students) _entry(s)],
    );
  }

  SelectedEntry _entry(PickableStudent student) {
    final name = formatPersonName(student.name);
    final alumni = student.isAlumni;
    final tone = alumni ? PhonebookTheme.purple : PhonebookTheme.blue;
    return SelectedEntry(
      id: student.id,
      title: name,
      subtitle: alumni ? 'Alumni' : (student.room.isEmpty ? '' : 'Room ${student.room}'),
      subtitleColor: alumni ? tone : null,
      leadingColor: alumni ? PhonebookTheme.purpleSoft : PhonebookTheme.blueSoft,
      leading: Text(
        nameInitials(name),
        style: AppTextStyles.label.copyWith(color: tone, fontWeight: FontWeight.w700),
      ),
      onRemove: () => onRemove(student),
    );
  }
}

/// One row of a [SelectedList].
class SelectedEntry {
  final Object id;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final Widget leading;
  final Color leadingColor;
  final VoidCallback onRemove;

  const SelectedEntry({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.subtitleColor,
    required this.leading,
    required this.leadingColor,
    required this.onRemove,
  });
}

/// What has been picked on a form: a box that opens to compact rows with a
/// remove button each. Closed, it shows the count and the names on one line.
class SelectedList extends StatefulWidget {
  /// What is listed, e.g. "student" (an "s" is added for more than one).
  final String noun;
  final List<SelectedEntry> entries;
  final VoidCallback onClear;

  /// Longer open lists get a second "Collapse" button at the bottom.
  static const footerAbove = 5;

  const SelectedList({super.key, required this.noun, required this.entries, required this.onClear});

  @override
  State<SelectedList> createState() => _SelectedListState();
}

class _SelectedListState extends State<SelectedList> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final radius = BorderRadius.circular(AppDimens.radiusMd);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
      // In front, so the rows never paint over the rounded border.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: PhonebookTheme.border),
      ),
      child: Column(
        children: [
          _buildHeader(),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 62, color: PhonebookTheme.border),
                        _SelectedRow(key: ValueKey(entries[i].id), entry: entries[i]),
                      ],
                      if (entries.length > SelectedList.footerAbove) _buildFooter(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Tapping anywhere on it, except "Clear all", opens or closes the box.
  Widget _buildHeader() {
    final total = widget.entries.length;
    return Material(
      color: PhonebookTheme.blueSoft,
      child: Semantics(
        button: true,
        expanded: _expanded,
        child: InkWell(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 17, color: PhonebookTheme.blue),
                  const SizedBox(width: AppDimens.gapSm),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$total ${widget.noun}${total == 1 ? '' : 's'} selected',
                          style: AppTextStyles.label.copyWith(color: PhonebookTheme.ink),
                        ),
                        if (!_expanded)
                          Text(
                            widget.entries.map((e) => e.title).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(color: PhonebookTheme.slate),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onClear,
                    style: TextButton.styleFrom(
                      foregroundColor: PhonebookTheme.red,
                      textStyle: AppTextStyles.label,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Clear all'),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: PhonebookTheme.blue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(height: 1, color: PhonebookTheme.border),
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: _toggle,
            child: SizedBox(
              height: 42,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Collapse', style: AppTextStyles.label.copyWith(color: PhonebookTheme.blue)),
                  const SizedBox(width: AppDimens.gapXs),
                  const Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: PhonebookTheme.blue),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedRow extends StatelessWidget {
  final SelectedEntry entry;

  const _SelectedRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: entry.leadingColor, borderRadius: BorderRadius.circular(12)),
            child: entry.leading,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(color: PhonebookTheme.ink, fontSize: 13.5),
                ),
                if (entry.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    style: AppTextStyles.caption.copyWith(color: entry.subtitleColor ?? PhonebookTheme.muted),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove ${entry.title}',
            onPressed: entry.onRemove,
            icon: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: PhonebookTheme.bg, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 16, color: PhonebookTheme.muted),
            ),
          ),
        ],
      ),
    );
  }
}
