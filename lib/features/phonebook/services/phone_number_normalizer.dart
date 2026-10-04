/// Indian mobile-number normalisation shared by the phonebook cache, the
/// search, and caller ID on both platforms.
///
/// Numbers arrive from the directory API as `7984907753`, `079849 07753`,
/// `+91-79849-07753`, `91 7984907753`… and from the telephony stack as
/// `+917984907753`. All of those must map to the same key.
class PhoneNumberNormalizer {
  PhoneNumberNormalizer._();

  static final _nonDigits = RegExp(r'\D');

  /// The 10 national digits (`7984907753`), or null if this isn't a usable
  /// mobile/landline number. This is what `phone_normalized` stores and what
  /// the Kotlin / Swift lookups compare against.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    var d = raw.replaceAll(_nonDigits, '');
    if (d.isEmpty) return null;
    // Strip trunk prefix / country code: 0XXXXXXXXXX, 91XXXXXXXXXX, 0091…
    if (d.length > 10 && d.startsWith('00')) d = d.substring(2);
    if (d.length > 10 && d.startsWith('91')) d = d.substring(2);
    if (d.length > 10 && d.startsWith('0')) d = d.substring(1);
    if (d.length != 10) return null;
    return d;
  }

  /// E.164 as an integer (`917984907753`) — the format CallKit requires.
  static int? toE164Int(String? raw) {
    final n = normalize(raw);
    return n == null ? null : int.tryParse('91$n');
  }

  /// `+91 79849 07753` for display.
  static String pretty(String? raw) {
    final n = normalize(raw);
    if (n == null) return raw ?? '';
    return '+91 ${n.substring(0, 5)} ${n.substring(5)}';
  }
}
