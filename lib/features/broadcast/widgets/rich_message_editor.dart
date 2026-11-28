import 'package:flutter/material.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';

/// Bit flags for inline WYSIWYG formatting in [RichBroadcastTextController].
class BroadcastStyleFlags {
  BroadcastStyleFlags._();

  static const int none = 0;
  static const int bold = 1 << 0;
  static const int italic = 1 << 1;
  static const int underline = 1 << 2;
  static const int strike = 1 << 3;
}

/// True WYSIWYG [TextEditingController]: tapping Bold / Italic / Underline /
/// Strikethrough styles selected text or newly typed characters directly on
/// screen without ever showing markdown/HTML symbols in the input box.
class RichBroadcastTextController extends TextEditingController {
  RichBroadcastTextController({super.text})
      : _styles = List<int>.filled(
          (text ?? '').length,
          BroadcastStyleFlags.none,
          growable: true,
        );

  List<int> _styles;
  int _pendingMask = BroadcastStyleFlags.none;
  int? _lockedCursorOffset;

  static final RegExp _bulletLineRe = RegExp(r'^•\s+');
  static final RegExp _numberLineRe = RegExp(r'^\d+\.\s+');

  /// Active style flags at the current cursor or selection.
  int get activeMask {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return _pendingMask;
    final lo = sel.start < sel.end ? sel.start : sel.end;
    final hi = sel.start < sel.end ? sel.end : sel.start;
    var common = ~0;
    var seenChar = false;
    for (var i = lo; i < hi && i < _styles.length; i++) {
      if (text.codeUnitAt(i) == 10) continue; // ignore '\n'
      common &= _styles[i];
      seenChar = true;
    }
    return seenChar ? common : _pendingMask;
  }

  String _currentLineText() {
    final cur = text;
    final pos = selection.isValid ? selection.extentOffset.clamp(0, cur.length) : cur.length;
    final lineStart = pos == 0 ? 0 : (cur.lastIndexOf('\n', pos - 1) + 1);
    final nextNl = cur.indexOf('\n', pos);
    final lineEnd = nextNl == -1 ? cur.length : nextNl;
    return cur.substring(lineStart, lineEnd);
  }

  /// True when the current line starts with a bullet (`• `).
  bool get isBulletActive => _bulletLineRe.hasMatch(_currentLineText());

  /// True when the current line starts with a list number (`1. `, `2. `, ...).
  bool get isNumberedActive => _numberLineRe.hasMatch(_currentLineText());

  /// Toggles [flag] on the current selection, or arms/disarms it for the next
  /// characters typed at the cursor.
  void toggleStyle(int flag) {
    final sel = selection;
    if (sel.isValid && !sel.isCollapsed) {
      final lo = sel.start < sel.end ? sel.start : sel.end;
      final hi = sel.start < sel.end ? sel.end : sel.start;
      final allHave = _rangeHasFlag(lo, hi, flag);
      for (var i = lo; i < hi && i < _styles.length; i++) {
        if (text.codeUnitAt(i) == 10) continue;
        _styles[i] = allHave ? (_styles[i] & ~flag) : (_styles[i] | flag);
      }
      _pendingMask = allHave ? (_pendingMask & ~flag) : (_pendingMask | flag);
      _lockedCursorOffset = null;
      notifyListeners();
      return;
    }

    _pendingMask ^= flag;
    _lockedCursorOffset = sel.isValid ? sel.extentOffset : text.length;
    notifyListeners();
  }

  bool _rangeHasFlag(int lo, int hi, int flag) {
    var seen = false;
    for (var i = lo; i < hi && i < _styles.length; i++) {
      if (text.codeUnitAt(i) == 10) continue;
      seen = true;
      if ((_styles[i] & flag) == 0) return false;
    }
    return seen;
  }

