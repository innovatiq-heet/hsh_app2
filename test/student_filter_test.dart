import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/students/pickable_student.dart';
import 'package:hsh_app2/core/network/repository/students/student_picker_source.dart';
import 'package:hsh_app2/features/shared/screens/student_picker_screen.dart';
import 'package:hsh_app2/features/shared/utils/student_picker_host.dart';

class _Host extends GetxController with StudentPickerHost {
  @override
  StudentPickerSource get studentSource => throw UnimplementedError();

  @override
  bool get includeAlumniInPicker => true;
}

/// Rows shaped like `GET /students?all=true`.
final _rows = [
  {
    'id': 1,
    'name': 'Asha Patel',
    'room_number': '101',
    'group_name': 'Param',
    'tags': [
      {'id': 3, 'name': 'Late', 'color': '#EF4444'},
    ],
  },
  {'id': 2, 'name': 'Bhavin Shah', 'room_number': '205', 'group_name': 'Pulkit', 'tags': []},
  {'id': 3, 'name': 'Chirag Dave', 'room_number': '12', 'group_name': 'N/A'},
  {'id': 4, 'name': 'Dev Old', 'room_number': '', 'floor_id': 0, 'group_name': ' param '},
];

void main() {
  test('floor, group and tags come from the row', () {
    final list = pickableStudentsFromRows(_rows, includeAlumni: true);

    expect(list.map((s) => s.floor), [1, 2, 0, null], reason: 'from the room; alumni are on no floor');
    expect(list.map((s) => s.group), ['Param', 'Pulkit', '', 'Param'], reason: 'one spelling per group');
    expect(list.first.tags.map((t) => t.id), [3]);
  });

  testWidgets('filters narrow the list and the counts, and keep the picks', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = _Host()..students.assignAll(pickableStudentsFromRows(_rows, includeAlumni: true));
    host.selectedStudents.add(host.students[1]); // Bhavin

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => StudentPickerScreen.open(context, host),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Param'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('group-Param')));
    await tester.pumpAndSettle();
    expect(find.text('Apply Filters & Show (1 Student)'), findsOneWidget, reason: 'residents tab: Asha only');
    await tester.tap(find.text('Apply Filters & Show (1 Student)'));
    await tester.pumpAndSettle();

    expect(find.text('Asha Patel'), findsOneWidget);
    expect(find.text('Chirag Dave'), findsNothing);
    expect(host.selectedStudents.map((s) => s.id), [2], reason: 'filtering does not unpick');

    // Add a floor that no Param resident is on, then clear from the empty state.
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('floor-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply Filters & Show (0 Students)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Chirag Dave'), findsOneWidget);
  });
}
