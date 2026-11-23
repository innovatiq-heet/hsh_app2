import 'package:flutter/material.dart';

import '../screen_time_api.dart';

/// Loads [load] and shows a spinner, an error with Retry, or [builder].
/// Pull-to-refresh calls [load] again.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _reload, child: const Text('Retry')),
          ]),
        ),
      );
    }
    return RefreshIndicator(onRefresh: _reload, child: widget.builder(context, _data as T, _reload));
  }
}

/// Runs [action], showing the server's message in a SnackBar on failure.
Future<bool> runWithFeedback(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } on ScreenTimeApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
    return false;
  }
}

/// Big number with a label, e.g. "12  Using phone in curfew".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color, this.onTap, this.help});

  final String value;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  /// Shown from the ⓘ icon: what the number means.
  final String? help;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
              if (help != null) HelpIcon(text: help!),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// ⓘ that explains a term in a dialog.
class HelpIcon extends StatelessWidget {
  const HelpIcon({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            content: Text(text),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        ),
        child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.info_outline, size: 16)),
      );
}

/// 🟢 online / 🟡 quiet / 🔴 offline.
class ConnectionDot extends StatelessWidget {
  const ConnectionDot({super.key, required this.status});

  final String status;

  static Color colorOf(String status) => switch (status) {
        'online' => Colors.green,
        'quiet' => Colors.amber,
        _ => Colors.red,
      };

  static String labelOf(String status) => switch (status) {
        'online' => 'Online',
        'quiet' => 'Quiet',
        _ => 'Offline',
      };

  @override
  Widget build(BuildContext context) => Tooltip(
        message: labelOf(status),
        child: Container(width: 10, height: 10, decoration: BoxDecoration(color: colorOf(status), shape: BoxShape.circle)),
      );
}

class SeverityChip extends StatelessWidget {
  const SeverityChip({super.key, required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (severity) {
      'high' => (Colors.red, 'Urgent'),
      'medium' => (Colors.orange, 'Check'),
      _ => (Colors.blueGrey, 'Note'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// "Running now" / "Off" / "Next: Mon 22:00" badge for a session.
class SessionStateBadge extends StatelessWidget {
  const SessionStateBadge({super.key, required this.isActive, required this.runningNow, this.nextStartAt});

  final bool isActive;
  final bool runningNow;
  final DateTime? nextStartAt;

  @override
  Widget build(BuildContext context) {
    final (color, text) = !isActive
        ? (Colors.grey, 'Off')
        : runningNow
            ? (Colors.deepPurple, 'Running now')
            : (Colors.teal, nextStartAt == null ? 'On' : 'Next: ${shortWhen(nextStartAt!)}');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _two(int n) => n.toString().padLeft(2, '0');

/// "today 22:00", "tomorrow 06:00", "Mon 22:00" (device local time).
String shortWhen(DateTime t) {
  final local = t.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = day.difference(today).inDays;
  final hm = '${_two(local.hour)}:${_two(local.minute)}';
  if (diff == 0) return 'today $hm';
  if (diff == 1) return 'tomorrow $hm';
  return '${_weekdays[local.weekday - 1]} $hm';
}

/// "21 Nov, 18:05".
String shortDateTime(DateTime t) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = t.toLocal();
  return '${l.day} ${months[l.month - 1]}, ${_two(l.hour)}:${_two(l.minute)}';
}
