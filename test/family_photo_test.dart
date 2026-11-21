import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/utils/student_photo.dart';

/// Student, father and mother photos are all named after the student's
/// 12-digit Aadhar, each in its own folder.
void main() {
  const base = 'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com';

  test('each family member has their own folder, keyed by the student Aadhar', () {
    expect(familyPhotoUrl('3423 7411 5218', PhotoOf.student), '$base/student/personal/342374115218.jpg');
    expect(familyPhotoUrl('342374115218', PhotoOf.father), '$base/father/personal/342374115218.jpg');
    expect(familyPhotoUrl('342374115218', PhotoOf.mother), '$base/mother/personal/342374115218.jpg');
    // The student helper is unchanged.
    expect(studentPhotoUrl('342374115218'), '$base/student/personal/342374115218.jpg');
  });

  test('no photo without a full 12-digit Aadhar (a bank code never qualifies)', () {
    for (final bad in [null, '', '0768', '12345678901', '1234567890123']) {
      expect(familyPhotoUrl(bad, PhotoOf.father), isNull, reason: '$bad');
      expect(familyPhotoUrl(bad, PhotoOf.mother), isNull, reason: '$bad');
    }
  });
}
