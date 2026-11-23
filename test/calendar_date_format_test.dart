import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/utils/date_formatting.dart';

/// Student, father and mother birth dates and the parents' anniversary are
/// shown the same way: "19 Mar 1971 (54 yrs)".
void main() {
  final today = DateTime(2026, 11, 24);

  test('the same format, with whole years, for every kind of directory date', () {
    expect(DateFormatting.calendarDateWithYears('2005-03-12', now: today), '12 Mar 2005 (21 yrs)');
    expect(DateFormatting.calendarDateWithYears('1971-03-19', now: today), '19 Mar 1971 (55 yrs)');
    expect(DateFormatting.calendarDateWithYears('19-03-1971', now: today), '19 Mar 1971 (55 yrs)');
    // Epoch milliseconds (anniversaries): 22 Nov 1998 00:00 IST.
    expect(DateFormatting.calendarDateWithYears('911673000000', now: today), '22 Nov 1998 (28 yrs)');
    // A date before 1970 stored as epoch milliseconds.
    expect(DateFormatting.calendarDate('-31555800000'), '1 Jan 1969');
  });

  test('the years only count once the day has come', () {
    expect(DateFormatting.calendarDateWithYears('1972-11-24', now: today), '24 Nov 1972 (54 yrs)');
    expect(DateFormatting.calendarDateWithYears('1972-11-25', now: today), '25 Nov 1972 (53 yrs)');
  });

  test('no years when they make no sense; unreadable text as is', () {
    expect(DateFormatting.calendarDateWithYears('2026-11-01', now: today), '1 Nov 2026');
    expect(DateFormatting.calendarDateWithYears('not a date', now: today), 'not a date');
    expect(DateFormatting.calendarDateWithYears('', now: today), '');
    expect(DateFormatting.calendarDateWithYears(null, now: today), '');
  });
}
