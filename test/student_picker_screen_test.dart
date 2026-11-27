import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/students/pickable_student.dart';
import 'package:hsh_app2/core/network/repository/students/student_picker_source.dart';
import 'package:hsh_app2/features/shared/utils/student_picker_host.dart';
import 'package:hsh_app2/features/shared/screens/student_picker_screen.dart';
import 'package:hsh_app2/features/shared/widgets/phonebook_style_widgets.dart';

/// The students are set directly, so the source is never asked.
class _Host extends GetxController with StudentPickerHost {
  @override
  StudentPickerSource get studentSource => throw UnimplementedError();

  @override
  bool get includeAlumniInPicker => true;
}

void main() {
  late _Host host;

  setUp(() {
    host = _Host()
      ..students.assignAll(const [
        PickableStudent(id: 1, name: 'asha patel', room: '101'),
        PickableStudent(id: 2, name: 'bhavin shah', room: '102'),
        PickableStudent(id: 3, name: 'chirag dave', room: 'Alumni', isAlumni: true),
      ]);
  });

  Future<void> open(WidgetTester tester) async {
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
  }

  testWidgets('tapping a student selects them; Clear empties the selection', (tester) async {
    await open(tester);
    expect(find.text('0 selected'), findsOneWidget);

    await tester.tap(find.text('Asha Patel'));
    await tester.pumpAndSettle();
    expect(host.selectedStudents.map((s) => s.id), [1]);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Done · 1 student'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(host.selectedStudents, isEmpty);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('the tabs are Residents, Alumni, All and it opens on Residents', (tester) async {
    await open(tester);

    double x(String label) => tester.getCenter(find.text(label).first).dx;
    expect(x('Residents'), lessThan(x('Alumni')));
    expect(x('Alumni'), lessThan(x('All')));
    expect(find.text('Asha Patel'), findsOneWidget);
    expect(find.text('Chirag Dave'), findsNothing);
  });

  testWidgets('swiping moves through the tabs and stops at the ends', (tester) async {
    await open(tester);
    double slider() => tester.getCenter(find.byKey(const ValueKey('tab-slider'))).dx;
    Future<void> swipe(double dx) async {
      await tester.fling(find.byType(CustomScrollView), Offset(dx, 0), 1000);
      await tester.pumpAndSettle();
    }

    final start = slider();
    await swipe(300); // already on the first tab
    expect(slider(), start);

    await swipe(-300);
    expect(find.text('Chirag Dave'), findsOneWidget);
    expect(find.text('Asha Patel'), findsNothing);
    final middle = slider();
    expect(middle, greaterThan(start));

    await swipe(-300);
    await swipe(-300); // already on the last tab
    expect(find.text('Chirag Dave'), findsOneWidget);
    expect(find.text('Asha Patel'), findsOneWidget);
    expect(slider(), greaterThan(middle));

    await swipe(300);
    expect(slider(), middle);
  });

  testWidgets('sliding the picked chips does not change the tab', (tester) async {
    // Tall enough for the cards below the chips to be built.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);
    await tester.tap(find.text('Asha Patel'));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(InputChip), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Bhavin Shah'), findsOneWidget);
    expect(find.text('Chirag Dave'), findsNothing);
  });

  testWidgets('the category tabs and the search narrow the list', (tester) async {
    await open(tester);

    await tester.tap(find.text('Alumni').first);
    await tester.pumpAndSettle();
    expect(find.text('Chirag Dave'), findsOneWidget);
    expect(find.text('Asha Patel'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.enterText(find.byType(TextField), '102');
    await tester.pumpAndSettle();
    expect(find.text('Bhavin Shah'), findsOneWidget);
    expect(find.text('Asha Patel'), findsNothing);
  });

  testWidgets('it is a full screen, and Back keeps the picks', (tester) async {
    await open(tester);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.getSize(find.byType(StudentPickerScreen)), tester.getSize(find.byType(MaterialApp)));

    await tester.tap(find.text('Asha Patel'));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentPickerScreen), findsNothing);
    expect(host.selectedStudents.map((s) => s.id), [1]);
  });

  testWidgets('the app header sits above the search bar and collapses on scroll', (tester) async {
    host.students.addAll([for (var i = 10; i < 40; i++) PickableStudent(id: i, name: 'student $i', room: '$i')]);
    await open(tester);

    final header = tester.widget<SliverPersistentHeader>(find.byType(SliverPersistentHeader));
    expect(header.pinned, isTrue);
    final delegate = header.delegate as PhonebookHeaderDelegate;
    expect(tester.getTopLeft(find.byType(TextField)).dy, greaterThan(delegate.maxExtent));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'the search bar scrolls with the page');
    expect(find.byTooltip('Back'), findsOneWidget, reason: 'the header stays pinned');
  });

  testWidgets('a small phone with the keyboard up does not overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('No students found'), findsOneWidget);
  });
}
