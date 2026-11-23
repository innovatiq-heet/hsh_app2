import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../shared/widgets/navy_sliver_header.dart';
import '../screen_time_api.dart';

/// The Screen Time module's palette (same values as the directory, the
/// student page and [ScreenTimePage]). Every curfew / dashboard widget uses
/// these, never the general app tokens, so the screens match.
class StPalette {
  StPalette._();

  static const bg = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFF1F5F9);
  static const muted = Color(0xFFF1F5F9);

  static const ink = Color(0xFF0F172A);
  static const text = Color(0xFF334155);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const textLight = Color(0xFFCBD5E1);

  static const accent = Color(0xFF0284C7);
  static const accentDark = Color(0xFF0369A1);
  static const accentSoft = Color(0xFFE0F2FE);
  static const accentBorder = Color(0xFFBAE6FD);

  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFF0FDF4);
  static const amber = Color(0xFFD97706);
  static const amberBright = Color(0xFFF59E0B);
  static const amberSoft = Color(0xFFFEF3C7);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFEF2F2);

  /// The navy header's gradient, for hero cards.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF03192E), Color(0xFF032B4F), Color(0xFF025A8D), Color(0xFF0369A1)],
    stops: [0.0, 0.38, 0.75, 1.0],
  );

  static List<BoxShadow> get shadow => [
        BoxShadow(color: ink.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
      ];
}

/// Page frame of every curfew / dashboard screen: the module's slate
/// background, the shared pinned navy header (back button, round [actions])
/// and an optional pinned [tabBar] under it. [body] scrolls under the header.
class CurfewPage extends StatelessWidget {
  const CurfewPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.actions = const [],
    this.tabBar,
    this.floatingActionButton,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final List<NavyHeaderAction> actions;
  final TabBar? tabBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: StPalette.bg,
        floatingActionButton: floatingActionButton,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            NavySliverHeader(
              title: title,
              subtitle: subtitle,
              onBack: () => Navigator.of(context).maybePop(),
              actions: actions,
            ),
            if (tabBar != null) SliverPersistentHeader(pinned: true, delegate: _TabBarDelegate(tabBar!)),
          ],
          body: body,
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => 62;

  @override
  double get maxExtent => 62;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        color: StPalette.bg,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: StPalette.card,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm + 2),
            border: Border.all(color: StPalette.border),
          ),
          child: tabBar,
        ),
      );

  @override
  bool shouldRebuild(covariant _TabBarDelegate old) => old.tabBar != tabBar;
}

/// Segmented tab bar for [CurfewPage.tabBar].
TabBar curfewTabBar(List<String> labels) => TabBar(
      tabs: [for (final l in labels) Tab(height: 36, text: l)],
      indicator: BoxDecoration(color: StPalette.accent, borderRadius: BorderRadius.circular(AppDimens.radiusSm)),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: Colors.white,
      unselectedLabelColor: StPalette.textSecondary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    );

/// Navy extended FAB in the app's button style.
class CurfewFab extends StatelessWidget {
  const CurfewFab({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: StPalette.accent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

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
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6, color: StPalette.accent),
        ),
      );
    }
    if (_error != null && _data == null) {
      return EmptyBlock(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load',
        message: '$_error',
        actionLabel: 'Retry',
        onAction: _reload,
      );
    }
    return RefreshIndicator(
      color: StPalette.accent,
      onRefresh: _reload,
      child: widget.builder(context, _data as T, _reload),
    );
  }
}

/// Centered icon, title and message (empty lists, errors). Scrollable, so
/// pull-to-refresh still works on it.
class EmptyBlock extends StatelessWidget {
  const EmptyBlock({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: StPalette.accentSoft, shape: BoxShape.circle),
              child: Icon(icon, color: StPalette.accent, size: 30),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: StPalette.ink),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: StPalette.textSecondary, height: 1.4),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            Center(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: StPalette.accent),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      );
}

/// Runs [action], showing the server's message in a SnackBar on failure.
Future<bool> runWithFeedback(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  void show(String text, {bool error = false}) => messenger.showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? StPalette.red : StPalette.ink,
      ));
  try {
    await action();
    if (success != null) show(success);
    return true;
  } on ScreenTimeApiException catch (e) {
    show(e.message, error: true);
    return false;
  } catch (e) {
    show('$e', error: true);
    return false;
  }
}

/// The Screen Time card: white, 14 px radius, slate hairline border and a
/// faint shadow (same as the directory rows). [gradient] for hero cards.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.gradient,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? StPalette.card) : null,
        gradient: gradient,
        borderRadius: radius,
        border: gradient == null ? Border.all(color: borderColor ?? StPalette.border) : null,
        boxShadow: StPalette.shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// "RIGHT NOW" style section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.icon});

  final String title;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: StPalette.textMuted),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: StPalette.textMuted,
              ),
            ),
          ),
          ?action,
        ]),
      );
}

/// Small text button for a [SectionHeader].
class SectionAction extends StatelessWidget {
  const SectionAction({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: StPalette.accent)),
            const Icon(Icons.chevron_right_rounded, size: 16, color: StPalette.accent),
          ]),
        ),
      );
}

/// Small rounded label: "Running now", "Paused", "Urgent", ...
class StPill extends StatelessWidget {
  const StPill({super.key, required this.text, required this.color, this.background, this.icon});

  final String text;
  final Color color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: background ?? color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Rounded square with an icon on a soft tint (leading of rows and tiles).
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.color = StPalette.accent, this.size = 40, this.background});

  final IconData icon;
  final Color color;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, size: size * 0.5, color: color),
      );
}

