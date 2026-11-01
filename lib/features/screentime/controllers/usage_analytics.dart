import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import 'screen_time_utils.dart';

/// One calendar day of a student's screen time.
class UsageDay {
  final DateTime day;

  /// `yyyy-MM-dd`.
  final String date;
  final int minutes;

  /// The part of [minutes] that fell at night.
  final int night;

  const UsageDay({
    required this.day,
    required this.date,
    required this.minutes,
    required this.night,
  });

  bool get hasData => minutes > 0;

  /// Screen time outside the night window.
  int get daytime => (minutes - night).clamp(0, minutes);

  /// From a point of `StudentDetailController.usagePoints`.
  factory UsageDay.fromPoint(Map<String, dynamic> p) {
    final date = (p['date'] ?? '').toString();
    return UsageDay(
      day: DateTime.tryParse(date) ?? DateTime.now(),
      date: date,
      minutes: toInt(p['totalMinutes']),
      night: toInt(p['nightMinutes']),
    );
  }
}

/// Numbers behind the usage screen's charts, worked out from a run of days.
/// Plain data in, plain data out, so it is easy to test.
class UsageAnalytics {
  /// Oldest first.
  final List<UsageDay> days;

  /// Daily allowance in minutes; 0 means no limit.
  final int limit;

  const UsageAnalytics(this.days, {this.limit = 0});

  factory UsageAnalytics.fromPoints(List<Map<String, dynamic>> points, {int limit = 0}) =>
      UsageAnalytics(points.map(UsageDay.fromPoint).toList(), limit: limit);

  Iterable<UsageDay> get _active => days.where((d) => d.hasData);

  /// Days that have any recorded usage.
  int get activeDays => _active.length;

  int get totalMinutes => _active.fold(0, (sum, d) => sum + d.minutes);

  /// Average over the days that have data (a day with nothing recorded is a
  /// gap in the data, not a zero).
  int get averageMinutes => activeDays == 0 ? 0 : totalMinutes ~/ activeDays;

  int get nightMinutes => days.fold(0, (sum, d) => sum + d.night);

  int get daytimeMinutes => _active.fold(0, (sum, d) => sum + d.daytime);

  int get nightDays => days.where((d) => d.night > 0).length;

  int get overLimitDays => limit > 0 ? days.where((d) => d.minutes > limit).length : 0;

  int get maxMinutes => days.fold(0, (m, d) => d.minutes > m ? d.minutes : m);

  UsageDay? get heaviest {
    UsageDay? best;
    for (final d in _active) {
      if (best == null || d.minutes > best.minutes) best = d;
    }
    return best;
  }

  /// Average minutes for each weekday, Monday first; null where the range has
  /// no recorded day for that weekday.
  List<int?> get weekdayAverages {
    final sums = List<int>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    for (final d in _active) {
      final i = d.day.weekday - DateTime.monday;
      sums[i] += d.minutes;
      counts[i]++;
    }
    return [for (var i = 0; i < 7; i++) counts[i] == 0 ? null : sums[i] ~/ counts[i]];
  }

  /// How far [minutes] is from the average, in percent (positive = above);
  /// null when there is no average yet.
  int? percentVsAverage(int minutes) {
    final avg = averageMinutes;
    if (avg == 0) return null;
    return ((minutes - avg) * 100 / avg).round();
  }
}

/// A one-line finding shown in the insights card.
class UsageInsight {
  final IconData icon;
  final Color color;
  final String text;
  const UsageInsight(this.icon, this.color, this.text);
}

/// Plain-language findings from [a] and the selected day's [categories]
/// (minutes per app category).
List<UsageInsight> buildUsageInsights(UsageAnalytics a, {Map<String, int> categories = const {}}) {
  if (a.activeDays == 0) {
    return const [
      UsageInsight(
        Icons.hourglass_empty_rounded,
        AppColors.textMuted,
        'Not enough data yet. Insights appear once the phone has reported a few days.',
      ),
    ];
  }

  final out = <UsageInsight>[];

  final heaviest = a.heaviest!;
  out.add(UsageInsight(
    Icons.local_fire_department_rounded,
    AppColors.secondaryDark,
    'Heaviest day: ${DateFormat('EEE, d MMM').format(heaviest.day)} with ${formatMinutes(heaviest.minutes)}.',
  ));

  final weekdays = a.weekdayAverages;
  final known = [for (var i = 0; i < 7; i++) if (weekdays[i] != null) i];
  if (known.length >= 3) {
    var top = known.first;
    for (final i in known) {
      if (weekdays[i]! > weekdays[top]!) top = i;
    }
    final name = DateFormat('EEEE').format(DateTime(2024, 1, 1 + top)); // 2024-01-01 is a Monday
    out.add(UsageInsight(
      Icons.calendar_view_week_rounded,
      AppColors.primary,
      'Most screen time on ${name}s, around ${formatMinutes(weekdays[top]!)} a day.',
    ));
  }

  if (a.limit > 0) {
    out.add(a.overLimitDays > 0
        ? UsageInsight(
            Icons.hourglass_disabled_rounded,
            AppColors.cancelledRed,
            'Went over the ${formatMinutes(a.limit)} limit on ${a.overLimitDays} of ${a.activeDays} days.',
          )
        : UsageInsight(
            Icons.verified_rounded,
            AppColors.successGreen,
            'Stayed within the ${formatMinutes(a.limit)} limit every day.',
          ));
  }

  out.add(a.nightDays > 0
      ? UsageInsight(
          Icons.nightlight_round,
          AppColors.secondaryDark,
          'Used the phone at night on ${a.nightDays} ${a.nightDays == 1 ? 'day' : 'days'} (${formatMinutes(a.nightMinutes)} in total).',
        )
      : const UsageInsight(
          Icons.bedtime_rounded,
          AppColors.successGreen,
          'No night-time use in this period.',
        ));

  final catTotal = categories.values.fold<int>(0, (s, v) => s + v);
  if (catTotal > 0) {
    final top = categories.entries.reduce((x, y) => y.value > x.value ? y : x);
    out.add(UsageInsight(
      Icons.pie_chart_rounded,
      AppColors.primary,
      '${top.key} takes ${(top.value * 100 / catTotal).round()}% of the selected day.',
    ));
  }

  return out;
}