  /// Inserts or toggles clean bullet (`• `) or numbered (`1. `) prefixes on
  /// the selected lines (or current line) with zero markdown symbols.
  void toggleList({required bool numbered}) {
    final cur = text;
    final sel = selection;
    final lo = sel.isValid ? (sel.start < sel.end ? sel.start : sel.end) : cur.length;
    final hi = sel.isValid ? (sel.start < sel.end ? sel.end : sel.start) : cur.length;

    final blockStart = lo == 0 ? 0 : (cur.lastIndexOf('\n', lo - 1) + 1);
    final endProbe = hi > lo && hi > 0 && cur[hi - 1] == '\n' ? hi - 1 : hi;
    final nextNl = cur.indexOf('\n', endProbe);
    final blockEnd = nextNl == -1 ? cur.length : nextNl;

    final bulletRe = RegExp(r'^•\s+');
    final numberRe = RegExp(r'^\d+\.\s+');

    final lineTexts = cur.substring(blockStart, blockEnd).split('\n');
    final nonEmpty = lineTexts.where((l) => l.trim().isNotEmpty).toList();
    final allMatch = nonEmpty.isNotEmpty &&
        nonEmpty.every((l) => numbered ? numberRe.hasMatch(l) : bulletRe.hasMatch(l));

    // Preserve per-character styles per line across prefix add/remove.
    final nextLines = <String>[];
    final nextLineStyles = <List<int>>[];
    var cursorPos = blockStart;
    var order = 1;

    for (var i = 0; i < lineTexts.length; i++) {
      final line = lineTexts[i];
      final lineLen = line.length;
      final lineStyle = (cursorPos + lineLen <= _styles.length)
          ? _styles.sublist(cursorPos, cursorPos + lineLen)
          : List<int>.filled(lineLen, BroadcastStyleFlags.none);
      cursorPos += lineLen + 1; // +1 for '\n'

      if (lineTexts.length > 1 && line.trim().isEmpty) {
        nextLines.add(line);
        nextLineStyles.add(lineStyle);
        continue;
      }

      var stripLen = 0;
      final bMatch = bulletRe.firstMatch(line);
      final nMatch = numberRe.firstMatch(line);
      if (bMatch != null) {
        stripLen = bMatch.end;
      } else if (nMatch != null) {
        stripLen = nMatch.end;
      }

      final strippedText = line.substring(stripLen);
      final strippedStyles = lineStyle.sublist(stripLen);

      if (allMatch) {
        nextLines.add(strippedText);
        nextLineStyles.add(strippedStyles);
      } else {
        final prefix = numbered ? '${order++}. ' : '• ';
        nextLines.add('$prefix$strippedText');
        nextLineStyles.add([
          ...List<int>.filled(prefix.length, BroadcastStyleFlags.none),
          ...strippedStyles,
        ]);
      }
    }

    final replacementText = nextLines.join('\n');
    final replacementStyles = <int>[];
    for (var i = 0; i < nextLineStyles.length; i++) {
      replacementStyles.addAll(nextLineStyles[i]);
      if (i < nextLineStyles.length - 1) {
        replacementStyles.add(BroadcastStyleFlags.none);
      }
    }

    final fullNewText =
        '${cur.substring(0, blockStart)}$replacementText${cur.substring(blockEnd)}';
    final fullNewStyles = <int>[
      ..._styles.sublist(0, blockStart),
      ...replacementStyles,
      ..._styles.sublist(blockEnd),
    ];

    _styles = fullNewStyles;
    _lockedCursorOffset = null;
    final endOffset = blockStart + replacementText.length;
    super.value = TextEditingValue(
      text: fullNewText,
      selection: lo == hi
          ? TextSelection.collapsed(offset: endOffset)
          : TextSelection(baseOffset: blockStart, extentOffset: endOffset),
    );
  }

  /// Clears formatting on the current selection, active cursor style, or whole text.
  void clearFormatting() {
    final sel = selection;
    if (sel.isValid && !sel.isCollapsed) {
      final lo = sel.start < sel.end ? sel.start : sel.end;
      final hi = sel.start < sel.end ? sel.end : sel.start;
      for (var i = lo; i < hi && i < _styles.length; i++) {
        _styles[i] = BroadcastStyleFlags.none;
      }
      _pendingMask = BroadcastStyleFlags.none;
      _lockedCursorOffset = null;
      notifyListeners();
      return;
    }

    if (_pendingMask != BroadcastStyleFlags.none) {
      _pendingMask = BroadcastStyleFlags.none;
      _lockedCursorOffset = sel.isValid ? sel.extentOffset : text.length;
      notifyListeners();
      return;
    }

    for (var i = 0; i < _styles.length; i++) {
      _styles[i] = BroadcastStyleFlags.none;
    }
    notifyListeners();
  }

  /// Style flags at character [index] (primarily for testing and inspection).
  int styleAt(int index) =>
      (index >= 0 && index < _styles.length) ? _styles[index] : BroadcastStyleFlags.none;

