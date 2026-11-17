import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/features/screentime/controllers/student_detail_controller.dart';
import 'package:hsh_app2/features/screentime/views/student_history_screen.dart';
import 'package:hsh_app2/features/screentime/views/student_usage_screen.dart';

import 'support/test_fonts.dart';

/// Leaving "Usage & trends" or "Requests & history" after picking a past day
/// goes back to today. Doing that inside dispose() made every Obx watching
/// the selected day throw "setState() or markNeedsBuild() called when widget
/// tree was locked".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadDeviceLikeFonts);

  String dayBack(int days) {
    final d = DateTime.now().subtract(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  StudentDetailController student() {
    final c = StudentDetailController(<String, dynamic>{'id': 903, 'name': 'Om', 'room': '306'});
    c.totalMinutesToday.value = 95;
    c.historyRecords.assignAll([
      {'date': dayBack(1), 'total_screen_time_minutes': 140},
      {'date': dayBack(2), 'total_screen_time_minutes': 60},
    ]);
    return c;
  }

  /// The overview stand-in: watches the selected day like its cards do.
  Future<void> pumpHome(WidgetTester tester, StudentDetailController c, Widget Function() page) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Get.testMode = true;
    await tester.pumpWidget(GetMaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              Obx(() => Text('Showing ${c.isTodaySelected ? 'today' : c.selectedDate.value}')),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page())),
                child: const Text('Open'),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  for (final (name, page) in <(String, Widget Function(StudentDetailController))>[
    ('Usage & trends', (c) => StudentUsageScreen(controller: c)),
    ('Requests & history', (c) => StudentHistoryScreen(controller: c)),
  ]) {
    testWidgets('$name: back after picking a past day returns to today without an error', (tester) async {
      final c = student();
      await pumpHome(tester, c, () => page(c));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      c.selectDate(dayBack(1));
      await tester.pumpAndSettle();
      expect(c.isTodaySelected, isFalse);

      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(c.isTodaySelected, isTrue);
      expect(find.text('Showing today'), findsOneWidget);
    });
  }
}
