import 'package:flutter/material.dart';

/// Supported inline text styles for Broadcast messages.
enum BroadcastInlineFormat {
  bold('*', '*'),
  italic('_', '_'),
  underline('<u>', '</u>'),
  strikethrough('~', '~'),
  code('`', '`');

  final String open;
  final String close;
  const BroadcastInlineFormat(this.open, this.close);
}

/// Supported line-level block formats for Broadcast messages.
enum BroadcastLineFormat {
  heading,
  bullet,
  numbered,
  quote,
}

/// Rich text editing, live editor highlighting, clean preview rendering, and
/// plain-text extraction for Broadcast messages.
class BroadcastRichTextHelper {
  BroadcastRichTextHelper._();

  static final RegExp _orderedPrefixRe = RegExp(r'^(\s*)(\d+)\.\s+');
  static final RegExp _bulletPrefixRe = RegExp(r'^(\s*)([-•])\s+');
  static final RegExp _headingPrefixRe = RegExp(r'^(\s*)#\s+');
  static final RegExp _quotePrefixRe = RegExp(r'^(\s*)>\s+');
  static final RegExp _dividerLineRe = RegExp(r'^\s*---\s*$');

  /// Toggles an inline style on the current selection, or inserts markers at the
  /// collapsed cursor so the author can type styled text immediately.
  static TextEditingValue toggleInlineFormat(
    TextEditingValue value,
    BroadcastInlineFormat format,
  ) {
    final text = value.text;
    final sel = value.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final lo = start < end ? start : end;
    final hi = start < end ? end : start;

    final open = format.open;
    final close = format.close;

    // Collapsed cursor: insert open+close and place cursor between them.
    if (lo == hi) {
      // If cursor is already inside empty markers (e.g. `*|` + `*`), step out.
      if (lo >= open.length &&
          lo + close.length <= text.length &&
          text.substring(lo - open.length, lo) == open &&
          text.substring(lo, lo + close.length) == close) {
        final next =
            text.substring(0, lo - open.length) + text.substring(lo + close.length);
        return TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: lo - open.length),
        );
      }
      final next = '${text.substring(0, lo)}$open$close${text.substring(hi)}';
      return TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: lo + open.length),
      );
    }

    final selected = text.substring(lo, hi);

    // 1. Exact outer match immediately outside the selection: `open[sel]close`
    if (lo >= open.length &&
        hi + close.length <= text.length &&
        text.substring(lo - open.length, lo) == open &&
        text.substring(hi, hi + close.length) == close) {
      final next = text.substring(0, lo - open.length) +
          selected +
          text.substring(hi + close.length);
      return TextEditingValue(
        text: next,
        selection: TextSelection(
          baseOffset: lo - open.length,
          extentOffset: hi - open.length,
        ),
      );
    }

    // 2. Selection itself starts & ends with this format's markers.
    if (selected.length >= open.length + close.length &&
        selected.startsWith(open) &&
        selected.endsWith(close)) {
      final inner = selected.substring(open.length, selected.length - close.length);
      final next = '${text.substring(0, lo)}$inner${text.substring(hi)}';
      return TextEditingValue(
        text: next,
        selection: TextSelection(
          baseOffset: lo,
          extentOffset: lo + inner.length,
        ),
      );
    }

    // 3. Selection already contains a nested occurrence of this marker (e.g.
    // toggling Bold off while Italic/Underline wraps outside it).
    final nestedOpen = selected.indexOf(open);
    if (nestedOpen != -1) {
      final nestedClose =
          selected.lastIndexOf(close);
      if (nestedClose > nestedOpen + open.length - 1 &&
          nestedClose != nestedOpen) {
        final stripped = selected.substring(0, nestedOpen) +
            selected.substring(nestedOpen + open.length, nestedClose) +
            selected.substring(nestedClose + close.length);
        final next = '${text.substring(0, lo)}$stripped${text.substring(hi)}';
        return TextEditingValue(
          text: next,
          selection: TextSelection(
            baseOffset: lo,
            extentOffset: lo + stripped.length,
          ),
        );
      }
    }

    // Otherwise wrap the selection and keep the wrapped text selected so
    // multiple styles (Bold + Italic + Underline + Strikethrough) stack easily.
    final wrapped = '$open$selected$close';
    final next = '${text.substring(0, lo)}$wrapped${text.substring(hi)}';
    return TextEditingValue(
      text: next,
      selection: TextSelection(
        baseOffset: lo,
        extentOffset: lo + wrapped.length,
      ),
    );
  }

  /// Toggles a line-level block prefix across all selected lines (or current line).
  static TextEditingValue toggleLineFormat(
    TextEditingValue value,
    BroadcastLineFormat format,
  ) {
    final text = value.text;
    final sel = value.selection;
    final lo = sel.isValid ? (sel.start < sel.end ? sel.start : sel.end) : text.length;
    final hi = sel.isValid ? (sel.start < sel.end ? sel.end : sel.start) : text.length;

    final blockStart = lo == 0 ? 0 : (text.lastIndexOf('\n', lo - 1) + 1);
    final rawEndSearch = hi > lo && hi > 0 && text[hi - 1] == '\n' ? hi - 1 : hi;
    final nextNl = text.indexOf('\n', rawEndSearch);
    final blockEnd = nextNl == -1 ? text.length : nextNl;

    final blockText = text.substring(blockStart, blockEnd);
    final lines = blockText.split('\n');

    bool matchesLine(String line) {
      switch (format) {
        case BroadcastLineFormat.heading:
          return _headingPrefixRe.hasMatch(line);
        case BroadcastLineFormat.bullet:
          return _bulletPrefixRe.hasMatch(line);
        case BroadcastLineFormat.numbered:
          return _orderedPrefixRe.hasMatch(line);
        case BroadcastLineFormat.quote:
          return _quotePrefixRe.hasMatch(line);
      }
    }

    String stripBlockPrefixes(String line) {
      var out = line;
      out = out.replaceFirst(_headingPrefixRe, '');
      out = out.replaceFirst(_bulletPrefixRe, '');
      out = out.replaceFirst(_orderedPrefixRe, '');
      out = out.replaceFirst(_quotePrefixRe, '');
      return out;
    }

    final allAlreadyMatch =
        lines.where((l) => l.trim().isNotEmpty).isNotEmpty &&
        lines.every((l) => l.trim().isEmpty || matchesLine(l));

    final updatedLines = <String>[];
    var orderNum = 1;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (lines.length > 1 && line.trim().isEmpty) {
        updatedLines.add(line);
        continue;
      }
      final clean = stripBlockPrefixes(line);
      if (allAlreadyMatch) {
        updatedLines.add(clean);
      } else {
        switch (format) {
          case BroadcastLineFormat.heading:
            updatedLines.add('# $clean');
          case BroadcastLineFormat.bullet:
            updatedLines.add('- $clean');
          case BroadcastLineFormat.numbered:
            updatedLines.add('${orderNum++}. $clean');
          case BroadcastLineFormat.quote:
            updatedLines.add('> $clean');
        }
      }
    }

    final replacement = updatedLines.join('\n');
    final nextText =
        '${text.substring(0, blockStart)}$replacement${text.substring(blockEnd)}';
    final endOffset = blockStart + replacement.length;
    return TextEditingValue(
      text: nextText,
      selection: lo == hi
          ? TextSelection.collapsed(offset: endOffset)
          : TextSelection(baseOffset: blockStart, extentOffset: endOffset),
    );
  }

  /// Inserts a horizontal divider (`---`) cleanly on its own line.
  static TextEditingValue insertDivider(TextEditingValue value) {
    final text = value.text;
    final sel = value.selection;
    final offset = sel.isValid ? sel.extentOffset : text.length;
    final before = text.substring(0, offset);
    final after = text.substring(offset);
    final prefix = (before.isEmpty || before.endsWith('\n')) ? '' : '\n';
    final suffix = (after.isEmpty || after.startsWith('\n')) ? '\n' : '\n';
    final insertion = '$prefix---$suffix';
    return TextEditingValue(
      text: '$before$insertion$after',
      selection: TextSelection.collapsed(offset: offset + insertion.length),
    );
  }

  /// Strips formatting markers from the selection (or entire text if collapsed).
  static TextEditingValue clearFormatting(TextEditingValue value) {
    final text = value.text;
    final sel = value.selection;
    final hasSelection = sel.isValid && !sel.isCollapsed;
    if (!hasSelection) {
      final plain = toPlainText(text, keepListPrefixes: true);
      return TextEditingValue(
        text: plain,
        selection: TextSelection.collapsed(offset: plain.length),
      );
    }
    final lo = sel.start < sel.end ? sel.start : sel.end;
    final hi = sel.start < sel.end ? sel.end : sel.start;
    final chunk = text.substring(lo, hi);
    final cleaned = toPlainText(chunk, keepListPrefixes: true);
    final nextText = '${text.substring(0, lo)}$cleaned${text.substring(hi)}';
    return TextEditingValue(
      text: nextText,
      selection: TextSelection(baseOffset: lo, extentOffset: lo + cleaned.length),
    );
  }

  /// Returns which inline/line formats are active at the current cursor/selection.
  static Set<BroadcastInlineFormat> activeInlineFormats(TextEditingValue value) {
    final active = <BroadcastInlineFormat>{};
    final text = value.text;
    final sel = value.selection;
    if (!sel.isValid || text.isEmpty) return active;
    final lo = sel.start < sel.end ? sel.start : sel.end;
    final hi = sel.start < sel.end ? sel.end : sel.start;
    final sample = lo == hi ? '' : text.substring(lo, hi);
    for (final f in BroadcastInlineFormat.values) {
      if (lo >= f.open.length &&
          hi + f.close.length <= text.length &&
          text.substring(lo - f.open.length, lo) == f.open &&
          text.substring(hi, hi + f.close.length) == f.close) {
        active.add(f);
      } else if (sample.contains(f.open) &&
          sample.contains(f.close) &&
          sample.indexOf(f.open) < sample.lastIndexOf(f.close)) {
        active.add(f);
      }
    }
    return active;
  }

  static BroadcastLineFormat? activeLineFormat(TextEditingValue value) {
    final text = value.text;
    final sel = value.selection;
    final pos = sel.isValid ? sel.start : text.length;
    final lineStart = pos == 0 ? 0 : (text.lastIndexOf('\n', pos - 1) + 1);
    final nextNl = text.indexOf('\n', lineStart);
    final line = text.substring(lineStart, nextNl == -1 ? text.length : nextNl);
    if (_headingPrefixRe.hasMatch(line)) return BroadcastLineFormat.heading;
    if (_bulletPrefixRe.hasMatch(line)) return BroadcastLineFormat.bullet;
    if (_orderedPrefixRe.hasMatch(line)) return BroadcastLineFormat.numbered;
    if (_quotePrefixRe.hasMatch(line)) return BroadcastLineFormat.quote;
    return null;
  }

  /// Converts rich formatted markup into clean plain text (preserving newlines).
  static String toPlainText(String input, {bool keepListPrefixes = false}) {
    final lines = input.split('\n');
    final out = <String>[];
    for (final rawLine in lines) {
      if (_dividerLineRe.hasMatch(rawLine)) {
        if (keepListPrefixes) continue;
        out.add('──────────');
        continue;
      }
      var line = rawLine;
      String prefix = '';
      if (_headingPrefixRe.hasMatch(line)) {
        line = line.replaceFirst(_headingPrefixRe, '');
      } else if (_quotePrefixRe.hasMatch(line)) {
        line = line.replaceFirst(_quotePrefixRe, '');
        if (!keepListPrefixes) prefix = '“';
      } else if (_bulletPrefixRe.hasMatch(line)) {
        line = line.replaceFirst(_bulletPrefixRe, '');
        prefix = keepListPrefixes ? '' : '• ';
      } else if (_orderedPrefixRe.hasMatch(line)) {
        final m = _orderedPrefixRe.firstMatch(line);
        if (m != null) {
          prefix = keepListPrefixes ? '' : '${m.group(2)}. ';
          line = line.substring(m.end);
        }
      }

      final stripped = _stripInlineMarkers(line);
      out.add(prefix == '“' ? '“$stripped”' : '$prefix$stripped');
    }
    return out.join('\n');
  }

  static String _stripInlineMarkers(String text) {
    final buf = StringBuffer();
    for (final span in _tokenizeInline(text)) {
      buf.write(span.plainText);
    }
    return buf.toString();
  }

  /// Builds an inline [TextSpan] for the live `TextField` that keeps **every**
  /// character in [text] at its exact index while styling bold, italic,
  /// underline, strikethrough, code, headings, quotes, lists, and dividers.
  static TextSpan buildEditorSpan(String text, TextStyle? baseStyle) {
    final base = baseStyle ?? const TextStyle(fontSize: 14, color: Color(0xFF0F172A));
    final markerStyle = base.copyWith(
      color: (base.color ?? const Color(0xFF0F172A)).withValues(alpha: 0.34),
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
    );

    final children = <InlineSpan>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      var content = line;
      var lineStyle = base;
      String prefixToken = '';

      if (_dividerLineRe.hasMatch(line)) {
        children.add(TextSpan(text: line, style: markerStyle));
      } else {
        final headingMatch = _headingPrefixRe.firstMatch(line);
        final quoteMatch = _quotePrefixRe.firstMatch(line);
        final bulletMatch = _bulletPrefixRe.firstMatch(line);
        final orderMatch = _orderedPrefixRe.firstMatch(line);

        if (headingMatch != null) {
          prefixToken = line.substring(0, headingMatch.end);
          content = line.substring(headingMatch.end);
          lineStyle = base.copyWith(
            fontSize: (base.fontSize ?? 14) + 2.5,
            fontWeight: FontWeight.w800,
          );
        } else if (quoteMatch != null) {
          prefixToken = line.substring(0, quoteMatch.end);
          content = line.substring(quoteMatch.end);
          lineStyle = base.copyWith(
            color: (base.color ?? const Color(0xFF0F172A)).withValues(alpha: 0.72),
            fontStyle: FontStyle.italic,
          );
        } else if (bulletMatch != null) {
          prefixToken = line.substring(0, bulletMatch.end);
          content = line.substring(bulletMatch.end);
        } else if (orderMatch != null) {
          prefixToken = line.substring(0, orderMatch.end);
          content = line.substring(orderMatch.end);
        }

        if (prefixToken.isNotEmpty) {
          children.add(
            TextSpan(
              text: prefixToken,
              style: base.copyWith(
                color: const Color(0xFF0284C7),
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        _appendInlineTokens(
          content,
          lineStyle,
          markerStyle: markerStyle,
          includeMarkers: true,
          out: children,
        );
      }

      if (i < lines.length - 1) {
        children.add(TextSpan(text: '\n', style: base));
      }
    }
    return TextSpan(style: base, children: children);
  }

  /// Parses an inline string for display (omits markers and applies styles).
  static TextSpan buildInlineDisplaySpan(String text, TextStyle baseStyle) {
    final children = <InlineSpan>[];
    _appendInlineTokens(
      text,
      baseStyle,
      markerStyle: baseStyle,
      includeMarkers: false,
      out: children,
    );
    return TextSpan(style: baseStyle, children: children);
  }

  static void _appendInlineTokens(
    String text,
    TextStyle style, {
    required TextStyle markerStyle,
    required bool includeMarkers,
    required List<InlineSpan> out,
  }) {
    for (final node in _tokenizeInline(text)) {
      if (node.isMarker) {
        if (includeMarkers) {
          out.add(TextSpan(text: node.raw, style: markerStyle));
        }
      } else {
        final merged = _applyStyles(style, node.formats);
        out.add(TextSpan(text: node.raw, style: merged));
      }
    }
  }

  static TextStyle _applyStyles(TextStyle base, Set<BroadcastInlineFormat> fmts) {
    if (fmts.isEmpty) return base;
    var s = base;
    final decorations = <TextDecoration>[
      if (base.decoration != null && base.decoration != TextDecoration.none)
        base.decoration!,
    ];
    if (fmts.contains(BroadcastInlineFormat.bold)) {
      s = s.copyWith(fontWeight: FontWeight.w700);
    }
    if (fmts.contains(BroadcastInlineFormat.italic)) {
      s = s.copyWith(fontStyle: FontStyle.italic);
    }
    if (fmts.contains(BroadcastInlineFormat.underline)) {
      decorations.add(TextDecoration.underline);
    }
    if (fmts.contains(BroadcastInlineFormat.strikethrough)) {
      decorations.add(TextDecoration.lineThrough);
    }
    if (fmts.contains(BroadcastInlineFormat.code)) {
      s = s.copyWith(
        fontFamily: 'monospace',
        backgroundColor: const Color(0xFFF1F5F9),
      );
    }
    if (decorations.isNotEmpty) {
      s = s.copyWith(decoration: TextDecoration.combine(decorations));
    }
    return s;
  }

  static List<_InlineChunk> _tokenizeInline(
    String input, [
    Set<BroadcastInlineFormat> active = const {},
  ]) {
    final out = <_InlineChunk>[];
    final buf = StringBuffer();
    var i = 0;

    void flushPlain() {
      if (buf.isNotEmpty) {
        out.add(_InlineChunk(buf.toString(), active, isMarker: false));
        buf.clear();
      }
    }

    while (i < input.length) {
      // 1. <u>...</u> underline
      if (!active.contains(BroadcastInlineFormat.underline) &&
          input.startsWith('<u>', i)) {
        final closeIdx = input.indexOf('</u>', i + 3);
        if (closeIdx > i + 3) {
          flushPlain();
          out.add(_InlineChunk('<u>', active, isMarker: true));
          out.addAll(_tokenizeInline(
            input.substring(i + 3, closeIdx),
            {...active, BroadcastInlineFormat.underline},
          ));
          out.add(_InlineChunk('</u>', active, isMarker: true));
          i = closeIdx + 4;
          continue;
        }
      }

      // 2. Single-character delimiters: `*`, `_`, `~`, `` ` ``
      final ch = input[i];
      BroadcastInlineFormat? fmt;
      if (ch == '*' && !active.contains(BroadcastInlineFormat.bold)) {
        fmt = BroadcastInlineFormat.bold;
      } else if (ch == '_' && !active.contains(BroadcastInlineFormat.italic)) {
        fmt = BroadcastInlineFormat.italic;
      } else if (ch == '~' &&
          !active.contains(BroadcastInlineFormat.strikethrough)) {
        fmt = BroadcastInlineFormat.strikethrough;
      } else if (ch == '`' && !active.contains(BroadcastInlineFormat.code)) {
        fmt = BroadcastInlineFormat.code;
      }

      if (fmt != null) {
        final closeIdx = _findClosingMarker(input, i + 1, ch);
        if (closeIdx > i + 1) {
          flushPlain();
          out.add(_InlineChunk(ch, active, isMarker: true));
          out.addAll(_tokenizeInline(
            input.substring(i + 1, closeIdx),
            {...active, fmt},
          ));
          out.add(_InlineChunk(ch, active, isMarker: true));
          i = closeIdx + 1;
          continue;
        }
      }

      buf.write(ch);
      i++;
    }
    flushPlain();
    return out;
  }

  static int _findClosingMarker(String text, int from, String marker) {
    // Reject leading space (`* not bold*`) or empty (`**`).
    if (from >= text.length || text[from] == ' ') return -1;
    var search = from;
    while (search < text.length) {
      final idx = text.indexOf(marker, search);
      if (idx == -1) return -1;
      if (idx > from && text[idx - 1] != ' ') {
        return idx;
      }
      search = idx + 1;
    }
    return -1;
  }
}

class _InlineChunk {
  final String raw;
  final Set<BroadcastInlineFormat> formats;
  final bool isMarker;

  const _InlineChunk(this.raw, this.formats, {required this.isMarker});

  String get plainText => isMarker ? '' : raw;
}

/// Renders a formatted Broadcast message cleanly (bold, italic, underline,
/// strikethrough, inline code, headings, bullet/numbered lists, quotes, dividers).
class BroadcastRichText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool selectable;

  const BroadcastRichText({
    super.key,
    required this.text,
    this.style,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ??
        const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Color(0xFF1E293B),
          height: 1.5,
        );
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      if (BroadcastRichTextHelper._dividerLineRe.hasMatch(line)) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
        );
        continue;
      }

      final headingMatch = BroadcastRichTextHelper._headingPrefixRe.firstMatch(line);
      if (headingMatch != null) {
        final content = line.substring(headingMatch.end);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text.rich(
              BroadcastRichTextHelper.buildInlineDisplaySpan(
                content,
                base.copyWith(
                  fontSize: (base.fontSize ?? 15) + 2.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final quoteMatch = BroadcastRichTextHelper._quotePrefixRe.firstMatch(line);
      if (quoteMatch != null) {
        final content = line.substring(quoteMatch.end);
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(left: BorderSide(color: Color(0xFF0284C7), width: 3)),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Text.rich(
              BroadcastRichTextHelper.buildInlineDisplaySpan(
                content,
                base.copyWith(
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final bulletMatch = BroadcastRichTextHelper._bulletPrefixRe.firstMatch(line);
      if (bulletMatch != null) {
        final content = line.substring(bulletMatch.end);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•  ',
                  style: base.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0284C7),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    BroadcastRichTextHelper.buildInlineDisplaySpan(content, base),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      final orderMatch = BroadcastRichTextHelper._orderedPrefixRe.firstMatch(line);
      if (orderMatch != null) {
        final numLabel = '${orderMatch.group(2)}. ';
        final content = line.substring(orderMatch.end);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  numLabel,
                  style: base.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0284C7),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    BroadcastRichTextHelper.buildInlineDisplaySpan(content, base),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text.rich(
            BroadcastRichTextHelper.buildInlineDisplaySpan(line, base),
          ),
        ),
      );
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
    return selectable ? SelectionArea(child: column) : column;
  }
}
