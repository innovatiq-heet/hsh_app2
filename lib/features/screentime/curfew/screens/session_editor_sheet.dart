import 'package:flutter/material.dart';

import '../curfew_schedule.dart';
import '../models.dart';
import '../widgets/common.dart';

/// Create (existing == null) or edit a session. Returns the draft to save,
/// or null when cancelled. For an edit only the changed fields are set.
Future<SessionDraft?> showSessionEditor(BuildContext context, {CurfewSession? existing}) =>
    showStSheet<SessionDraft>(context, _SessionEditor(existing: existing));

class _SessionEditor extends StatefulWidget {
  const _SessionEditor({this.existing});

  final CurfewSession? existing;

  @override
  State<_SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<_SessionEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? 'Night Curfew');
  late TimeOfDay _start = _parse(widget.existing?.startTime ?? '22:00');
  late TimeOfDay _end = _parse(widget.existing?.endTime ?? '06:00');
  late final Set<String> _days = {...(widget.existing?.days ?? kDayKeys)};
  late bool _active = widget.existing?.isActive ?? true;
  String? _error;

  static TimeOfDay _parse(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  static String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: Theme(
          data: Theme.of(c).copyWith(colorScheme: Theme.of(c).colorScheme.copyWith(primary: StPalette.accent)),
          child: child!,
        ),
      ),
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  void _setDays(Iterable<String> days) => setState(() => _days
    ..clear()
    ..addAll(days));

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 60) return setState(() => _error = 'Name must be 1–60 characters');
    if (_fmt(_start) == _fmt(_end)) return setState(() => _error = 'Start and end time must differ');
    if (_days.isEmpty) return setState(() => _error = 'Pick at least one day');

    final days = kDayKeys.where(_days.contains).toList();
    final e = widget.existing;
    if (e == null) {
      Navigator.pop(context, SessionDraft(name: name, startTime: _fmt(_start), endTime: _fmt(_end), days: days, isActive: _active));
      return;
    }
    Navigator.pop(
      context,
      SessionDraft(
        name: name != e.name ? name : null,
        startTime: _fmt(_start) != e.startTime ? _fmt(_start) : null,
        endTime: _fmt(_end) != e.endTime ? _fmt(_end) : null,
        days: days.join() != e.days.join() ? days : null,
        isActive: _active != e.isActive ? _active : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overnight = _end.hour * 60 + _end.minute < _start.hour * 60 + _start.minute;
    final days = kDayKeys.where(_days.contains).toList();
    final isNew = widget.existing == null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(
            title: isNew ? 'New curfew session' : 'Edit session',
            subtitle: isNew ? 'Phones block apps during this time' : 'Assigned phones update in a few seconds',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            maxLength: 60,
            style: const TextStyle(fontWeight: FontWeight.w600, color: StPalette.ink),
            decoration: stInputDecoration(label: 'Name', hint: 'e.g. Night Curfew, Afternoon Study'),
          ),
          const FieldLabel('Time (IST)'),
          Row(children: [
            Expanded(child: _TimeButton(label: 'Starts', icon: Icons.nightlight_outlined, time: _fmt(_start), onTap: () => _pick(true))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded, color: StPalette.textMuted, size: 18),
            ),
            Expanded(child: _TimeButton(label: 'Ends', icon: Icons.wb_sunny_outlined, time: _fmt(_end), onTap: () => _pick(false))),
          ]),
          if (overnight) ...[
            const SizedBox(height: 8),
            const NoteBox(text: 'Ends the next morning. It counts under the day it starts.', icon: Icons.bedtime_outlined),
          ],
          FieldLabel(
            'Days',
            trailing: Wrap(spacing: 4, children: [
              _QuickDays(label: 'Every day', onTap: () => _setDays(kDayKeys)),
              _QuickDays(label: 'Mon–Fri', onTap: () => _setDays(kDayKeys.take(5))),
              _QuickDays(label: 'Weekend', onTap: () => _setDays(kDayKeys.skip(5))),
            ]),
          ),
          Row(children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _DayButton(
                  label: kDayLabels[i].substring(0, 1),
                  selected: _days.contains(kDayKeys[i]),
                  onTap: () => setState(() => _days.contains(kDayKeys[i]) ? _days.remove(kDayKeys[i]) : _days.add(kDayKeys[i])),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: StPalette.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: StPalette.border),
            ),
            child: Row(children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Session on', style: TextStyle(fontWeight: FontWeight.w700, color: StPalette.ink)),
                  Text('When off, no phone enforces it. Students stay assigned.',
                      style: TextStyle(fontSize: 12, color: StPalette.textSecondary)),
                ]),
              ),
              Switch(
                value: _active,
                activeThumbColor: Colors.white,
                activeTrackColor: StPalette.accent,
                onChanged: (v) => setState(() => _active = v),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          NoteBox(
            icon: Icons.schedule_rounded,
            text: days.isEmpty
                ? 'Pick at least one day.'
                : 'Phones block apps ${_fmt(_start)}–${_fmt(_end)} ${describeDays(days)}.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            NoteBox(text: _error!, icon: Icons.error_outline_rounded, color: StPalette.red),
          ],
          const SizedBox(height: 18),
          StPrimaryButton(label: isNew ? 'Create session' : 'Save changes', onPressed: _save),
        ]),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.icon, required this.time, required this.onTap});

  final String label;
  final IconData icon;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: StPalette.bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: StPalette.border),
            ),
            child: Row(children: [
              Icon(icon, size: 18, color: StPalette.accent),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: StPalette.textSecondary)),
                Text(time, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: StPalette.ink)),
              ]),
            ]),
          ),
        ),
      );
}

class _DayButton extends StatelessWidget {
  const _DayButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? StPalette.accent : StPalette.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? StPalette.accent : StPalette.border),
          ),
          child: Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: selected ? Colors.white : StPalette.textSecondary,
              )),
        ),
      );
}

class _QuickDays extends StatelessWidget {
  const _QuickDays({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: StPalette.accent)),
        ),
      );
}
