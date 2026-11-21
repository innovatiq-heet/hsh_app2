import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/models/birthday/birthday_models.dart';
import 'package:hsh_app2/features/birthday/controllers/admin_birthday_controller.dart';
import 'package:hsh_app2/features/birthday/models/parent_birthday.dart';
import 'package:hsh_app2/features/phonebook/models/phonebook_models.dart';

/// Parents' own birthdays (from the phonebook on this phone) and the father /
/// mother templates, which stay on this phone until hsh_api stores them.
void main() {
  PhonebookStudent student(
    String id,
    String name, {
    String? room = '204',
    String? group = 'Param',
    String? father,
    String? fatherPhone,
    String? fatherDob,
    String? mother,
    String? motherPhone,
    String? motherDob,
    String? aadhar,
  }) =>
      PhonebookStudent(
        id: id,
        studentId: id,
        name: name,
        enrollmentNumber: '',
        department: '',
        batch: '',
        room: room,
        groupName: group,
        fatherName: father,
        fatherPhone: fatherPhone,
        fatherDob: fatherDob,
        motherName: mother,
        motherPhone: motherPhone,
        motherDob: motherDob,
        aadhar: aadhar,
      );

  group('finding parents whose birthday is on a day', () {
    final day = DateTime(2026, 11, 22);

    test('matches day and month, works out the age, fathers first', () {
      final found = ParentBirthday.on([
        student('1', 'Rohan Shah',
            father: 'Chirag Shah', fatherPhone: '9974066375', fatherDob: '1972-11-22',
            mother: 'Mital Shah', motherPhone: '9427131874', motherDob: '1975-11-22'),
        student('2', 'Meet Patel', father: 'Amit Patel', fatherPhone: '9800000001', fatherDob: '1970-11-23'),
      ], day);

      expect(found.map((p) => p.parentName), ['Chirag Shah', 'Mital Shah']);
      expect(found.first.isFather, isTrue);
      expect(found.first.turning, 54);
      expect(found.first.relationLine, 'Father of Rohan Shah');
      expect(found.last.role, 'mother');
    });

    test('a parent of two siblings is listed once, with both children', () {
      final found = ParentBirthday.on([
        student('1', 'Rohan Shah', father: 'Chirag Shah', fatherPhone: '99740 66375', fatherDob: '1972-11-22'),
        student('2', 'Meet Shah', father: 'Chirag Shah', fatherPhone: '9974066375', fatherDob: '1972-11-22'),
      ], day);

      expect(found, hasLength(1));
      expect(found.single.studentNames, ['Rohan Shah', 'Meet Shah']);
      expect(found.single.relationLine, 'Father of Rohan Shah & Meet Shah');
    });

    test('a leader only sees their own group; unreadable or missing dates are skipped', () {
      final students = [
        student('1', 'A', group: 'Param', father: 'F1', fatherPhone: '9800000001', fatherDob: '1970-11-22'),
        student('2', 'B', group: 'Paramanand', father: 'F2', fatherPhone: '9800000002', fatherDob: '1970-11-22'),
        student('3', 'C', father: 'F3', fatherPhone: '9800000003', fatherDob: 'not a date'),
        student('4', 'D', father: 'F4', fatherPhone: '9800000004'),
      ];
      expect(ParentBirthday.on(students, day, group: 'param').map((p) => p.parentName), ['F1']);
      expect(ParentBirthday.on(students, day).map((p) => p.parentName), ['F1', 'F2']);
    });

    test('29 February is celebrated on 28 February in other years', () {
      final dob = DateTime(1972, 2, 29);
      expect(ParentBirthday.fallsOn(dob, DateTime(2027, 2, 28)), isTrue);
      expect(ParentBirthday.fallsOn(dob, DateTime(2028, 2, 28)), isFalse);
      expect(ParentBirthday.fallsOn(dob, DateTime(2028, 2, 29)), isTrue);
    });

    test('dates in yyyy-MM-dd and epoch milliseconds are read', () {
      expect(ParentBirthday.parseDob('1972-11-22'), DateTime(1972, 11, 22));
      expect(ParentBirthday.parseDob('1972-11-22T00:00:00.000Z'), DateTime(1972, 11, 22));
      // 22 Nov 1998 00:00 IST
      expect(ParentBirthday.parseDob('911673000000'), DateTime(1998, 11, 22));
      expect(ParentBirthday.parseDob(''), isNull);
      expect(ParentBirthday.parseDob('null'), isNull);
    });
  });

  group('father / mother templates', () {
    test('fill with the parent, their child and the age', () {
      final p = ParentBirthday.on([
        student('1', 'Rohan Shah', mother: 'Mital Chirag Shah', motherPhone: '9427131874', motherDob: '1975-11-22'),
      ], DateTime(2026, 11, 22)).single;
      final text = AdminBirthdayController.fillParentTemplate(
        'Dear {parent_name} ({first_name}), happy {age}th! Love from {student_name}.',
        p,
      );
      expect(text, 'Dear Mital Chirag Shah (Mital), happy 51th! Love from Rohan Shah.');
    });

    test('an older server: father / mother come from this phone and every kind has a default', () {
      const config = BirthdayConfigModel(
        templatesFromServer: true,
        templates: [
          BirthdayTemplate(id: 's1', name: 'S', body: 'Hi {student_name}', audience: 'student'),
          BirthdayTemplate(id: 'p1', name: 'P', body: 'Dear parent', audience: 'parent'),
        ],
        activeStudentTemplateId: 's1',
        activeParentTemplateId: 'p1',
      );
      final r = AdminBirthdayController.resolveTemplates(config, null, parentCache: {
        'templates': [
          {'id': 'f1', 'name': 'Dad', 'body': 'Happy birthday {parent_name}', 'audience': 'father'},
        ],
        'active': {'father': 'f1'},
      });

      expect(r.active['father'], 'f1');
      expect(r.templates.firstWhere((t) => t.id == 'f1').audience, 'father');
      // Mother had nothing saved: a default is created.
      final mother = r.templates.where((t) => t.audience == 'mother').toList();
      expect(mother, hasLength(1));
      expect(r.active['mother'], mother.single.id);
      expect(mother.single.body, AdminBirthdayController.defaultMotherTemplate);
    });

    test('a server that stores them is the source; the phone copy is ignored', () {
      final config = BirthdayConfigModel.fromJson({
        'messageTemplate': 'Hi',
        'templates': [
          {'id': 's1', 'name': 'S', 'body': 'Hi', 'audience': 'student'},
          {'id': 'f9', 'name': 'Server dad', 'body': 'From server', 'audience': 'father'},
        ],
        'activeStudentTemplateId': 's1',
        'activeFatherTemplateId': 'f9',
        'activeMotherTemplateId': null,
      });
      expect(config.supportsParentBirthdays, isTrue);

      final r = AdminBirthdayController.resolveTemplates(config, null, parentCache: {
        'templates': [
          {'id': 'f1', 'name': 'Phone dad', 'body': 'From phone', 'audience': 'father'},
        ],
        'active': {'father': 'f1'},
      });
      expect(r.active['father'], 'f9');
      expect(r.templates.any((t) => t.id == 'f1'), isFalse);
    });

    test('a just-upgraded server with no father / mother templates keeps the phone copy', () {
      final config = BirthdayConfigModel.fromJson({
        'messageTemplate': 'Hi',
        'templates': [
          {'id': 's1', 'name': 'S', 'body': 'Hi', 'audience': 'student'},
        ],
        'activeStudentTemplateId': 's1',
        'activeFatherTemplateId': null,
        'activeMotherTemplateId': null,
      });
      final r = AdminBirthdayController.resolveTemplates(config, null, parentCache: {
        'templates': [
          {'id': 'f1', 'name': 'Phone dad', 'body': 'From phone', 'audience': 'father'},
        ],
        'active': {'father': 'f1'},
      });
      expect(r.active['father'], 'f1');
      expect(r.templates.firstWhere((t) => t.id == 'f1').body, 'From phone');
    });

    test('an older server is never sent father / mother fields', () {
      final old = BirthdayConfigModel.fromJson({'messageTemplate': 'Hi', 'templates': []});
      expect(old.supportsParentBirthdays, isFalse);
      final json = old.copyWith(activeFatherTemplateId: 'f1').toJson();
      expect(json.containsKey('activeFatherTemplateId'), isFalse);
      expect(json.containsKey('activeMotherTemplateId'), isFalse);

      final supported = BirthdayConfigModel.fromJson({'messageTemplate': 'Hi', 'activeFatherTemplateId': null});
      expect(supported.copyWith(activeFatherTemplateId: 'f1').toJson()['activeFatherTemplateId'], 'f1');
    });

    test('unknown template kinds still read as student; father / mother are kept', () {
      final list = BirthdayTemplate.listFromJson([
        {'id': 'a', 'audience': 'father'},
        {'id': 'b', 'audience': 'mother'},
        {'id': 'c', 'audience': 'teacher'},
      ]);
      expect(list.map((t) => t.audience), ['father', 'mother', 'student']);
    });
  });
}
