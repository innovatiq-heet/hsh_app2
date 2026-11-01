import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/features/screentime/controllers/student_detail_controller.dart';
import 'package:hsh_app2/features/screentime/widgets/student_overview_body.dart';
import 'package:hsh_app2/features/screentime/widgets/top_apps_card.dart';
import 'package:hsh_app2/features/screentime/widgets/student_usage_body.dart';
import 'package:hsh_app2/features/screentime/views/curfew_limit_screen.dart';
import 'package:hsh_app2/features/screentime/views/restrict_apps_screen.dart';
import 'package:hsh_app2/features/screentime/views/student_apps_screen.dart';
import 'package:hsh_app2/features/screentime/views/student_history_screen.dart';
import 'package:hsh_app2/features/screentime/views/student_usage_screen.dart';
import 'package:hsh_app2/features/screentime/widgets/usage_calendar_card.dart';
import 'package:hsh_app2/features/shared/widgets/skeleton_loader.dart';

/// The student overview is a short set of cards; long content (charts, the
/// full app list, history) lives on the usage screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  StudentDetailController student() => StudentDetailController(<String, dynamic>{
        'id': 903,
        'name': 'Om',
        'room': '306',
      });

  Future<void> pumpBody(WidgetTester tester, Widget body) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: body))),
      );

  testWidgets('follows its controller: skeleton while loading, then the cards', (tester) async {
    final c = student()..isLoading.value = true;
    await pumpBody(tester, StudentOverviewBody(controller: c));
    expect(find.byType(SkeletonLoader), findsWidgets);

    c.isLoading.value = false;
    await tester.pump();

    expect(find.byType(SkeletonLoader), findsNothing);
    expect(find.text('Top apps'), findsOneWidget);
    expect(find.text('Usage & trends'), findsOneWidget);
  });

  testWidgets('the overview leaves charts, the app list and history to the usage screen', (tester) async {
    final c = student();
    await pumpBody(tester, StudentOverviewBody(controller: c));
    await tester.pump();

    expect(find.text('Used today, most first'), findsNothing); // the full per-app list
    expect(find.byType(StudentUsageBody), findsNothing);
  });

  testWidgets('the usage screen opens from the overview and resets to today on close', (tester) async {
    final c = student();
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) {
          hostContext = context;
          return const Scaffold(body: Text('overview'));
        }),
      ),
    );

    StudentUsageScreen.open(hostContext, c);
    await tester.pumpAndSettle();
    expect(find.text('Usage & trends'), findsWidgets);

    // Pick a past day on the usage screen ...
    c.selectedDate.value = '2020-01-01';
    expect(c.isTodaySelected, isFalse);

    // ... and leaving puts the overview back on today.
    Navigator.of(hostContext).pop();
    await tester.pumpAndSettle();
    expect(find.text('overview'), findsOneWidget);
    expect(c.isTodaySelected, isTrue);
  });

  group('the overview opens a separate screen for each section', () {
    Future<void> pumpOverview(WidgetTester tester, StudentDetailController c) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: StudentOverviewBody(controller: c))),
          ),
        );

    testWidgets('Usage & trends, Apps and Requests & history each open their own screen', (tester) async {
      final c = student();
      for (final entry in {
        'Usage & trends': 'Usage & trends',
        'Apps': 'Apps',
        'Requests & history': 'Requests & history',
      }.entries) {
        await pumpOverview(tester, c);
        await tester.pump();
        await tester.ensureVisible(find.text(entry.key).last);
        await tester.tap(find.text(entry.key).last);
        await tester.pumpAndSettle();
        // The new screen's header shows the title, and the student line below it.
        expect(find.text(entry.value), findsWidgets);
        expect(find.text('Om • Room 306'), findsOneWidget, reason: entry.key);
        Navigator.of(tester.element(find.text('Om • Room 306'))).pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the controls open the daily limit and restrict screens', (tester) async {
      final c = student();
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            host = context;
            return const Scaffold(body: SizedBox());
          }),
        ),
      );

      CurfewLimitScreen.open(host, c);
      await tester.pumpAndSettle();
      expect(find.text('Daily limit & bedtime'), findsWidgets);
      expect(find.text('Save rules'), findsOneWidget);
      Navigator.of(host).pop();
      await tester.pumpAndSettle();

      RestrictAppsScreen.open(host, c);
      await tester.pumpAndSettle();
      expect(find.text('Restrict apps'), findsWidgets);
      Navigator.of(host).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('the history screen shows the month calendar with the selected day', (tester) async {
      final c = student()..totalMinutesToday.value = 80;
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            host = context;
            return const Scaffold(body: SizedBox());
          }),
        ),
      );
      StudentHistoryScreen.open(host, c);
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(find.text(DateFormat('MMMM yyyy').format(now)), findsOneWidget);
      // Today is selected by default: its day card and its total in the grid.
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('1h 20m'), findsWidgets);
      expect(find.text('Top apps'), findsOneWidget);
      // Nothing earlier on record, so there is no previous month to go to.
      final back = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left_rounded));
      expect(back.onPressed, isNull);
    });

    testWidgets('tapping a day on the calendar selects it', (tester) async {
      final c = student();
      c.historyRecords.assignAll([
        {'date': UsageCalendarCard.dateKey(DateTime.now().subtract(const Duration(days: 40))), 'total_screen_time_minutes': 50},
      ]);
      final first = DateTime(DateTime.now().year, DateTime.now().month, 1);
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            host = context;
            return const Scaffold(body: SizedBox());
          }),
        ),
      );
      StudentHistoryScreen.open(host, c);
      await tester.pumpAndSettle();

      // An older month has data, so the calendar can go back to it.
      final back = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left_rounded));
      expect(back.onPressed, isNotNull);

      // Pick the 1st of this month (a past or current day).
      if (first.isBefore(DateTime.now()) || first.day == DateTime.now().day) {
        await tester.tap(find.text('1').first);
        await tester.pump();
        expect(c.selectedDate.value, UsageCalendarCard.dateKey(first));
      }
    });

    testWidgets('the apps screen shows the app list card', (tester) async {
      final c = student();
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            host = context;
            return const Scaffold(body: SizedBox());
          }),
        ),
      );
      StudentAppsScreen.open(host, c);
      await tester.pumpAndSettle();
      expect(find.text('Used today, most first'), findsOneWidget);
    });
  });

  testWidgets('the controls offer one way into each settings screen (no duplicate buttons)', (tester) async {
    final c = student();
    await pumpBody(tester, StudentOverviewBody(controller: c));
    await tester.pump();

    expect(find.text('Bedtime & daily limit'), findsOneWidget);
    expect(find.text('Blocked apps'), findsOneWidget);
    expect(find.text('Restrict app'), findsNothing);
    expect(find.text('Curfew & limit'), findsNothing);
  });

  testWidgets('the curfew can be switched off on the daily limit screen', (tester) async {
    final c = student()
      ..bedtimeStart.value = '22:30'
      ..bedtimeEnd.value = '05:30';
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) {
          host = context;
          return const Scaffold(body: SizedBox());
        }),
      ),
    );
    CurfewLimitScreen.open(host, c);
    await tester.pumpAndSettle();

    // Bedtime is on: both times are shown.
    expect(find.text('22:30'), findsOneWidget);
    expect(find.text('05:30'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('22:30'), findsNothing);
    expect(find.text('No bedtime. The phone follows only the daily limit.'), findsOneWidget);
    expect(find.text('Save rules'), findsOneWidget);
  });

  group('UsageCalendarCard', () {
    test('the month grid starts on Monday: blanks, then every day', () {
      // October 2026 starts on a Thursday and has 31 days.
      final cells = UsageCalendarCard.monthCells(DateTime(2026, 10));
      expect(cells.take(3), [null, null, null]);
      expect(cells[3], 1);
      expect(cells.length, 3 + 31);
      expect(cells.last, 31);
      // A month that starts on Monday has no leading blanks.
      expect(UsageCalendarCard.monthCells(DateTime(2026, 6)).first, 1);
    });

    test('minutesOnDate: today, a recorded day, and a day with nothing', () {
      final c = student()..totalMinutesToday.value = 45;
      c.historyRecords.assignAll([
        {'date': '2020-03-05', 'total_screen_time_minutes': 130},
        {'date': '2020-03-06', 'total_screen_time_minutes': 0},
      ]);
      expect(c.minutesOnDate(c.todayDateStr), 45);
      expect(c.minutesOnDate('2020-03-05'), 130);
      expect(c.minutesOnDate('2020-03-06'), isNull);
      expect(c.minutesOnDate('2020-03-07'), isNull);
    });
  });

  group('TopAppsCard.topApps', () {
    test('most used first, at most five, apps without time left out', () {
      final apps = TopAppsCard.topApps([
        for (var i = 1; i <= 7; i++) {'packageName': 'com.app$i', 'appName': 'App $i', 'minutes': i * 10},
        {'packageName': 'com.idle', 'appName': 'Idle app', 'minutes': 0},
      ]);
      expect(apps.map((a) => a.pkg), ['com.app7', 'com.app6', 'com.app5', 'com.app4', 'com.app3']);
      expect(apps.first.minutes, 70);
    });

    test('the same package is counted once', () {
      final apps = TopAppsCard.topApps([
        {'packageName': 'com.x', 'appName': 'X', 'minutes': 10},
        {'packageName': 'com.x', 'appName': 'X', 'minutes': 25},
      ]);
      expect(apps, hasLength(1));
      expect(apps.single.minutes, 35);
    });
  });
}
