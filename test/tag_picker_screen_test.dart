import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/tags/student_tag_model.dart';
import 'package:hsh_app2/features/shared/screens/tag_picker_screen.dart';

void main() {
  late RxList<StudentTag> tags;
  late RxSet<int> selected;

  setUp(() {
    tags = <StudentTag>[
      const StudentTag(id: 3, name: 'Floor 2', studentCount: 40),
      const StudentTag(id: 7, name: 'Mess team', studentCount: 1),
    ].obs;
    selected = <int>{}.obs;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => TagPickerScreen.open(
              context,
              tags: tags,
              selectedIds: selected,
              isLoading: false.obs,
              onToggle: (id) => selected.contains(id) ? selected.remove(id) : selected.add(id),
              onRefresh: () async {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('several tags can be picked and Back keeps them', (tester) async {
    await open(tester);
    expect(find.text('40 students'), findsOneWidget);
    expect(find.text('1 student'), findsOneWidget);

    await tester.tap(find.text('Floor 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mess team').last);
    await tester.pumpAndSettle();
    expect(selected, {3, 7});
    expect(find.text('Done · 2 tags'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(TagPickerScreen), findsNothing);
    expect(selected, {3, 7});
  });

  testWidgets('search narrows the tags; Clear empties the selection', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), 'mess');
    await tester.pumpAndSettle();
    expect(find.text('Mess team'), findsOneWidget);
    expect(find.text('Floor 2'), findsNothing);

    await tester.tap(find.text('Mess team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
  });
}