/// Number with a label and an icon, e.g. "12 · Using phone in curfew".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color, this.onTap, this.help, this.icon});

  final String value;
  final String label;

  /// Highlight colour for the number (a problem worth looking at).
  final Color? color;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Shown from the ⓘ icon: what the number means.
  final String? help;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? StPalette.accent;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) IconBadge(icon: icon!, color: accent, size: 30),
          const Spacer(),
          if (help != null) HelpIcon(text: help!),
          if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 18, color: StPalette.textLight),
        ]),
        const SizedBox(height: 10),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: color ?? StPalette.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: StPalette.textSecondary),
        ),
      ]),
    );
  }
}

/// Two columns of tiles (four on a wide screen).
class TileGrid extends StatelessWidget {
  const TileGrid(this.children, {super.key, this.columns});

  final List<Widget> children;
  final int? columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final n = columns ?? (c.maxWidth > 600 ? 4 : 2);
        const gap = 10.0;
        final width = (c.maxWidth - (n - 1) * gap) / n;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final w in children) SizedBox(width: width, child: w)]);
      });
}

/// ⓘ that explains a term in a dialog.
class HelpIcon extends StatelessWidget {
  const HelpIcon({super.key, required this.text, this.color = StPalette.textLight});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusLg)),
            content: Text(text, style: const TextStyle(height: 1.4)),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(3), child: Icon(Icons.info_outline_rounded, size: 16, color: color)),
      );
}

/// Round avatar with the student's initials and an optional status dot.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.status, this.size = 42});

  final String name;
  final String? status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials =
        parts.isEmpty ? '?' : (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: StPalette.accentSoft, shape: BoxShape.circle),
          child: Text(
            initials,
            style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: StPalette.accent),
          ),
        ),
        if (status != null)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: ConnectionDot(status: status!),
            ),
          ),
      ]),
    );
  }
}

/// 🟢 online / 🟡 quiet / 🔴 offline.
class ConnectionDot extends StatelessWidget {
  const ConnectionDot({super.key, required this.status});

  final String status;

  static Color colorOf(String status) => switch (status) {
        'online' => StPalette.green,
        'quiet' => StPalette.amberBright,
        _ => StPalette.red,
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

  static Color colorOf(String severity) => switch (severity) {
        'high' => StPalette.red,
        'medium' => StPalette.amber,
        _ => StPalette.textSecondary,
      };

  @override
  Widget build(BuildContext context) => StPill(
        text: switch (severity) {
          'high' => 'Urgent',
          'medium' => 'Check',
          _ => 'Note',
        },
        color: colorOf(severity),
      );
}

/// "Running now" / "Off" / "Next today 22:00" badge for a session.
class SessionStateBadge extends StatelessWidget {
  const SessionStateBadge({super.key, required this.isActive, required this.runningNow, this.nextStartAt});

  final bool isActive;
  final bool runningNow;
  final DateTime? nextStartAt;

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return const StPill(text: 'Off', color: StPalette.textMuted, icon: Icons.power_settings_new_rounded);
    }
    if (runningNow) return const StPill(text: 'Running now', color: StPalette.accent, icon: Icons.nightlight_round);
    return StPill(
      text: nextStartAt == null ? 'On' : 'Next ${shortWhen(nextStartAt!)}',
      color: StPalette.green,
      icon: Icons.schedule_rounded,
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheets (session editor, add students)
// ---------------------------------------------------------------------------

/// Opens [child] in a white rounded bottom sheet with the module's handle.
Future<T?> showStSheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: StPalette.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: StPalette.border, borderRadius: BorderRadius.circular(2)),
          ),
          Flexible(child: child),
        ]),
      ),
    );

/// Title and subtitle at the top of a sheet.
class SheetTitle extends StatelessWidget {
  const SheetTitle({super.key, required this.title, this.subtitle, this.icon = Icons.nightlight_round});

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
        IconBadge(icon: icon, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: StPalette.ink)),
            if (subtitle != null)
              Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: StPalette.textSecondary)),
          ]),
        ),
      ]);
}

/// Small grey label above a group of fields.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: StPalette.textMuted,
                )),
          ),
          ?trailing,
        ]),
      );
}

/// Selectable chip in the module's style (sky when selected).
class StChoice extends StatelessWidget {
  const StChoice({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? StPalette.accentSoft : StPalette.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? StPalette.accentBorder : StPalette.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null || selected) ...[
                Icon(selected ? Icons.check_rounded : icon, size: 14, color: selected ? StPalette.accent : StPalette.textSecondary),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? StPalette.accentDark : StPalette.text,
                  )),
            ]),
          ),
        ),
      );
}

/// Text field decoration of the sheets.
InputDecoration stInputDecoration({required String label, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: StPalette.bg,
      counterText: '',
      labelStyle: const TextStyle(color: StPalette.textSecondary),
      floatingLabelStyle: const TextStyle(color: StPalette.accent, fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StPalette.border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StPalette.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StPalette.accent, width: 1.5)),
    );

/// Full-width sky button at the bottom of a sheet.
class StPrimaryButton extends StatelessWidget {
  const StPrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 50,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: StPalette.accent,
            disabledBackgroundColor: StPalette.textLight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          onPressed: busy ? null : onPressed,
          child: busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(label),
        ),
      );
}

/// Light note box (info, warning, error) used inside sheets and pages.
class NoteBox extends StatelessWidget {
  const NoteBox({super.key, required this.text, this.icon = Icons.info_outline_rounded, this.color = StPalette.accent});

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: StPalette.text, height: 1.35))),
        ]),
      );
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
