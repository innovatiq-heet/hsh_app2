import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/attendance/attendance_responses.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/animated_counter.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/fade_slide_in.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/icon_badge.dart';
import '../shared/widgets/pressable.dart';
import '../shared/widgets/progress_ring.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/skeleton_loader.dart';
import 'attendance_controller.dart';
import 'scan_attendance_sheet.dart';

class AttendanceScreen extends GetView<AttendanceController> {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          skeleton: const HeroSkeleton(),
          builder: (context) => RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                GradientHeader(
                  overline: DateFormat('EEEE, d MMMM').format(DateTime.now()),
                  title: 'Attendance',
                  actions: [
                    HeaderIconButton(
                      icon: Icons.history_rounded,
                      tooltip: 'History',
                      onPressed: () => Get.toNamed(Routes.attendanceHistory),
                    ),
                  ],
                  child: const _ProgressSummary(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapXl,
                    AppDimens.screenPadding,
                    120,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FadeSlideIn(
                        index: 1,
                        child: SectionHeader(title: 'This month'),
                      ),
                      const FadeSlideIn(index: 2, child: _MonthCalendar()),
                      const SizedBox(height: AppDimens.gapXl),
                      const FadeSlideIn(
                        index: 3,
                        child: SectionHeader(title: "Today's sessions"),
                      ),
                      for (int i = 0; i < AttendanceType.values.length; i++)
                        FadeSlideIn(
                          index: 4 + i,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimens.gapMd,
                            ),
                            child: _SessionCard(type: AttendanceType.values[i]),
                          ),
                        ),
                      if (controller.upcomingSabhas.isNotEmpty) ...[
                        const SizedBox(height: AppDimens.gapLg),
                        const SectionHeader(title: 'Upcoming sabhas'),
                        for (final sabha in controller.upcomingSabhas)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimens.gapMd,
                            ),
                            child: _SabhaCard(sabha: sabha),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AttendanceController>();
    return Obx(() {
      final total = AttendanceType.values.length;
      final marked = controller.markedToday;
      final remaining = total - marked;
      final streak = controller.currentStreak;

      return HeaderPanel(
        child: Row(
          children: [
            ProgressRing(
              value: marked / total,
              size: 88,
              strokeWidth: 9,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCounter.integer(
                    value: marked,
                    style: AppTextStyles.numeric(24).copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'of $total',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.gapLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remaining == 0 ? 'All done today' : "Today's progress",
                    style: AppTextStyles.title.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    remaining == 0
                        ? 'Every session is marked.'
                        : '$remaining ${remaining == 1 ? 'session' : 'sessions'} left to mark',
                    style: AppTextStyles.bodySm.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  _StreakPill(days: streak),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _StreakPill extends StatelessWidget {
  final int days;

  const _StreakPill({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), AppColors.warningOrange],
        ),
        boxShadow: AppColors.glow(AppColors.warningOrange, 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          AnimatedCounter.integer(
            value: days,
            suffix: ' day streak',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Current-month calendar: cell intensity reflects sessions marked that
/// day, the running streak glows, today is ringed. Tap a day to see what
/// was marked.
class _MonthCalendar extends StatefulWidget {
  const _MonthCalendar();

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  late final DateTime _today = DateFormatting.utcToIst(DateTime.now().toUtc());
  late int _selectedDay = _today.day;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AttendanceController>();
    return Obx(() {
      final counts = controller.sessionsByDay;
      final streak = controller.currentStreak;
      final streakEnd = (counts[_today.day] ?? 0) > 0 ? _today.day : _today.day - 1;
      final streakDays = {for (int k = 0; k < streak; k++) streakEnd - k};

      final firstWeekday = DateTime(_today.year, _today.month, 1).weekday % 7;
      final daysInMonth = DateTime(_today.year, _today.month + 1, 0).day;
      final activeDays = counts.values.where((c) => c > 0).length;

      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_today),
                    style: AppTextStyles.subtitle,
                  ),
                ),
                Text('$activeDays active days', style: AppTextStyles.bodySm),
              ],
            ),
            const SizedBox(height: AppDimens.gapLg),
            Row(
              children: [
                for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Expanded(
                    child: Center(child: Text(d, style: AppTextStyles.caption)),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.gapSm),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: firstWeekday + daysInMonth,
              itemBuilder: (context, i) {
                if (i < firstWeekday) return const SizedBox.shrink();
                final day = i - firstWeekday + 1;
                return _DayCell(
                  day: day,
                  index: i,
                  sessions: counts[day] ?? 0,
                  isToday: day == _today.day,
                  isFuture: day > _today.day,
                  inStreak: streakDays.contains(day),
                  selected: day == _selectedDay,
                  onTap: day > _today.day
                      ? null
                      : () => setState(() => _selectedDay = day),
                );
              },
            ),
            const SizedBox(height: AppDimens.gapMd),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(sizeFactor: anim, child: child),
              ),
              child: _DayDetail(
                key: ValueKey(_selectedDay),
                day: _selectedDay,
                month: _today,
                types: _typesOn(controller, _selectedDay),
              ),
            ),
          ],
        ),
      );
    });
  }

