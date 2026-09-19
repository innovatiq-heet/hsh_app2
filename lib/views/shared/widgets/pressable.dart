import 'package:flutter/material.dart';

/// Tactile press feedback: scales the child down while a pointer is held
/// and springs back on release.
///
/// Uses a raw [Listener] rather than a gesture recognizer so it never
/// competes in the gesture arena with the child's own InkWell / onTap —
/// the child still receives taps normally. A pointer that drifts past a
/// small slop (i.e. the user is scrolling) releases the press.
class Pressable extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double pressedScale;

  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.96,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  static const _slop = 10.0;

  bool _pressed = false;
  Offset? _downAt;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (e) {
        _downAt = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        if (_downAt != null && (e.position - _downAt!).distance > _slop) {
          _set(false);
        }
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: _pressed
            ? const Duration(milliseconds: 110)
            : const Duration(milliseconds: 320),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
