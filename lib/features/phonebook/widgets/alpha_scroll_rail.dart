import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One letter on the index rail. [alumni] letters belong to the alumni
/// section, which has its own tab and strip.
class RailEntry {
  final String letter;
  final bool alumni;
  const RailEntry(this.letter, {this.alumni = false});

  @override
  bool operator ==(Object other) =>
      other is RailEntry && other.letter == letter && other.alumni == alumni;

  @override
  int get hashCode => Object.hash(letter, alumni);
}

/// iOS-Contacts style index with two independent sections, **Students** and
/// **Alumni**. Each rests as its own small tab on the right edge; tapping a
/// tab smoothly grows just that section into a strip of its letters while the
/// other section stays a tab (opening one folds the other). The open strip
/// folds back by itself 3 seconds after the last touch. On an open strip, slide
/// a finger anywhere: the list follows letter by letter with a haptic tick.
class AlphaScrollRail extends StatefulWidget {
  final List<RailEntry> entries;

  /// Called once each time the finger moves onto a different letter.
  final ValueChanged<RailEntry> onSelected;

  const AlphaScrollRail({
    super.key,
    required this.entries,
    required this.onSelected,
  });

  @override
  State<AlphaScrollRail> createState() => _AlphaScrollRailState();
}

class _AlphaScrollRailState extends State<AlphaScrollRail> {
  /// Which section is open: false = students, true = alumni, null = none.
  bool? _openAlumni;

  @override
  Widget build(BuildContext context) {
    final students = widget.entries.where((e) => !e.alumni).toList();
    final alumni = widget.entries.where((e) => e.alumni).toList();
    if (students.length + alumni.length <= 1) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight.isFinite ? constraints.maxHeight : 520.0;
        final groups = [
          if (students.isNotEmpty) false,
          if (alumni.isNotEmpty) true,
        ];
        // Height left for the open strip once the other tab(s) are counted.
        final otherTabs = groups.length - 1;
        final maxOpen = available - otherTabs * (_RailSection.tabHeight + _gap);

        final sections = <Widget>[];
        for (var i = 0; i < groups.length; i++) {
          final isAlumni = groups[i];
          if (i > 0) sections.add(const SizedBox(height: _gap));
          sections.add(
            _RailSection(
              key: ValueKey(isAlumni ? 'rail-alumni' : 'rail-students'),
              title: isAlumni ? 'Alumni' : 'Students',
              icon: isAlumni ? Icons.school_rounded : Icons.people_alt_rounded,
              color: isAlumni ? const Color(0xFF9333EA) : const Color(0xFF0284C7),
              entries: isAlumni ? alumni : students,
              isOpen: _openAlumni == isAlumni,
              maxHeight: maxOpen,
              onRequestOpen: () => setState(() => _openAlumni = isAlumni),
              onRequestClose: () {
                if (_openAlumni == isAlumni) setState(() => _openAlumni = null);
              },
              onSelected: widget.onSelected,
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: sections,
        );
      },
    );
  }

  static const double _gap = 8;
}

/// One section of the rail: a resting tab that grows into a letter strip.
class _RailSection extends StatefulWidget {
  static const double tabHeight = 60;

  final String title;
  final IconData icon;
  final Color color;
  final List<RailEntry> entries;
  final bool isOpen;
  final double maxHeight;
  final VoidCallback onRequestOpen;
  final VoidCallback onRequestClose;
  final ValueChanged<RailEntry> onSelected;

  const _RailSection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.entries,
    required this.isOpen,
    required this.maxHeight,
    required this.onRequestOpen,
    required this.onRequestClose,
    required this.onSelected,
  });

  @override
  State<_RailSection> createState() => _RailSectionState();
}

class _RailSectionState extends State<_RailSection> with SingleTickerProviderStateMixin {
  /// Index of the letter under the finger, or null when idle.
  final ValueNotifier<int?> _active = ValueNotifier<int?>(null);
  bool _touching = false;
  RailEntry? _last;

