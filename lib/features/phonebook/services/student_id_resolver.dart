import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/network/repository/students/student_picker_source.dart';
import '../../../core/network/repository/tags/tags_repository.dart';
import '../models/phonebook_models.dart';

/// Finds the numeric `students.id` of a phonebook student, for actions that
/// change data on the server. The phonebook itself has no `students.id`.
///
/// Never by bank code (they collide with other students' ids) and never by
/// name alone (AGENTS.md, student identity):
/// - [byAadhar]: the exact 12-digit Aadhar, which belongs to one person, when
///   exactly one student has it;
/// - [confirmFromList]: otherwise the admin picks the student by hand.
class StudentIdResolver {
  StudentIdResolver._();

  static TagsRepository get _tags =>
      Get.isRegistered<TagsRepository>() ? Get.find<TagsRepository>() : TagsRepository();

  /// The `students.id` whose Aadhar is exactly [aadhar] (12 digits), when
  /// exactly one row has it; else null.
  static int? idByAadhar(Iterable<Map> rows, String? aadhar) {
    final wanted = (aadhar ?? '').replaceAll(RegExp(r'\D'), '');
    if (wanted.length != 12) return null;
    int? found;
    for (final row in rows) {
      final a = '${row['aadhar'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
      if (a != wanted) continue;
      final id = studentIdOf(row);
      if (id == null) continue;
      if (found != null && found != id) return null; // two students: not certain
      found = id;
    }
    return found;
  }

  /// [student]'s id by Aadhar from the full student list (alumni included).
  static Future<int?> byAadhar(PhonebookStudent student) async {
    if ((student.aadhar ?? '').replaceAll(RegExp(r'\D'), '').length != 12) return null;
    try {
      return idByAadhar(await _tags.getStudentsForAssignment(), student.aadhar);
    } catch (_) {
      return null;
    }
  }

  /// Lists students whose name contains every word of [name] (alumni
  /// included) and lets the admin pick one. Null when cancelled or none.
  static Future<int?> confirmFromList(BuildContext context, String name) async {
    final List<PickableStudent> all;
    try {
      all = await StudentPickerSource(tags: _tags).load(includeAlumni: true);
    } catch (_) {
      return null;
    }
    final words = name.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (words.isEmpty || !context.mounted) return null;
    final candidates = all.where((s) {
      final n = s.name.toLowerCase();
      return words.every(n.contains);
    }).take(20).toList();
    if (candidates.isEmpty) return null;

    final picked = await showDialog<PickableStudent>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Confirm the student'),
        children: [
          for (final c in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(c),
              child: Text('${c.name} · ${c.isAlumni ? 'Alumni' : 'Room ${c.room}'}'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('None of these', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
    return picked?.id;
  }
}
