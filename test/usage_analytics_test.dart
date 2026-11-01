import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/features/screentime/controllers/student_detail_controller.dart';
import 'package:hsh_app2/features/screentime/controllers/usage_analytics.dart';
import 'package:hsh_app2/features/screentime/widgets/student_usage_body.dart';
import 'package:hsh_app2/features/screentime/widgets/usage/usage_category_card.dart';
import 'package:hsh_app2/features/screentime/widgets/usage/usage_trend_chart.dart';

UsageDay day(String date, int minutes, {int night = 0}) => UsageDay(
      day: DateTime.parse(date),
      date: date,
      minutes: minutes,
      night: night,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 2024-01-01 is a Monday.
  final week = [
    day('2024-01-01', 120, night: 20), // Mon
    day('2024-01-02', 60), // Tue
    day('2024-01-03', 0), // Wed: nothing recorded
    day('2024-01-04', 240, night: 40), // Thu
    day('2024-01-05', 90), // Fri
    day('2024-01-06', 300), // Sat
    day('2024-01-07', 150), // Sun
  ];

  group('UsageAnalytics', () {
    test('averages count only the days that have data', () {
      final a = UsageAnalytics(week);
      expect(a.activeDays, 6);
      expect(a.totalMinutes, 960);
      expect(a.averageMinutes, 160); // not 960 / 7
      expect(a.maxMinutes, 300);
      expect(a.heaviest!.date, '2024-01-06');
    });

    test('night and day split, and the days with night use', () {
      final a = UsageAnalytics(week);
      expect(a.nightMinutes, 60);
      expect(a.nightDays, 2);
      expect(a.daytimeMinutes, 900);
    });

    test('days over the limit; none without a limit', () {
      expect(UsageAnalytics(week, limit: 100).overLimitDays, 4);
      expect(UsageAnalytics(week).overLimitDays, 0);
    });

    test('weekday averages start on Monday, null where no day was recorded', () {
      final a = UsageAnalytics([...week, day('2024-01-08', 180)]); // a second Monday
      final avg = a.weekdayAverages;
      expect(avg[0], 150); // Mon: (120 + 180) / 2
      expect(avg[2], isNull); // Wed had no data
      expect(avg[5], 300); // Sat
    });

    test('percent against the average', () {
      final a = UsageAnalytics(week); // average 160
      expect(a.percentVsAverage(240), 50);
      expect(a.percentVsAverage(80), -50);
      expect(a.percentVsAverage(160), 0);
      expect(UsageAnalytics([day('2024-01-01', 0)]).percentVsAverage(60), isNull);
    });
  });

  group('insights', () {
    test('say when there is not enough data', () {
      final out = buildUsageInsights(UsageAnalytics([day('2024-01-01', 0)]));
      expect(out, hasLength(1));
      expect(out.single.text, contains('Not enough data'));
    });

    test('heaviest day, weekday pattern, limit and night behaviour', () {
      final out = buildUsageInsights(
        UsageAnalytics(week, limit: 100),
        categories: {'Social Media': 90, 'Gaming': 30},
      ).map((i) => i.text).toList();

      expect(out.any((t) => t.startsWith('Heaviest day: Sat, 6 Jan with 5h')), isTrue);
      expect(out.any((t) => t.contains('Most screen time on Saturdays')), isTrue);
      expect(out.any((t) => t.contains('over the 1h 40m limit on 4 of 6 days')), isTrue);
      expect(out.any((t) => t.contains('at night on 2 days')), isTrue);
      expect(out.any((t) => t.startsWith('Social Media takes 75%')), isTrue);
    });

    test('good behaviour is reported too', () {
      final calm = UsageAnalytics([day('2024-01-01', 30), day('2024-01-02', 40)], limit: 120);
      final out = buildUsageInsights(calm).map((i) => i.text).toList();
      expect(out.any((t) => t.contains('Stayed within the 2h limit every day')), isTrue);
      expect(out.any((t) => t.contains('No night-time use')), isTrue);
    });
  });

  group('chart helpers', () {
    test('y axis leaves room above the tallest bar and the limit', () {
      expect(UsageTrendChart.axisMaxHours(UsageAnalytics([day('2024-01-01', 20)])), 2);
      expect(UsageTrendChart.axisMaxHours(UsageAnalytics([day('2024-01-01', 130)])), 3);
      expect(UsageTrendChart.axisMaxHours(UsageAnalytics([day('2024-01-01', 30)], limit: 300)), 5);
    });

    test('categories are ranked biggest first and empty ones dropped', () {
      final ranked = UsageCategoryCard.ranked({'Gaming': 10, 'Social Media': 50, 'Other': 0});
      expect(ranked.map((e) => e.key), ['Social Media', 'Gaming']);
    });
  });

  group('StudentUsageBody', () {
    StudentDetailController student() {
      final c = StudentDetailController(<String, dynamic>{'id': 903, 'name': 'Om', 'room': '306'});
      final now = DateTime.now();
      String key(int back) {
        final d = now.subtract(Duration(days: back));
        final mm = d.month.toString().padLeft(2, '0');
        final dd = d.day.toString().padLeft(2, '0');
        return '${d.year.toString().padLeft(4, '0')}-$mm-$dd';
      }

      c.totalMinutesToday.value = 95;
      c.nightMinutesToday.value = 15;
      c.dailyLimitMinutes.value = 120;
      c.historyRecords.assignAll([
        {'date': key(1), 'total_screen_time_minutes': 140, 'night_screen_time_minutes': 20},
        {'date': key(2), 'total_screen_time_minutes': 60},
        {'date': key(3), 'total_screen_time_minutes': 200},
      ]);
      return c;
    }

    Future<void> pumpBody(WidgetTester tester, StudentDetailController c) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: StudentUsageBody(controller: c)),
            ),
          ),
        );

    testWidgets('shows the analysis sections for the last week by default', (tester) async {
      await pumpBody(tester, student());
      await tester.pumpAndSettle();

      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Daily screen time'), findsOneWidget);
      expect(find.text('What stands out'), findsOneWidget);
      expect(find.text('What the time went on'), findsOneWidget);
      expect(find.text('Weekly rhythm'), findsOneWidget);
      expect(find.text('Top apps'), findsOneWidget);
    });

    testWidgets('switching the range keeps every section', (tester) async {
      await pumpBody(tester, student());
      await tester.pumpAndSettle();

      for (final label in ['14 days', '30 days', '7 days']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text('Daily screen time'), findsOneWidget, reason: label);
        expect(find.text('Weekly rhythm'), findsOneWidget, reason: label);
      }
    });

    testWidgets('fits a 360 px wide phone without overflowing, in every range', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final c = student()..selectedDate.value = '';
      await pumpBody(tester, c);
      await tester.pumpAndSettle();
      for (final label in ['14 days', '30 days']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      // A failed layout would have thrown a RenderFlex overflow by now.
      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the selected day', (tester) async {
      final c = student();
      await pumpBody(tester, c);
      await tester.pumpAndSettle();
      expect(find.text('Back to today'), findsNothing);

      c.selectedDate.value = c.usagePoints(7)[5]['date'] as String; // yesterday
      await tester.pumpAndSettle();
      expect(find.text('Back to today'), findsOneWidget);
    });
  });
}