  List<AttendanceType> _typesOn(AttendanceController c, int day) {
    if (day == _today.day) {
      return [
        for (final e in c.todayStatus.entries)
          if (e.value != null) e.key,
      ];
    }
    return [
      for (final entry in c.monthLog)
        if (DateFormatting.utcToIst(entry.markedAt).day == day) entry.type,
    ];
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int index;
  final int sessions;
  final bool isToday;
  final bool isFuture;
  final bool inStreak;
  final bool selected;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.index,
    required this.sessions,
    required this.isToday,
    required this.isFuture,
    required this.inStreak,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final intensity = (sessions / AttendanceType.values.length).clamp(0.0, 1.0);
    final Color textColor;
    BoxDecoration decoration;

    if (inStreak) {
      textColor = Colors.white;
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.indigo, AppColors.primaryLight],
        ),
        boxShadow: AppColors.glow(AppColors.indigo, 0.35),
      );
    } else if (sessions > 0) {
      textColor = AppColors.primary;
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.primaryLight.withValues(alpha: 0.12 + 0.3 * intensity),
      );
    } else {
      textColor = isFuture ? AppColors.border : AppColors.textMuted;
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isFuture ? Colors.transparent : AppColors.surfaceMuted,
      );
    }
    if (isToday || selected) {
      decoration = decoration.copyWith(
        border: Border.all(
          color: isToday ? AppColors.warningOrange : AppColors.primary,
          width: 2,
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 14),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(
        scale: v,
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: Pressable(
        enabled: onTap != null,
        pressedScale: 0.88,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: decoration,
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: AppTextStyles.label.copyWith(
                color: textColor,
                fontWeight: sessions > 0 || isToday
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  final int day;
  final DateTime month;
  final List<AttendanceType> types;

  const _DayDetail({
    super.key,
    required this.day,
    required this.month,
    required this.types,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime(month.year, month.month, day);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.gapMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('EEE, d MMM').format(date)} · ${types.length} of ${AttendanceType.values.length} sessions',
            style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppDimens.gapSm),
          if (types.isEmpty)
            Text('Nothing marked this day.', style: AppTextStyles.bodySm)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in types)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(t.label, style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 11.5,
                        )),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final AttendanceType type;

  const _SessionCard({required this.type});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AttendanceController>();
    return Obx(() {
      final markedAt = controller.todayStatus[type];
      final isMarking = controller.markingType.value == type;
      final isMarked = markedAt != null;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isMarked
              ? AppColors.successGreen.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(
            color: isMarked
                ? AppColors.successGreen.withValues(alpha: 0.35)
                : AppColors.border.withValues(alpha: 0.6),
          ),
          boxShadow: isMarked ? null : AppColors.softShadow,
        ),
        padding: const EdgeInsets.all(AppDimens.gapLg),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: IconBadge(
                key: ValueKey(isMarked),
                icon: isMarked ? Icons.check_rounded : type.icon,
                color: isMarked ? AppColors.successGreen : AppColors.primary,
                solid: isMarked,
              ),
            ),
            const SizedBox(width: AppDimens.gapLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label, style: AppTextStyles.subtitle),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      isMarked
                          ? 'Marked at ${DateFormatting.time(markedAt)}'
                          : 'Not marked yet',
                      key: ValueKey(isMarked),
                      style: AppTextStyles.bodySm.copyWith(
                        color: isMarked
                            ? AppColors.successGreen
                            : AppColors.textMuted,
                        fontWeight: isMarked ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: isMarking
                  ? const SizedBox(
                      key: ValueKey('marking'),
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : isMarked
                  ? const SizedBox.shrink(key: ValueKey('done'))
                  : Row(
                      key: const ValueKey('actions'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Pressable(
                          pressedScale: 0.9,
                          child: IconButton.filledTonal(
                            tooltip: 'Scan to mark',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surfaceMuted,
                              foregroundColor: AppColors.secondary,
                            ),
                            icon: const Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 20,
                            ),
                            onPressed: () =>
                                showScanAttendanceSheet(context, type),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Pressable(
                          pressedScale: 0.92,
                          child: FilledButton(
                            onPressed: () =>
                                controller.mark(type, viaCode: false),
                            child: const Text('Mark'),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    });
  }
}

class _SabhaCard extends StatelessWidget {
  final SabhaResponse sabha;

  const _SabhaCard({required this.sabha});

  @override
  Widget build(BuildContext context) {
    final ist = DateFormatting.utcToIst(sabha.date);
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.gapMd),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.indigo, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              boxShadow: AppColors.glow(AppColors.indigo, 0.3),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('d').format(ist),
                  style: AppTextStyles.numeric(20).copyWith(color: Colors.white),
                ),
                Text(
                  DateFormat('MMM').format(ist).toUpperCase(),
                  style: AppTextStyles.overline.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.gapLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sabha.title, style: AppTextStyles.subtitle),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormatting.time(sabha.startTime)} – ${DateFormatting.time(sabha.endTime)}',
                      style: AppTextStyles.bodySm,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
