import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/features/phonebook/models/phonebook_models.dart';

/// Education (branch, semester, college) is read from the cached directory
/// row (`course`, `semester`, `study_institute`); blanks stay missing so the
/// profile shows "-".
void main() {
  Map<String, dynamic> row(Map<String, dynamic> extra) => {
        'id': 'HSH-1131',
        'student_id': 'HSH-1131',
        'name': 'Prajval Patel',
        'enrollment_number': '',
        'department': '',
        'batch': '',
        ...extra,
      };

  test('branch, semester and college come through', () {
    final s = PhonebookStudent.fromJson(row({
      'course': 'Computer Engineering (CE)',
      'semester': '5',
      'study_institute': 'G H PATEL COLLEGE OF ENGINEERING AND TECHNOLOGY (GCET)',
    }));
    expect(s.course, 'Computer Engineering (CE)');
    expect(s.semester, '5');
    expect(s.studyInstitute, 'G H PATEL COLLEGE OF ENGINEERING AND TECHNOLOGY (GCET)');
  });

  test('blanks and "null" are missing', () {
    final s = PhonebookStudent.fromJson(row({'course': ' ', 'semester': 'null', 'studyInstitute': null}));
    expect(s.course, isNull);
    expect(s.semester, isNull);
    expect(s.studyInstitute, isNull);
  });
}
