import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/features/phonebook/controllers/phonebook_controller.dart';
import 'package:hsh_app2/features/phonebook/models/phonebook_models.dart';
import 'package:hsh_app2/features/phonebook/widgets/alpha_scroll_rail.dart';

PhonebookStudent _s(String name, {String? room = '101'}) => PhonebookStudent(
      id: name,
      studentId: 'HSH-$name',
      name: name,
      enrollmentNumber: '',
      department: '',
      batch: 'ACTIVE',
      room: room,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rail entries', () {
    test('student letters first (A-Z, # last), then alumni letters', () {
      final c = PhonebookController();
      c.rebuildAlphaIndex([
        _s('Amy'),
        _s('Zed'),
        _s('1Bot'),
        _s('Bob', room: 'alumni'),
        _s('Abe', room: 'alumni'),
      ]);
      expect(
        c.railEntries.map((e) => '${e.alumni ? 'alumni:' : ''}${e.letter}').toList(),
        ['A', 'Z', '#', 'alumni:A', 'alumni:B'],
      );
    });
  });

  group('AlphaScrollRail', () {
    const entries = [
      RailEntry('A'),
      RailEntry('B'),
      RailEntry('C'),
      RailEntry('A', alumni: true),
      RailEntry('B', alumni: true),
      RailEntry('C', alumni: true),
    ];

    final studentsTab = find.byKey(const ValueKey('rail-students'));
    final alumniTab = find.byKey(const ValueKey('rail-alumni'));

    Future<List<RailEntry>> pump(WidgetTester tester) async {
      final picked = <RailEntry>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 500,
              // Align loosens the height like the screen's Positioned does.
              child: Align(
                alignment: Alignment.topRight,
                child: AlphaScrollRail(entries: entries, onSelected: picked.add),
              ),
            ),
          ),
        ),
      );
      return picked;
    }

    Future<void> open(WidgetTester tester, Finder section) async {
      await tester.tap(section);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }

    Future<void> scrubOn(WidgetTester tester, Finder section, List<double> ys) async {
      final topRight = tester.getTopRight(section);
      final x = topRight.dx - 14;
      final g = await tester.startGesture(Offset(x, topRight.dy + ys.first));
      for (final y in ys.skip(1)) {
        await g.moveTo(Offset(x, topRight.dy + y));
      }
      await g.up();
    }

    Future<void> letCollapseRun(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    }

    // Open student strip: 3 letters at 19 px, centred in a 69 px strip (6 px top).
    double row(int i) => 6 + 19 * i + 9.5;

    testWidgets('both sections rest as their own tab', (tester) async {
      await pump(tester);
      expect(studentsTab, findsOneWidget);
      expect(alumniTab, findsOneWidget);
      expect(tester.getSize(studentsTab).height, lessThan(80));
      expect(tester.getSize(alumniTab).height, lessThan(80));
    });

    testWidgets('opening one section leaves the other a tab and picks nothing', (tester) async {
      final picked = await pump(tester);
      final tab = tester.getSize(studentsTab).height;
      await open(tester, studentsTab);
      expect(tester.getSize(studentsTab).height, greaterThan(tab));
      expect(tester.getSize(alumniTab).height, tab);
      expect(picked, isEmpty);
      await letCollapseRun(tester);
    });

    testWidgets('opening alumni folds students back', (tester) async {
      await pump(tester);
      final tab = tester.getSize(studentsTab).height;
      await open(tester, studentsTab);
      await open(tester, alumniTab);
      expect(tester.getSize(studentsTab).height, tab);
      expect(tester.getSize(alumniTab).height, greaterThan(tab));
      await letCollapseRun(tester);
    });

    testWidgets('sliding on the student strip reports student letters once each', (tester) async {
      final picked = await pump(tester);
      await open(tester, studentsTab);
      await scrubOn(tester, studentsTab, [row(0), row(0) + 2, row(1), row(2)]);
      await letCollapseRun(tester);
      expect(picked, [const RailEntry('A'), const RailEntry('B'), const RailEntry('C')]);
    });

    testWidgets('the alumni strip reports alumni letters', (tester) async {
      final picked = await pump(tester);
      await open(tester, alumniTab);
      await scrubOn(tester, alumniTab, [row(0), row(1)]);
      await letCollapseRun(tester);
      expect(picked, [
        const RailEntry('A', alumni: true),
        const RailEntry('B', alumni: true),
      ]);
    });

    testWidgets('an open section folds back into its tab by itself', (tester) async {
      await pump(tester);
      final tab = tester.getSize(studentsTab).height;
      await open(tester, studentsTab);
      await letCollapseRun(tester);
      expect(tester.getSize(studentsTab).height, tab);
    });
  });
}
