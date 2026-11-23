import 'package:flutter/material.dart';

import '../curfew_schedule.dart';
import '../models.dart';

/// Create (existing == null) or edit a session. Returns the draft to save,
/// or null when cancelled. For an edit only the changed fields are set.
Future<SessionDraft?> showSessionEditor(BuildContext context, {CurfewSession? existing}) {
  return showModalBottomSheet<SessionDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _SessionEditor(existing: existing),
    ),
  );
}

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
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.existing == null ? 'New curfew session' : 'Edit session', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Night Curfew, Afternoon Study'),
          ),
          Row(children: [
            Expanded(child: _TimeButton(label: 'Starts', time: _fmt(_start), onTap: () => _pick(true))),
            const SizedBox(width: 12),
            Expanded(child: _TimeButton(label: 'Ends', time: _fmt(_end), onTap: () => _pick(false))),
          ]),
          if (overnight)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Ends the next morning. It counts under the day it starts.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 16),
          Text('Days', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < 7; i++)
              FilterChip(
                label: Text(kDayLabels[i]),
                selected: _days.contains(kDayKeys[i]),
                onSelected: (on) => setState(() => on ? _days.add(kDayKeys[i]) : _days.remove(kDayKeys[i])),
              ),
          ]),
          Wrap(spacing: 8, children: [
            TextButton(onPressed: () => setState(() => _days..clear()..addAll(kDayKeys)), child: const Text('Every day')),
            TextButton(onPressed: () => setState(() => _days..clear()..addAll(kDayKeys.take(5))), child: const Text('Mon–Fri')),
            TextButton(onPressed: () => setState(() => _days..clear()..addAll(kDayKeys.skip(5))), child: const Text('Weekend')),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Session on'),
            subtitle: const Text('When off, no phone enforces it. Students stay assigned.'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          Text('Phones block apps ${_fmt(_start)}–${_fmt(_end)} ${describeDays(days)}.',
              style: Theme.of(context).textTheme.bodyMedium),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(widget.existing == null ? 'Create' : 'Save')),
        ]),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.time, required this.onTap});

  final String label;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Column(children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(time, style: Theme.of(context).textTheme.titleLarge),
        ]),
      );
}
