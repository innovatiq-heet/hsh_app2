import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/models/students/pickable_student.dart';
import 'package:hsh_app2/core/utils/string_formatting.dart';
import 'package:hsh_app2/features/shared/widgets/selected_students_list.dart';

void main() {
  final removed = <int>[];
  var cleared = 0;

  setUp(() {
    removed.clear();
    cleared = 0;
  });

  Future<void> show(WidgetTester tester, int count) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SelectedStudentsList(
              students: [for (var i = 1; i <= count; i++) PickableStudent(id: i, name: 'student $i', room: '10$i')],
              onRemove: (s) => removed.add(s.id),
              onClear: () => cleared++,
            ),
          ),
        ),
      ));

  testWidgets('it starts closed with the names on one line, and opens and closes', (tester) async {
    await show(tester, 2);
    expect(find.text('2 students selected'), findsOneWidget);
    expect(find.text('Student 1, Student 2'), findsOneWidget);
    expect(find.text('Student 1'), findsNothing);

    await tester.tap(find.text('2 students selected'));
    await tester.pumpAndSettle();
    expect(find.text('Student 1'), findsOneWidget);
    expect(find.text('Collapse'), findsNothing, reason: 'a short list only needs the header');

    await tester.tap(find.text('2 students selected'));
    await tester.pumpAndSettle();
    expect(find.text('Student 1'), findsNothing);
  });

  testWidgets('a long open list shows every row and can be collapsed from the bottom', (tester) async {
    await show(tester, 6);
    await tester.tap(find.text('6 students selected'));
    await tester.pumpAndSettle();
    expect(find.text('Student 6'), findsOneWidget);

    await tester.ensureVisible(find.text('Collapse'));
    await tester.tap(find.text('Collapse'));
    await tester.pumpAndSettle();
    expect(find.text('Student 6'), findsNothing);
  });

  testWidgets('the row button removes that student; Clear all clears without opening', (tester) async {
    await show(tester, 2);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(cleared, 1);
    expect(find.text('Student 2'), findsNothing);

    await tester.tap(find.text('2 students selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Student 2'));
    expect(removed, [2]);
  });

  test('initials come from the first and last word', () {
    expect(nameInitials('Aadi Niraj Pandya'), 'AP');
    expect(nameInitials('asha'), 'A');
    expect(nameInitials('  '), '#');
  });
}