  @override
  set value(TextEditingValue newValue) {
    final oldText = super.value.text;
    final newText = newValue.text;

    if (oldText != newText) {
      final oldLen = oldText.length;
      final newLen = newText.length;
      final minLen = oldLen < newLen ? oldLen : newLen;

      var prefix = 0;
      while (prefix < minLen &&
          oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
        prefix++;
      }
      var suffix = 0;
      while (suffix < (minLen - prefix) &&
          oldText.codeUnitAt(oldLen - 1 - suffix) ==
              newText.codeUnitAt(newLen - 1 - suffix)) {
        suffix++;
      }

      final deleted = oldLen - prefix - suffix;
      final inserted = newLen - prefix - suffix;

      final insertedStyles = List<int>.generate(inserted, (i) {
        if (newText.codeUnitAt(prefix + i) == 10) return BroadcastStyleFlags.none;
        return _pendingMask;
      });

      final safePrefix = prefix.clamp(0, _styles.length);
      final safeOldEnd = (prefix + deleted).clamp(safePrefix, _styles.length);
      _styles = <int>[
        ..._styles.sublist(0, safePrefix),
        ...insertedStyles,
        ..._styles.sublist(safeOldEnd),
      ];
      _lockedCursorOffset = null;

      // Auto-continue bullet (`• `) or numbered (`1. `, `2. `) lists on Enter,
      // or exit the list cleanly when Enter is pressed on an empty list item.
      if (deleted == 0 &&
          inserted == 1 &&
          newText.codeUnitAt(prefix) == 10 &&
          newValue.selection.isCollapsed &&
          newValue.selection.extentOffset == prefix + 1) {
        final prevLineStart =
            prefix == 0 ? 0 : (newText.lastIndexOf('\n', prefix - 1) + 1);
        final prevLine = newText.substring(prevLineStart, prefix);
        final bulletMatch = _bulletLineRe.firstMatch(prevLine);
        final numMatch = _numberLineRe.firstMatch(prevLine);

        if (bulletMatch != null || numMatch != null) {
          final prefixMatchEnd =
              bulletMatch != null ? bulletMatch.end : numMatch!.end;
          final bodyAfterPrefix = prevLine.substring(prefixMatchEnd);

          if (bodyAfterPrefix.trim().isEmpty) {
            // Empty list item + Enter -> remove the list prefix & extra newline to exit list.
            final exitedText =
                newText.substring(0, prevLineStart) + newText.substring(prefix + 1);
            _styles = <int>[
              ..._styles.sublist(0, prevLineStart),
              ..._styles.sublist(prefix + 1),
            ];
            _pendingMask = BroadcastStyleFlags.none;
            super.value = TextEditingValue(
              text: exitedText,
              selection: TextSelection.collapsed(offset: prevLineStart),
            );
            return;
          }

          String nextListPrefix;
          if (bulletMatch != null) {
            nextListPrefix = '• ';
          } else {
            final curNum = int.tryParse(prevLine.split('.').first.trim()) ?? 1;
            nextListPrefix = '${curNum + 1}. ';
          }

          final insertPos = prefix + 1;
          final continuedText =
              '${newText.substring(0, insertPos)}$nextListPrefix${newText.substring(insertPos)}';
          _styles = <int>[
            ..._styles.sublist(0, insertPos),
            ...List<int>.filled(nextListPrefix.length, BroadcastStyleFlags.none),
            ..._styles.sublist(insertPos),
          ];
          final cursorPos = insertPos + nextListPrefix.length;
          _lockedCursorOffset = cursorPos;
          super.value = TextEditingValue(
            text: continuedText,
            selection: TextSelection.collapsed(offset: cursorPos),
          );
          return;
        }
      }
    } else {
      final sel = newValue.selection;
      if (sel.isValid && sel.isCollapsed) {
        final pos = sel.extentOffset;
        if (_lockedCursorOffset == null || _lockedCursorOffset != pos) {
          _lockedCursorOffset = null;
          if (pos > 0 &&
              pos <= _styles.length &&
              newText.codeUnitAt(pos - 1) != 10) {
            _pendingMask = _styles[pos - 1];
          } else {
            _pendingMask = BroadcastStyleFlags.none;
          }
        }
      } else {
        _lockedCursorOffset = null;
      }
    }

    super.value = newValue;
  }

