/// Utilities for Apple Contacts-style multi-word intelligent search with
/// support for Indian / Gujarati naming conventions (e.g. honorific suffixes like "bhai",
/// "kumar", "ben", "sinh", father's names, middle names, and out-of-order tokens).
abstract final class AppleSearchUtils {
  /// Strips common Gujarati / Indian honorific suffixes from names for flexible search matching.
  /// E.g. "Krutarthbhai" -> "Krutarth", "Nileshkumar" -> "Nilesh", "Hansaben" -> "Hansa".
  static String? getGujaratiNameStem(String token) {
    final lower = token.toLowerCase().trim();
    if (lower.length > 5 && lower.endsWith('bhai')) {
      return lower.substring(0, lower.length - 4);
    }
    if (lower.length > 6 && lower.endsWith('kumar')) {
      return lower.substring(0, lower.length - 5);
    }
    if (lower.length > 4 && lower.endsWith('ben')) {
      return lower.substring(0, lower.length - 3);
    }
    if (lower.length > 6 && lower.endsWith('bahen')) {
      return lower.substring(0, lower.length - 5);
    }
    if (lower.length > 5 && (lower.endsWith('sinh') || lower.endsWith('singh'))) {
      return lower.substring(0, lower.length - (lower.endsWith('singh') ? 5 : 4));
    }
    return null;
  }

  /// Splits user search query into distinct non-empty lowercase tokens.
  static List<String> tokenize(String query) {
    return query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Checks if a record matches all search tokens (Apple Contacts-style logical AND).
  /// Every token must match somewhere across the searchable fields.
  static bool matches({
    required String query,
    required String name,
    String? fatherName,
    String? motherName,
    String? room,
    String? code,
    String? phone,
  }) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return true;

    final nLower = name.toLowerCase().trim();
    final fLower = (fatherName ?? '').toLowerCase().trim();
    final mLower = (motherName ?? '').toLowerCase().trim();
    final rLower = (room ?? '').toLowerCase().trim();
    final cLower = (code ?? '').toLowerCase().trim();
    final pLower = (phone ?? '').toLowerCase().replaceAll(RegExp(r'\D'), '');

    return tokens.every((token) {
      final stem = getGujaratiNameStem(token);
      final tokenNum = token.replaceAll(RegExp(r'\D'), '');

      // Check name (both full token and suffix stem)
      if (nLower.contains(token) || (stem != null && stem.length >= 3 && nLower.contains(stem))) {
        return true;
      }

      // Check father / mother
      if (fLower.contains(token) || (stem != null && stem.length >= 3 && fLower.contains(stem))) {
        return true;
      }
      if (mLower.contains(token) || (stem != null && stem.length >= 3 && mLower.contains(stem))) {
        return true;
      }

      // Check room
      if (rLower.isNotEmpty && rLower.contains(token)) {
        return true;
      }

      // Check student / bank code
      if (cLower.isNotEmpty) {
        final cTrimmed = cLower.replaceFirst(RegExp(r'^0+'), '');
        final tTrimmed = token.replaceFirst(RegExp(r'^0+'), '');
        if (cLower.contains(token) || (tTrimmed.isNotEmpty && cTrimmed.contains(tTrimmed))) {
          return true;
        }
      }

      // Check phone digits
      if (tokenNum.length >= 3 && pLower.contains(tokenNum)) {
        return true;
      }

      return false;
    });
  }

  /// Calculates an Apple Contacts relevance score for ranking search results.
  /// Higher score = better match.
  static int computeScore({
    required List<String> tokens,
    required String name,
    String? fatherName,
    String? motherName,
    String? room,
    String? code,
    bool isAlumni = false,
  }) {
    if (tokens.isEmpty) return 0;
    int score = 0;

    final nameLower = name.toLowerCase().trim();
    final nameWords = nameLower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final fatherLower = (fatherName ?? '').toLowerCase().trim();
    final motherLower = (motherName ?? '').toLowerCase().trim();
    final roomLower = (room ?? '').toLowerCase().trim();
    final codeLower = (code ?? '').toLowerCase().trim();

    int tokensMatchedAsWordPrefix = 0;
    int tokensMatchedInName = 0;

    for (final t in tokens) {
      if (t.isEmpty) continue;
      final stem = getGujaratiNameStem(t);

      bool matchedTokenInName = false;
      bool matchedTokenAsWordPrefix = false;

      for (int i = 0; i < nameWords.length; i++) {
        final word = nameWords[i];
        final wordStem = getGujaratiNameStem(word);

        // Exact word match (e.g. "Solanki" == "solanki")
        if (word == t || (wordStem != null && wordStem == t) || (stem != null && word == stem)) {
          score += 60;
          matchedTokenAsWordPrefix = true;
          matchedTokenInName = true;
          if (i == 0) score += 25; // First name exact bonus
          if (i == nameWords.length - 1) score += 20; // Surname exact bonus
        }
        // Word prefix match (e.g. "Krutarthbhai" starts with "krutarth")
        else if (word.startsWith(t) || (stem != null && word.startsWith(stem))) {
          score += 45;
          matchedTokenAsWordPrefix = true;
          matchedTokenInName = true;
          if (i == 0) score += 20; // First name prefix bonus
          if (i == nameWords.length - 1) score += 15; // Surname prefix bonus
        }
        // Substring inside word
        else if (word.contains(t) || (stem != null && word.contains(stem))) {
          score += 15;
          matchedTokenInName = true;
        }
      }

      if (matchedTokenAsWordPrefix) tokensMatchedAsWordPrefix++;
      if (matchedTokenInName) tokensMatchedInName++;

      // Father name check
      if (fatherLower.isNotEmpty) {
        if (fatherLower.startsWith(t) || (stem != null && fatherLower.startsWith(stem))) {
          score += 25;
        } else if (fatherLower.contains(t) || (stem != null && fatherLower.contains(stem))) {
          score += 10;
        }
      }

      // Mother name check
      if (motherLower.isNotEmpty) {
        if (motherLower.startsWith(t)) {
          score += 20;
        } else if (motherLower.contains(t)) {
          score += 8;
        }
      }

      // Room number match
      if (roomLower.isNotEmpty && roomLower == t) {
        score += 35;
      } else if (roomLower.isNotEmpty && roomLower.contains(t)) {
        score += 15;
      }

      // Code match
      if (codeLower.isNotEmpty) {
        final cTrimmed = codeLower.replaceFirst(RegExp(r'^0+'), '');
        final tTrimmed = t.replaceFirst(RegExp(r'^0+'), '');
        if (codeLower == t || (tTrimmed.isNotEmpty && cTrimmed == tTrimmed)) {
          score += 40;
        }
      }
    }

    // Huge Apple Contacts bonus: all search tokens match as word prefixes in student's name
    if (tokensMatchedAsWordPrefix == tokens.length && tokens.length > 1) {
      score += 100;
    } else if (tokensMatchedInName == tokens.length && tokens.length > 1) {
      score += 50;
    }

    // Active residents rank higher than alumni when scores are close
    if (!isAlumni) {
      score += 5;
    }

    return score;
  }
}