  /// 0 = resting tab, 1 = open strip.
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 240),
  );
  late final Animation<double> _grow = CurvedAnimation(
    parent: _open,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );
  Timer? _collapseTimer;
  static const _collapseDelay = Duration(seconds: 3);

  bool get _isOpen => _open.value > 0.92;

  @override
  void initState() {
    super.initState();
    if (widget.isOpen) _open.value = 1;
  }

  @override
  void didUpdateWidget(covariant _RailSection old) {
    super.didUpdateWidget(old);
    if (widget.isOpen && !old.isOpen) {
      _open.forward();
      _scheduleCollapse();
    } else if (!widget.isOpen && old.isOpen) {
      _collapseTimer?.cancel();
      _open.reverse();
    }
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(_collapseDelay, () {
      if (mounted && !_touching) widget.onRequestClose();
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _open.dispose();
    _active.dispose();
    super.dispose();
  }

  void _touch(double dy, double height) {
    final n = widget.entries.length;
    if (n == 0 || height <= 0) return;
    final fraction = (dy / height).clamp(0.0, 0.9999);
    final i = (fraction * n).floor();
    final entry = widget.entries[i];
    if (_active.value != i) _active.value = i;
    if (entry != _last) {
      _last = entry;
      HapticFeedback.selectionClick();
      widget.onSelected(entry);
    }
  }

  void _end() {
    _touching = false;
    _active.value = null;
    _last = null;
    _scheduleCollapse();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.entries.length;
    // Fit every letter: tall phones get roomy letters, short ones shrink.
    final rowHeight = ((widget.maxHeight - 12) / n).clamp(11.0, 19.0);
    final letters = rowHeight * n;
    // Never shorter than the resting tab, so a section with few letters still grows.
    final fullHeight = (letters + 12).clamp(_RailSection.tabHeight, double.infinity);
    final top = (fullHeight - letters) / 2; // letters stay centred in the strip
    final fontSize = rowHeight >= 16 ? 10.5 : (rowHeight >= 13 ? 9.5 : 8.5);
    const tabHeight = _RailSection.tabHeight;

    return Semantics(
      label: '${widget.title} index. Tap to open, then slide to jump to a letter',
      container: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _collapseTimer?.cancel();
          if (!_isOpen) {
            // First touch only opens this section; letters are picked after.
            if (!widget.isOpen) {
              HapticFeedback.lightImpact();
              widget.onRequestOpen();
            }
            return;
          }
          _touching = true;
          _touch(e.localPosition.dy - top, letters);
        },
        onPointerMove: (e) {
          if (_isOpen && _touching) _touch(e.localPosition.dy - top, letters);
        },
        onPointerUp: (_) => _touching ? _end() : _scheduleCollapseIfOpen(),
        onPointerCancel: (_) => _touching ? _end() : _scheduleCollapseIfOpen(),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _grow,
            builder: (context, _) {
              final t = _grow.value;
              final height = tabHeight + (fullHeight - tabHeight) * t;
              // The tab label fades out first, the letters fade in last.
              final tabOpacity = (1 - t * 2.5).clamp(0.0, 1.0);
              final lettersOpacity = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
              return Container(
                // Wider touch target than the visible tab.
                width: 36,
                height: height,
                alignment: Alignment.centerRight,
                color: Colors.transparent,
                child: Container(
                  width: 26 + 2 * t,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.80 + 0.14 * t),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.35 - 0.15 * t),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08 + 0.04 * t),
                        blurRadius: 10,
                        offset: const Offset(-1, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(opacity: tabOpacity, child: _tabLabel()),
                        if (lettersOpacity > 0)
                          Opacity(
                            opacity: lettersOpacity,
                            child: OverflowBox(
                              minHeight: fullHeight,
                              maxHeight: fullHeight,
                              child: Align(
                                alignment: Alignment.center,
                                child: ValueListenableBuilder<int?>(
                                  valueListenable: _active,
                                  builder: (context, active, _) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var i = 0; i < n; i++)
                                          _row(widget.entries[i], i == active, rowHeight, fontSize),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _scheduleCollapseIfOpen() {
    if (widget.isOpen) _scheduleCollapse();
  }

  /// The resting tab: the section's icon and a short label.
  Widget _tabLabel() {
    final style = TextStyle(
      fontSize: 8.5,
      fontWeight: FontWeight.w900,
      color: widget.color,
      height: 1,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: 16, color: widget.color),
        const SizedBox(height: 3),
        Text(widget.title == 'Students' ? 'STU' : 'ALU', style: style),
        const SizedBox(height: 1),
        Icon(Icons.unfold_more_rounded, size: 13, color: widget.color),
      ],
    );
  }

  Widget _row(RailEntry entry, bool active, double height, double fontSize) {
    return SizedBox(
      height: height,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: active ? height + 2 : 16,
          height: active ? height + 2 : height,
          decoration: active ? BoxDecoration(color: widget.color, shape: BoxShape.circle) : null,
          alignment: Alignment.center,
          child: Text(
            entry.letter,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              color: active
                  ? Colors.white
                  : (entry.alumni ? widget.color : const Color(0xFF475569)),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
