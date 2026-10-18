import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/features/phonebook/models/phonebook_models.dart';

void main() {
  group('PhonebookStudent Model & Formatted Getters', () {
    test('Correctly computes age, formattedDob, maskedAadhar, and motherName', () {
      final student = PhonebookStudent(
        id: '101',
        studentId: '101',
        name: 'Rudra Ketanbhai Patel',
        enrollmentNumber: 'EN101',
        department: 'B.Tech IT',
        batch: 'ACTIVE',
        phones: const [
          PhonebookContact(phone: '9876543210', phoneNormalized: '9876543210', label: 'Mobile')
        ],
        room: 'B-204',
        groupName: 'B-Wing',
        fatherName: 'Ketanbhai Patel',
        motherName: 'Meenaben Patel',
        fatherPhone: '9825012345',
        motherPhone: '9825054321',
        whatsappNumber: '9876543210',
        dob: '2007-03-29',
        aadhar: '123456789012',
        address: '12, Shanti Nagar, Anand',
        pinCode: '388001',
        bloodGroup: 'B+',
        status: 'Active',
        bankCode: '0768',
        floor: 2,
      );

      expect(student.name, 'Rudra Ketanbhai Patel');
      expect(student.room, 'B-204');
      expect(student.groupName, 'B-Wing');
      expect(student.primaryPhone, '9876543210');
      expect(student.fatherName, 'Ketanbhai Patel');
      expect(student.motherName, 'Meenaben Patel');
      expect(student.hasMotherName, isTrue);
      expect(student.fatherPhone, '9825012345');
      expect(student.motherPhone, '9825054321');
      expect(student.hasDob, isTrue);
      expect(student.hasFatherPhone, isTrue);
      expect(student.hasMotherPhone, isTrue);
      expect(student.hasWhatsApp, isTrue);
      expect(student.isAlumni, isFalse);
      expect(student.maskedAadhar, '•••• •••• 9012');
      expect(student.formattedDob, contains('2007'));
      expect(student.ageText, isNotEmpty);
      expect(student.displayAddress, contains('Shanti Nagar'));

      // Test toShareText()
      final shareText = student.toShareText();
      expect(shareText, contains('Rudra Ketanbhai Patel'));
      expect(shareText, contains('B-204'));
      expect(shareText, contains('B-Wing'));
      expect(shareText, contains('9876543210'));
      expect(shareText, contains('Ketanbhai Patel'));
      expect(shareText, contains('Meenaben Patel'));
      expect(shareText, contains('12, Shanti Nagar'));
      expect(shareText, contains('101'));
    });

    test('Generates default campus residence address when explicit address is empty', () {
      final student = const PhonebookStudent(
        id: '102',
        studentId: '102',
        name: 'Aakash Sharma',
        enrollmentNumber: 'EN102',
        department: 'Diploma CE',
        batch: 'ACTIVE',
        phones: [
          PhonebookContact(phone: '9898989898', phoneNormalized: '9898989898', label: 'Mobile')
        ],
        room: 'A-102',
        groupName: 'A-Wing',
      );

      expect(student.hasDob, isFalse);
      expect(student.hasFatherPhone, isFalse);
      expect(student.hasMotherName, isFalse);
      expect(student.motherName, isNull);
      expect(student.maskedAadhar, 'Not Provided');
      expect(student.formattedDob, 'Not Provided');
      expect(student.ageText, '');
      expect(student.displayAddress, contains('Room A-102, A-Wing'));
      expect(student.displayAddress, contains('Hari Smruti Hostel (HSH)'));

      final shareText = student.toShareText();
      expect(shareText, contains('Aakash Sharma'));
      expect(shareText, contains('A-102'));
      expect(shareText, contains('A-Wing'));
      expect(shareText, contains('Hari Smruti Hostel (HSH)'));
    });

    test('Handles JSON / SQLite map deserialization via PhonebookStudent.fromJson including motherName', () {
      final map = {
        'id': '103',
        'student_id': '103',
        'name': 'Jayesh Parmar',
        'enrollment_number': 'EN103',
        'department': 'B.Pharm',
        'batch': 'ALUMNI',
        'phone': '9123456789',
        'room': 'C-301',
        'group_name': 'C-Wing',
        'father_name': 'Rameshbhai',
        'mother_name': 'Shilpaben',
        'father_phone': '9426011111',
        'mother_phone': '9426022222',
        'whatsapp_number': '9123456789',
        'dob': '2005-11-14',
        'aadhar': '987654321098',
        'address': 'Bunglow 4, Nadiad',
        'pin_code': '387001',
        'blood_group': 'O+',
        'status': 'Alumni',
        'bank_code': '1043',
        'floor': 3,
      };

      final restored = PhonebookStudent.fromJson(map);

      expect(restored.id, '103');
      expect(restored.name, 'Jayesh Parmar');
      expect(restored.primaryPhone, '9123456789');
      expect(restored.room, 'C-301');
      expect(restored.fatherName, 'Rameshbhai');
      expect(restored.motherName, 'Shilpaben');
      expect(restored.hasMotherName, isTrue);
      expect(restored.fatherPhone, '9426011111');
      expect(restored.motherPhone, '9426022222');
      expect(restored.dob, '2005-11-14');
      expect(restored.aadhar, '987654321098');
      expect(restored.bloodGroup, 'O+');
      expect(restored.status, 'Alumni');
      expect(restored.isAlumni, isTrue);
      expect(restored.bankCode, '1043');
      expect(restored.floor, 3);
    });
  });
}