  @override
  void clear() {
    _styles = <int>[];
    _pendingMask = BroadcastStyleFlags.none;
    _lockedCursorOffset = null;
    super.clear();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle(fontSize: 15, color: PhonebookTheme.ink);
    final cur = text;
    if (cur.isEmpty) return TextSpan(text: '', style: base);
    if (_styles.length != cur.length) {
      return TextSpan(text: cur, style: base);
    }

    final children = <InlineSpan>[];
    var runStart = 0;
    var runMask = _styles[0];

    for (var i = 1; i <= cur.length; i++) {
      final nextMask = i < cur.length ? _styles[i] : -1;
      if (nextMask != runMask) {
        children.add(
          TextSpan(
            text: cur.substring(runStart, i),
            style: _applyMask(base, runMask),
          ),
        );
        runStart = i;
        runMask = nextMask;
      }
    }
    return TextSpan(style: base, children: children);
  }

  static TextStyle _applyMask(TextStyle base, int mask) {
    if (mask == BroadcastStyleFlags.none) return base;
    var s = base;
    final decorations = <TextDecoration>[
      if (base.decoration != null && base.decoration != TextDecoration.none)
        base.decoration!,
    ];
    if ((mask & BroadcastStyleFlags.bold) != 0) {
      s = s.copyWith(fontWeight: FontWeight.w700);
    }
    if ((mask & BroadcastStyleFlags.italic) != 0) {
      s = s.copyWith(fontStyle: FontStyle.italic);
    }
    if ((mask & BroadcastStyleFlags.underline) != 0) {
      decorations.add(TextDecoration.underline);
    }
    if ((mask & BroadcastStyleFlags.strike) != 0) {
      decorations.add(TextDecoration.lineThrough);
    }
    if (decorations.isNotEmpty) {
      s = s.copyWith(decoration: TextDecoration.combine(decorations));
    }
    return s;
  }

  /// Serializes the styled runs into clean markup (`*bold*`, `_italic_`,
  /// `<u>underline</u>`, `~strike~`) for In-App rendering, Push, and WhatsApp.
  String toFormattedMarkup() {
    final cur = text;
    if (cur.isEmpty) return '';
    if (_styles.length != cur.length) return cur;

    final out = StringBuffer();
    var lineStart = 0;

    while (lineStart <= cur.length) {
      final nl = cur.indexOf('\n', lineStart);
      final lineEnd = nl == -1 ? cur.length : nl;

      if (lineEnd > lineStart) {
        var runStart = lineStart;
        var runMask = _styles[lineStart];
        for (var i = lineStart + 1; i <= lineEnd; i++) {
          final nextMask = i < lineEnd ? _styles[i] : -1;
          if (nextMask != runMask) {
            out.write(_wrapChunk(cur.substring(runStart, i), runMask));
            runStart = i;
            runMask = nextMask;
          }
        }
      }

      if (nl == -1) break;
      out.write('\n');
      lineStart = nl + 1;
    }
    return out.toString();
  }

  static String _wrapChunk(String raw, int mask) {
    if (mask == BroadcastStyleFlags.none || raw.trim().isEmpty) return raw;
    final leadMatch = RegExp(r'^\s*').firstMatch(raw);
    final trailMatch = RegExp(r'\s*$').firstMatch(raw);
    final leadEnd = leadMatch?.end ?? 0;
    final trailStart = trailMatch?.start ?? raw.length;
    if (leadEnd >= trailStart) return raw;

    final lead = raw.substring(0, leadEnd);
    var core = raw.substring(leadEnd, trailStart);
    final trail = raw.substring(trailStart);

    if ((mask & BroadcastStyleFlags.bold) != 0) core = '*$core*';
    if ((mask & BroadcastStyleFlags.italic) != 0) core = '_${core}_';
    if ((mask & BroadcastStyleFlags.underline) != 0) core = '<u>$core</u>';
    if ((mask & BroadcastStyleFlags.strike) != 0) core = '~$core~';
    return '$lead$core$trail';
  }
}

/// Clean WYSIWYG message composer with a simple formatting bar (Bold, Italic,
/// Underline, Strikethrough, Bullet list, Numbered list, Undo/Redo, Clear) and
/// zero visible formatting symbols.
class RichMessageComposer extends StatefulWidget {
  final RichBroadcastTextController controller;
  final int maxLength;

