import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/enums/attendance_type.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/responses/attendance/attendance_models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/namedrop_attendance_overlay.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/attendance_controller.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  final AttendanceController controller = Get.find<AttendanceController>();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'HV';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  IconData _resolveScheduleIcon(String? iconName, AttendanceType type) {
    final lower = iconName?.toLowerCase() ?? '';
    if (type == AttendanceType.night || lower.contains('moon')) {
      return Icons.dark_mode_rounded;
    }
    if (lower.contains('bell')) {
      return Icons.notifications_rounded;
    }
    if (lower.contains('sun') || lower.contains('morning')) {
      return Icons.wb_sunny_rounded;
    }
    return Icons.groups_rounded;
  }

  bool _isTimingActiveNow(String startTime, String endTime) {
    try {
      if (startTime == '00:00' && endTime == '00:00') {
        return false;
      }
      final now = DateTime.now();
      final curMins = now.hour * 60 + now.minute;
      final startParts = startTime
          .split(':')
          .map((e) => int.parse(e.trim()))
          .toList();
      final endParts = endTime
          .split(':')
          .map((e) => int.parse(e.trim()))
          .toList();
      if (startParts.length < 2 || endParts.length < 2) return false;

      final startMins = startParts[0] * 60 + startParts[1];
      int endMins = endParts[0] * 60 + endParts[1];

      // If session ends at midnight (00:00), treat as 24:00 (1440 mins)
      if (endMins == 0 && startMins > 0) {
        endMins = 1440;
      }

      if (startMins == endMins) {
        return false;
      }

      if (startMins < endMins) {
        return curMins >= startMins && curMins <= endMins;
      } else {
        // Overnight window crossing past midnight (e.g. 23:00 to 02:00)
        return curMins >= startMins || curMins <= endMins;
      }
    } catch (_) {
      return false;
    }
  }

  void _showResultDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    String buttonLabel = 'Got it',
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                    border: Border.all(
                      color: AppColors.borderLight,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow.withValues(alpha: 0.16),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 26),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapLg),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headline.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapSm),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMd.copyWith(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapXl),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: buttonLabel,
                          onPressed: () => Navigator.of(ctx).pop(),
                          variant: AppButtonVariant.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBluetoothRequiredDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppColors.warningOrange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bluetooth_disabled_rounded,
                      color: AppColors.warningOrange,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bluetooth Required',
                    style: AppTextStyles.headline.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bluetooth is required to detect the ESP-32 beacon on your floor and verify your presence in the hostel/classroom.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            try {
                              await FlutterBluePlus.turnOn();
                            } catch (_) {}
                          },
                          child: const Text('Turn On'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLocationRequiredDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Location Services Required',
                    style: AppTextStyles.headline.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Android requires location permissions to discover nearby Bluetooth Low Energy (BLE) beacons. Your GPS coordinates are never recorded or stored.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            openAppSettings();
                          },
                          child: const Text('Open Settings'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _performBleScan(
    AttendanceType type, {
    required bool isAttendanceOpen,
  }) async {
    if (controller.alreadyMarked.value) {
      _showResultDialog(
        title: 'Already Marked',
        message: 'Your attendance is already marked for today.',
        icon: Icons.info_outline_rounded,
        color: AppColors.primary,
        buttonLabel: 'Understood',
      );
      return;
    }

    if (!isAttendanceOpen) {
      _showResultDialog(
        title: 'Attendance Closed',
        message:
            'Attendance is currently closed. Please check the schedule for the next available session.',
        icon: Icons.schedule_rounded,
        color: AppColors.warningOrange,
        buttonLabel: 'Got it',
      );
      return;
    }

    try {
      final record = await controller.markWithBle(type);
      if (record != null) {
        if (mounted) {
          NamedropAttendanceOverlay.show(
            context,
            title: 'Attendance Marked!',
            sessionName: type.label,
            eventType: type,
            subtitle:
                'Your attendance for ${type.label} has been recorded successfully.',
          );
        }
      }
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('bluetooth') ||
          err.contains('adapter') ||
          err.contains('turn on')) {
        _showBluetoothRequiredDialog();
      } else if (err.contains('permission') || err.contains('location')) {
        _showLocationRequiredDialog();
      } else {
        _showResultDialog(
          title: 'Could Not Mark Attendance',
          message: controller.friendlyError(e),
          icon: Icons.error_outline_rounded,
          color: AppColors.cancelledRed,
          buttonLabel: 'Dismiss',
        );
      }
    }
  }

  Widget _buildHeader() {
    return Obx(() {
      final sName = controller.studentName.value;
      final sRoom = controller.studentRoom.value;
      final sGroup = controller.studentGroup.value;
      final sCode = controller.studentCode.value;
      final initials = _getInitials(sName);

      return SliverGradientHeader(
        expandedHeight: 185.0,
        overline: DateFormat('EEEE, d MMMM')
            .format(DateTime.now())
            .toUpperCase(),
        title: 'Attendance',
        subtitle: sName.isNotEmpty
            ? sName
            : 'Daily routine & verification',
        heroLeading: Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              initials,
              style: AppTextStyles.headline.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        actions: [
          HeaderIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: controller.load,
          ),
        ],
        child: Builder(
          builder: (context) {
            final pills = [
              if (sRoom.isNotEmpty)
                HeaderPill(
                  icon: Icons.meeting_room_outlined,
                  label: sRoom.toLowerCase().contains('room')
                      ? sRoom
                      : 'Room $sRoom',
                ),
              if (sGroup.isNotEmpty)
                HeaderPill(
                  icon: Icons.groups_outlined,
                  label: sGroup,
                ),
              if (sCode.isNotEmpty)
                HeaderPill(
                  icon: Icons.badge_outlined,
                  label: 'ID: $sCode',
                ),
            ];
            if (pills.isEmpty) return const SizedBox.shrink();
            return Row(
              children: [
                for (int i = 0; i < pills.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppDimens.gapSm),
                  Expanded(child: pills[i]),
                ],
              ],
            );
          },
        ),
      );
    });
  }

  Widget _buildScheduleCard({
    required AttendanceScheduleItem item,
    required bool isMarked,
    required bool isActiveNow,
  }) {
    final iconData = _resolveScheduleIcon(item.iconName, item.attendanceType);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (isMarked) {
            NamedropAttendanceOverlay.show(
              context,
              title: 'Attendance Marked!',
              sessionName: item.sessionName,
              eventType: item.attendanceType,
              subtitle: 'Attendance verified for ${item.sessionName}.',
            );
          } else if (isActiveNow) {
            _performBleScan(item.attendanceType, isAttendanceOpen: true);
          } else if (!item.isScheduledToday) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${item.sessionName} is not scheduled for today.',
                ),
                duration: const Duration(seconds: 2),
                backgroundColor: const Color(0xFF376682),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${item.sessionName} will be available between ${item.startTime} and ${item.endTime}.',
                ),
                duration: const Duration(seconds: 2),
                backgroundColor: const Color(0xFF376682),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActiveNow
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : const Color(0xFFF3F1EC),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isActiveNow
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Box - soft squircle pastel background with teal-navy icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EDF2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: const Color(0xFF3B6B82), size: 19),
              ),
              const SizedBox(width: 8),
              // Session Info (Title, Timing, Late Pill)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.sessionName,
                      style: AppTextStyles.title.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E2D38),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.startTime} – ${item.endTime}',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: const Color(0xFF9AA7B0),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (item.lateTime != null &&
                        item.lateTime!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDEEE2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Late after ${item.lateTime}',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFF8A5A1F),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Right Status Pill (Upcoming, Open Now, Done)
              if (isMarked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Done',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF2E7D32),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (isActiveNow)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    'Open Now',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (!item.isScheduledToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F1EC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Not Today',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF8C9BA5),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF4F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Upcoming',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF5E8A9D),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          loadingWidget: const _AttendanceSkeleton(),
          builder: (context) {
            final statusData = controller.studentStatus.value;

            // Resolve list of session schedules
            final schedules = controller.schedulesList.isNotEmpty
                ? controller.schedulesList.toList()
                : const [
                    AttendanceScheduleItem(
                      sessionKey: 'aarti',
                      sessionName: 'Aarti',
                      iconName: 'users',
                      startTime: '18:45',
                      endTime: '19:20',
                      lateTime: '19:10',
                    ),
                    AttendanceScheduleItem(
                      sessionKey: 'weekly_assembly',
                      sessionName: 'Weekly Assembly',
                      iconName: 'users',
                      startTime: '20:50',
                      endTime: '21:20',
                      lateTime: '21:16',
                    ),
                    AttendanceScheduleItem(
                      sessionKey: 'night',
                      sessionName: 'Night',
                      iconName: 'moon',
                      startTime: '22:30',
                      endTime: '23:05',
                    ),
                  ];

            return AppRefreshIndicator(
              onRefresh: controller.load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  _buildHeader(),
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 18),

                          // 1. "Today's Schedule" Section Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAAB78),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Today's Schedule",
                                  style: AppTextStyles.headline.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF22333C),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${schedules.length} sessions',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 13,
                                    color: const Color(0xFF8C9BA5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Side Timing & Schedule Cards List
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              children: [
                                for (int i = 0; i < schedules.length; i++) ...[
                                  Builder(
                                    builder: (context) {
                                      final item = schedules[i];
                                      final type = item.attendanceType;
                                      final markedTime =
                                          controller.todayStatus[type];
                                      final isMarked =
                                          markedTime != null ||
                                          (controller.alreadyMarked.value &&
                                              statusData?.activeType == type);
                                      final isWindowOpen =
                                          item.isScheduledToday &&
                                              _isTimingActiveNow(
                                                item.startTime,
                                                item.endTime,
                                              );
                                      final isActiveNow = !isMarked &&
                                          item.isScheduledToday &&
                                          (isWindowOpen ||
                                              (controller.attendanceActive.value &&
                                                  statusData?.activeType == type));

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              // Left side timing (horizontal, strictly on one line)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 19,
                                                ),
                                                child: SizedBox(
                                                  width: 38,
                                                  child: Text(
                                                    item.startTime,
                                                    maxLines: 1,
                                                    softWrap: false,
                                                    textAlign: TextAlign.right,
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                          color: const Color(
                                                            0xFF8C9BA5,
                                                          ),
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          letterSpacing: -0.2,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),

                                              // Vertical connecting line and dot
                                              CustomPaint(
                                                painter: _TimelinePainter(
                                                  isFirst: i == 0,
                                                  isLast: i == schedules.length - 1,
                                                  lineColor: const Color(
                                                    0xFFE5E2DA,
                                                  ),
                                                  dotColor: const Color(0xFF376682),
                                                  dotCenterY: 29,
                                                ),
                                                child: const SizedBox(width: 10),
                                              ),
                                              const SizedBox(width: 6),

                                              // Schedule Card
                                              Expanded(
                                                child: _buildScheduleCard(
                                                  item: item,
                                                  isMarked: isMarked,
                                                  isActiveNow: isActiveNow,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AttendanceSkeleton extends StatelessWidget {
  const _AttendanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverGradientHeader(
          overline: DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(),
          title: 'Attendance',
          titleStyle: AppTextStyles.headline.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
          subtitle: 'Daily routine & verification',
          expandedHeight: 145.0,
          actions: [
            HeaderIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              onPressed: () {},
            ),
            const SizedBox(width: AppDimens.gapSm),
          ],
          child: Row(
            children: [
              SkeletonLoader(
                width: 105,
                height: 32,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                baseColor: Colors.white.withValues(alpha: 0.18),
                highlightColor: Colors.white.withValues(alpha: 0.40),
              ),
              const SizedBox(width: AppDimens.gapSm),
              SkeletonLoader(
                width: 95,
                height: 32,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                baseColor: Colors.white.withValues(alpha: 0.18),
                highlightColor: Colors.white.withValues(alpha: 0.40),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Action Card Skeleton
                    AppCard(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Center(
                            child: SkeletonLoader(
                              width: 72,
                              height: 72,
                              borderRadius: BorderRadius.circular(999),
                              baseColor: AppColors.primary.withValues(alpha: 0.10),
                              highlightColor: AppColors.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: SkeletonLoader(
                              width: 160,
                              height: 22,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: SkeletonLoader(
                              width: 130,
                              height: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: SkeletonLoader(
                              width: 240,
                              height: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SkeletonLoader(
                            width: double.infinity,
                            height: 52,
                            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section Heading Skeleton
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SkeletonLoader(
                          width: 140,
                          height: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3 Session Card Skeletons
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      AppCard(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            SkeletonLoader(
                              width: 44,
                              height: 44,
                              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonLoader(
                                    width: 110,
                                    height: 16,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  const SizedBox(height: 6),
                                  SkeletonLoader(
                                    width: 85,
                                    height: 12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                            ),
                            SkeletonLoader(
                              width: 76,
                              height: 28,
                              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final bool isFirst;
  final bool isLast;
  final Color lineColor;
  final Color dotColor;
  final double dotCenterY;

  const _TimelinePainter({
    required this.isFirst,
    required this.isLast,
    required this.lineColor,
    required this.dotColor,
    required this.dotCenterY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw line above dot (short top line for first item, full top for others)
    final topY = isFirst ? 10.0 : 0.0;
    canvas.drawLine(
      Offset(centerX, topY),
      Offset(centerX, dotCenterY),
      linePaint,
    );

    // Draw line from dot to bottom (if not last)
    if (!isLast) {
      canvas.drawLine(
        Offset(centerX, dotCenterY),
        Offset(centerX, size.height),
        linePaint,
      );
    }

    // Draw solid circle dot matching user screenshot
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX, dotCenterY), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.isFirst != isFirst ||
      oldDelegate.isLast != isLast ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.dotCenterY != dotCenterY;
}
