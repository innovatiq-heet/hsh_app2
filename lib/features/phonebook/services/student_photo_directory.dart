import 'package:flutter/foundation.dart';
import '../../../core/utils/student_photo.dart';
import 'phonebook_database_service.dart';

/// Photo addresses for screens that know a student only by bank code
/// (birthdays, daily alumni, directories). The photo is named after the
/// Aadhar, which only the phonebook synced on this phone has, so a phone that
/// never synced it shows no photos.
///
/// Display only: never use it to pick a student for an action. A code that
/// several phonebook rows disagree on gets no photo rather than a guess.
class StudentPhotoDirectory {
  StudentPhotoDirectory._();

  static final StudentPhotoDirectory instance = StudentPhotoDirectory._();

  /// Bumped when the index was (re)loaded, so avatars rebuild.
  final ValueNotifier<int> version = ValueNotifier<int>(0);

  Map<String, String> _aadharByCode = const {};
  Future<void>? _loading;

  /// Loads the index once. An empty result (phonebook not synced yet) is not
  /// kept, so the next avatar to appear tries again.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final index = await PhonebookDatabaseService.instance.aadharByBankCode();
      _aadharByCode = index;
      if (index.isNotEmpty) version.value++;
      if (index.isEmpty) _loading = null;
    } catch (_) {
      _loading = null;
    }
  }

  /// Drops the index, e.g. after a phonebook sync or on logout.
  void reset() {
    _aadharByCode = const {};
    _loading = null;
    version.value++;
  }

  String? urlForBankCode(String? bankCode, {PhotoOf who = PhotoOf.student}) =>
      familyPhotoUrl(aadharForBankCode(bankCode), who);

  /// The student's Aadhar for [bankCode], from the synced phonebook.
  String? aadharForBankCode(String? bankCode) {
    final key = PhonebookDatabaseService.normalizeBankCode(bankCode ?? '');
    if (key.isEmpty) return null;
    return _aadharByCode[key];
  }
}