  const RichMessageComposer({
    super.key,
    required this.controller,
    this.maxLength = 2000,
  });

  @override
  State<RichMessageComposer> createState() => _RichMessageComposerState();
}

class _RichMessageComposerState extends State<RichMessageComposer> {
  final FocusNode _focusNode = FocusNode();
  final UndoHistoryController _undoController = UndoHistoryController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant RichMessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.dispose();
    _undoController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _toggle(int flag) {
    widget.controller.toggleStyle(flag);
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  void _toggleList({required bool numbered}) {
    widget.controller.toggleList(numbered: numbered);
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  void _clear() {
    widget.controller.clearFormatting();
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.controller.activeMask;
    final len = widget.controller.text.length;
    final overLimit = len > widget.maxLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Simple WYSIWYG formatting bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: PhonebookTheme.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: PhonebookTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ToolbarButton(
                        icon: Icons.format_bold_rounded,
                        tooltip: 'Bold',
                        active: (active & BroadcastStyleFlags.bold) != 0,
                        onTap: () => _toggle(BroadcastStyleFlags.bold),
                      ),
                      _ToolbarButton(
                        icon: Icons.format_italic_rounded,
                        tooltip: 'Italic',
                        active: (active & BroadcastStyleFlags.italic) != 0,
                        onTap: () => _toggle(BroadcastStyleFlags.italic),
                      ),
                      _ToolbarButton(
                        icon: Icons.format_underlined_rounded,
                        tooltip: 'Underline',
                        active: (active & BroadcastStyleFlags.underline) != 0,
                        onTap: () => _toggle(BroadcastStyleFlags.underline),
                      ),
                      _ToolbarButton(
                        icon: Icons.strikethrough_s_rounded,
                        tooltip: 'Strikethrough',
                        active: (active & BroadcastStyleFlags.strike) != 0,
                        onTap: () => _toggle(BroadcastStyleFlags.strike),
                      ),
                      const _ToolbarDivider(),
                      _ToolbarButton(
                        icon: Icons.format_list_bulleted_rounded,
                        tooltip: 'Bullet list',
                        active: widget.controller.isBulletActive,
                        onTap: () => _toggleList(numbered: false),
                      ),
                      _ToolbarButton(
                        icon: Icons.format_list_numbered_rounded,
                        tooltip: 'Numbered list',
                        active: widget.controller.isNumberedActive,
                        onTap: () => _toggleList(numbered: true),
                      ),
                      const _ToolbarDivider(),
                      ValueListenableBuilder<UndoHistoryValue>(
                        valueListenable: _undoController,
                        builder: (_, undoVal, _) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ToolbarButton(
                              icon: Icons.undo_rounded,
                              tooltip: 'Undo',
                              enabled: undoVal.canUndo,
                              onTap: _undoController.undo,
                            ),
                            _ToolbarButton(
                              icon: Icons.redo_rounded,
                              tooltip: 'Redo',
                              enabled: undoVal.canRedo,
                              onTap: _undoController.redo,
                            ),
                          ],
                        ),
                      ),
                      _ToolbarButton(
                        icon: Icons.format_clear_rounded,
                        tooltip: 'Clear formatting',
                        onTap: _clear,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 6),
                child: Text(
                  '$len/${widget.maxLength}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: overLimit ? PhonebookTheme.red : PhonebookTheme.muted,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Live WYSIWYG text editor (no Title field, no raw symbols)
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          undoController: _undoController,
          maxLength: widget.maxLength,
          minLines: 6,
          maxLines: 14,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            color: PhonebookTheme.ink,
            fontSize: 15,
            height: 1.5,
          ),
          decoration: const InputDecoration(
            hintText: 'Write your message here…',
            hintStyle: TextStyle(color: PhonebookTheme.muted, fontSize: 14.5),
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              borderSide: BorderSide(color: PhonebookTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              borderSide: BorderSide(color: PhonebookTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              borderSide: BorderSide(color: PhonebookTheme.blue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.active = false,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active ? PhonebookTheme.blueSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(color: PhonebookTheme.blue.withValues(alpha: 0.35))
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: !enabled
                ? PhonebookTheme.border
                : (active ? PhonebookTheme.blue : PhonebookTheme.ink),
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: PhonebookTheme.border,
    );
  }
}
