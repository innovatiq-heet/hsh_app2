/// Utility functions for string formatting across the app.
library;

/// Formats a person's name into proper Title Case (capitalizes each word,
/// lowercases the rest).
///
/// Handles irregular casing (ALL CAPS, all lowercase, mixed/camelCase),
/// multiple consecutive spaces, hyphens (e.g. "Mary-Jane"), apostrophes
/// (e.g. "O'Connor"), initials/periods (e.g. "A.B. Patel"), and parenthesized
/// nicknames/aliases (e.g. "(Harsh)").
///
/// Returns an empty string if [raw] is null or contains only whitespace.
String formatPersonName(String? raw) {
  if (raw == null) return '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  return trimmed
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return '';

        final buffer = StringBuffer();
        bool capitalizeNext = true;

        for (int i = 0; i < word.length; i++) {
          final char = word[i];
          if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
            if (capitalizeNext) {
              buffer.write(char.toUpperCase());
              capitalizeNext = false;
            } else {
              buffer.write(char.toLowerCase());
            }
          } else {
            buffer.write(char);
            // Non-alphabetic delimiters reset capitalization for the following letter
            if (char == '-' ||
                char == '/' ||
                char == '(' ||
                char == '[' ||
                char == '.' ||
                char == "'") {
              capitalizeNext = true;
            }
          }
        }
        return buffer.toString();
      })
      .join(' ');
}

/// Up to two initials (first and last word), e.g. "Aadi Niraj Pandya" -> "AP".
/// "#" when there is no name.
String nameInitials(String name) {
  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '#';
  final first = String.fromCharCode(words.first.runes.first);
  final last = words.length > 1 ? String.fromCharCode(words.last.runes.first) : '';
  return '$first$last'.toUpperCase();
}
