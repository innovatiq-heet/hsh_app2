import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating A-Z scroll rail for the phonebook list.
///
/// Collapsed to a small "A-Z" tab by default; tapping the tab opens the full
/// rail, which hides again [collapseDelay] after the last touch.
///
/// Features:
/// - Only shows letters present in current student directory (no dead letters or wasted space).
/// - Instant real-time scrolling when dragged; smooth animated scroll when tapped.
/// - Floating magnifying letter bubble to the left of the finger while touching/dragging.
/// - Haptic feedback on each letter transition.
class AlphaScrollRail extends StatefulWidget {
  final Map<String, int> alphaIndex;
  final void Function(String letter, {bool isDragging}) onLetterSelected;

  /// Called when the finger lifts off a letter, with the touch position on
  /// screen, so the caller can ask which group (students / alumni) to open.
  final void Function(String letter, Offset globalPosition)? onLetterReleased;

  final Duration collapseDelay;

  const AlphaScrollRail({
    super.key,
    required this.alphaIndex,
    required this.onLetterSelected,
    this.onLetterReleased,
    this.collapseDelay = const Duration(seconds: 3),
  });

  @override
  State<AlphaScrollRail> createState() => _AlphaScrollRailState();
}

class _AlphaScrollRailState extends State<AlphaScrollRail> {
  String? _activeLetter;
  double? _touchY;
  bool _expanded = false;
  Timer? _collapseTimer;

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _expand() {
    HapticFeedback.lightImpact();
    setState(() => _expanded = true);
    _scheduleCollapse();
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(widget.collapseDelay, () {
      if (mounted && _activeLetter == null) setState(() => _expanded = false);
    });
  }

  List<String> get _letters {
    final keys = widget.alphaIndex.keys.toList();
    keys.sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });
    return keys;
  }

  void _handleTouch(Offset localPosition, double railHeight, {required bool isDragging}) {
    final letters = _letters;
    if (letters.isEmpty) return;
    _collapseTimer?.cancel();

    final clampedY = localPosition.dy.clamp(0.0, railHeight);
    final fraction = (clampedY / railHeight).clamp(0.0, 0.999);
    final idx = (fraction * letters.length).floor();
    final letter = letters[idx];

    if (letter != _activeLetter) {
      setState(() {
        _activeLetter = letter;
        _touchY = clampedY;
      });
      HapticFeedback.selectionClick();
      widget.onLetterSelected(letter, isDragging: isDragging);
    } else {
      if (_touchY != clampedY) {
        setState(() => _touchY = clampedY);
      }
    }
  }

  void _handleTouchEnd([Offset? globalPosition]) {
    final letter = _activeLetter;
    if (letter != null && globalPosition != null) {
      widget.onLetterReleased?.call(letter, globalPosition);
    }
    setState(() {
      _activeLetter = null;
      _touchY = null;
    });
    _scheduleCollapse();
  }

  @override
  Widget build(BuildContext context) {
    final letters = _letters;
    if (letters.length <= 1) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(animation),
          alignment: Alignment.centerRight,
          child: child,
        ),
      ),
      child: _expanded ? _buildRail(letters) : _buildHandle(),
    );
  }

  /// Small tab shown while the rail is collapsed; tap to open the rail.
  Widget _buildHandle() {
    const accent = Color(0xFF0284C7);
    const letterStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w900,
      color: accent,
      height: 1,
    );
    return Semantics(
      key: const ValueKey('alpha-rail-handle'),
      button: true,
      label: 'Show A to Z index',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _expand,
        // Padding widens the touch target beyond the slim tab.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
          child: Container(
            width: 26,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(-1, 2),
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('A', style: letterStyle),
                Icon(Icons.unfold_more_rounded, size: 14, color: accent),
                Text('Z', style: letterStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRail(List<String> letters) {
    final itemHeight = (letters.length > 20) ? 15.0 : 18.0;
    final railHeight = (letters.length * itemHeight) + 12.0;

    final rail = SizedBox(
      height: railHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // 1. Floating Magnifier Bubble shown when touching/scrubbing
          if (_activeLetter != null && _touchY != null)
            Positioned(
              right: 34,
              top: (_touchY! - 22).clamp(0.0, railHeight - 44),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF03192E), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(-2, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _activeLetter!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

          // 2. The alphabet capsule rail
          // Raw pointer events: a GestureDetector with tap + drag waits for the
          // gesture arena (~100 ms) before the first letter reacts.
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _handleTouch(e.localPosition, railHeight, isDragging: false),
            onPointerMove: (e) => _handleTouch(e.localPosition, railHeight, isDragging: true),
            onPointerUp: (e) => _handleTouchEnd(e.position),
            onPointerCancel: (_) => _handleTouchEnd(),
            child: Container(
              width: 22,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(-1, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: letters.map((letter) {
                  final isActive = _activeLetter == letter;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: isActive ? 20 : 16,
                    height: itemHeight - 2,
                    decoration: isActive
                        ? const BoxDecoration(
                            color: Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          )
                        : null,
                    alignment: Alignment.center,
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: (letters.length > 20) ? 9 : 10,
                        fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                        color: isActive ? Colors.white : const Color(0xFF475569),
                        height: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );

    return KeyedSubtree(key: const ValueKey('alpha-rail-expanded'), child: rail);
  }
}

/// Collapsible shrinking deep navy header with luminous arcs, sync action and status pills.
