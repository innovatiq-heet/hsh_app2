import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/features/phonebook/controllers/phonebook_controller.dart';
import 'package:hsh_app2/features/phonebook/models/phonebook_models.dart';

PhonebookStudent makeStudent({
  required String id,
  required String name,
  String? room,
  String? group,
}) {
  return PhonebookStudent(
    id: id,
    studentId: id,
    name: name,
    enrollmentNumber: 'EN_$id',
    department: 'Param',
    batch: 'ACTIVE',
    room: room,
    groupName: group ?? 'Param',
    phones: const [
      PhonebookContact(phone: '9876543210', phoneNormalized: '9876543210', label: 'Mobile')
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Room Number Natural Comparison & Sorting', () {
    test('parseRoomNumber correctly extracts number and suffix', () {
      final p2 = PhonebookController.parseRoomNumber('2');
      expect(p2.number, 2);
      expect(p2.suffix, '');

      final p10 = PhonebookController.parseRoomNumber('10');
      expect(p10.number, 10);
      expect(p10.suffix, '');

      final p101A = PhonebookController.parseRoomNumber('101A');
      expect(p101A.number, 101);
      expect(p101A.suffix, 'A');

      final pAlumni = PhonebookController.parseRoomNumber('Alumni');
      expect(pAlumni.number, 999999);
    });

    test('Room 2 sorts before Room 10 in ascending order (numeric sorting)', () {
      final s2 = makeStudent(id: '2', name: 'Student Two', room: '2');
      final s10 = makeStudent(id: '10', name: 'Student Ten', room: '10');

      final list = [s10, s2];
      list.sort((a, b) => PhonebookController.compareRooms(a, b, ascending: true));

      expect(list[0].room, '2');
      expect(list[1].room, '10');
    });

    test('Room 10 sorts before Room 2 in descending order', () {
      final s2 = makeStudent(id: '2', name: 'Student Two', room: '2');
      final s10 = makeStudent(id: '10', name: 'Student Ten', room: '10');

      final list = [s2, s10];
      list.sort((a, b) => PhonebookController.compareRooms(a, b, ascending: false));

      expect(list[0].room, '10');
      expect(list[1].room, '2');
    });

    test('Rooms with suffixes like 101A and 101B sort in proper alphabetical sub-order', () {
      final s101B = makeStudent(id: '101B', name: 'Student 101B', room: '101B');
      final s101A = makeStudent(id: '101A', name: 'Student 101A', room: '101A');

      final list = [s101B, s101A];
      list.sort((a, b) => PhonebookController.compareRooms(a, b, ascending: true));

      expect(list[0].room, '101A');
      expect(list[1].room, '101B');
    });

    test('Alumni and unassigned rooms appear at the end in both ascending and descending', () {
      final s2 = makeStudent(id: '2', name: 'Student Two', room: '2');
      final sAlumni = makeStudent(id: 'alumni', name: 'Student Alumni', room: 'Alumni');
      final s10 = makeStudent(id: '10', name: 'Student Ten', room: '10');

      final ascList = [sAlumni, s10, s2];
      ascList.sort((a, b) => PhonebookController.compareRooms(a, b, ascending: true));
      expect(ascList.map((s) => s.room).toList(), ['2', '10', 'Alumni']);

      final descList = [s2, sAlumni, s10];
      descList.sort((a, b) => PhonebookController.compareRooms(a, b, ascending: false));
      expect(descList.map((s) => s.room).toList(), ['10', '2', 'Alumni']);
    });
  });

  group('Group & Contact Selection State Logic', () {
    test('areAllVisibleSelected reflects visible student selection accurately', () {
      final controller = PhonebookController();
      final s1 = makeStudent(id: 's1', name: 'Student 1');
      final s2 = makeStudent(id: 's2', name: 'Student 2');
      controller.students.assignAll([s1, s2]);

      expect(controller.areAllVisibleSelected, isFalse);

      controller.selectedStudentIds.add('s1');
      expect(controller.areAllVisibleSelected, isFalse);

      controller.selectedStudentIds.add('s2');
      expect(controller.areAllVisibleSelected, isTrue);
    });

    test('toggleSelectAll toggles visible students without corrupting selection', () {
      final controller = PhonebookController();
      final s1 = makeStudent(id: 's1', name: 'Student 1');
      final s2 = makeStudent(id: 's2', name: 'Student 2');
      controller.students.assignAll([s1, s2]);

      // Select all
      controller.toggleSelectAll();
      expect(controller.isSelectionMode.value, isTrue);
      expect(controller.selectedCount, 2);
      expect(controller.areAllVisibleSelected, isTrue);

      // Deselect all
      controller.toggleSelectAll();
      expect(controller.isSelectionMode.value, isFalse);
      expect(controller.selectedCount, 0);
      expect(controller.areAllVisibleSelected, isFalse);
    });

    test('toggleSelectStudent activates and deactivates selection mode dynamically', () {
      final controller = PhonebookController();
      final s1 = makeStudent(id: 's1', name: 'Student 1');
      controller.students.assignAll([s1]);

      expect(controller.isSelectionMode.value, isFalse);

      controller.toggleSelectStudent('s1');
      expect(controller.isSelectionMode.value, isTrue);
      expect(controller.isStudentSelected('s1'), isTrue);

      controller.toggleSelectStudent('s1');
      expect(controller.isSelectionMode.value, isFalse);
      expect(controller.isStudentSelected('s1'), isFalse);
    });
  });
}
