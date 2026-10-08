import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/storage/session_store.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/staggered_slide_fade.dart';

class _OperatorAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _OperatorAction(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.route,
  );
}

class _OperatorGroup {
  final String title;
  final List<_OperatorAction> actions;

  const _OperatorGroup(this.title, this.actions);
}

/// Converges what used to be separate laundry-admin/complain-admin/leader
/// screens into one role-aware operator shell (spec §3) — admin/warden
/// land here after login.
class OperatorHomeScreen extends StatelessWidget {
  const OperatorHomeScreen({super.key});

  static const _groups = [
    _OperatorGroup('Student Management & Safety', [
      _OperatorAction(
        'Student Phonebook',
        'Campus contacts & caller directory',
        Icons.contact_phone_rounded,
        AppColors.primary,
        Routes.operatorDirectory,
      ),
      _OperatorAction(
        'Screen Time',
        'Telemetry, app restrictions & usage analytics',
        Icons.phone_android_rounded,
        Color(0xFF8B4513),
        Routes.studentScreenTime,
      ),
      _OperatorAction(
        'Campus Geofence',
        'Curfew hours, hostel perimeter & breach alerts',
        Icons.fmd_good_rounded,
        Color(0xFFE65100),
        Routes.operatorGeofence,
      ),
      _OperatorAction(
        'Student Locations',
        'Every student\'s current location on the map',
        Icons.share_location_rounded,
        Color(0xFF00796B),
        Routes.operatorStudentLocations,
      ),
      // --- Temporarily disabled mock features ---
      // _OperatorAction(
      //   'Admissions',
      //   'Review and approve new student applications',
      //   Icons.how_to_reg_rounded,
      //   AppColors.successGreen,
      //   Routes.operatorAdmissions,
      // ),
      // _OperatorAction(
      //   'Room Swap',
      //   'Manage and execute room exchange requests',
      //   Icons.swap_horiz_rounded,
      //   AppColors.secondary,
      //   Routes.operatorRoomSwap,
      // ),
      // _OperatorAction(
      //   'Mark Left',
      //   'Checkout and archive departing students',
      //   Icons.person_remove_rounded,
      //   AppColors.cancelledRed,
      //   Routes.operatorMarkLeft,
      // ),
    ]),
    _OperatorGroup('Alumni Network & Community', [
      _OperatorAction(
        'Alumni Console (Admin)',
        'Events, RSVPs, news, giving back & verifications',
        Icons.admin_panel_settings_rounded,
        Color(0xFF8B5CF6),
        Routes.operatorAlumni,
      ),
      _OperatorAction(
        'Alumni Directory',
        'Search pass-out students by batch, company & city',
        Icons.people_alt_rounded,
        Color(0xFF6366F1),
        Routes.alumniDirectory,
      ),
      _OperatorAction(
        'Events & Reunions',
        'Hostel reunions, annual sabhas & RSVP tracking',
        Icons.event_available_rounded,
        AppColors.warningOrange,
        Routes.alumniEvents,
      ),
      _OperatorAction(
        'Giving Back & News',
        'Hostel announcements, news & contribution initiatives',
        Icons.volunteer_activism_rounded,
        Color(0xFFEC4899),
        Routes.alumniNews,
      ),
      // --- Redundant student-only links commented out ---
      // _OperatorAction(
      //   'Alumni Hub (Student View)',
      //   'Main alumni network portal & community dashboard',
      //   Icons.school_rounded,
      //   Color(0xFF0EA5E9),
      //   Routes.alumniHub,
      // ),
      // _OperatorAction(
      //   'Job Board & Referrals',
      //   'Alumni career referrals, openings & internships',
      //   Icons.work_outline_rounded,
      //   AppColors.successGreen,
      //   Routes.alumniJobs,
      // ),
    ]),
    _OperatorGroup('Approvals & Services', [
      _OperatorAction(
        'Complaints Desk',
        'Inspect, assign & resolve student complaints',
        Icons.handyman_rounded,
        Color(0xFF7C3AED),
        Routes.complainSolverModule,
      ),
      _OperatorAction(
        'Laundry Desk',
        'Manage wash cycles, batches & student balances',
        Icons.local_laundry_service_rounded,
        Color(0xFF0EA5E9),
        Routes.laundryModule,
      ),
      // --- Temporarily disabled mock features ---
      // _OperatorAction(
      //   'Leave Requests',
      //   'Review & approve gate passes and leave slips',
      //   Icons.event_note_rounded,
      //   AppColors.warningOrange,
      //   Routes.operatorLeaveApprovals,
      // ),
      // _OperatorAction(
      //   'Fee Approvals',
      //   'Verify bank receipts & fee payment slips',
      //   Icons.fact_check_rounded,
      //   Color(0xFF0284C7),
      //   Routes.operatorFeeApprovals,
      // ),
    ]),
    _OperatorGroup('Attendance & Roll Call', [
      _OperatorAction(
        'Dynamic QR Code',
        'Display rotating QR code for roll call',
        Icons.qr_code_2_rounded,
        AppColors.primary,
        Routes.operatorAttendanceQrDisplay,
      ),
      _OperatorAction(
        'Attendance History',
        'Review daily logs & attendance records',
        Icons.history_rounded,
        Color(0xFFF59E0B),
        Routes.attendanceHistory,
      ),
      // --- Temporarily disabled mock features ---
      // _OperatorAction(
      //   'Attendance on Behalf',
      //   'Manual check-in and attendance override',
      //   Icons.edit_calendar_rounded,
      //   Color(0xFF0D9488),
      //   Routes.operatorAttendanceOnBehalf,
      // ),
      // _OperatorAction(
      //   'Sabha Management',
      //   'Schedule spiritual sabhas & track participation',
      //   Icons.event_rounded,
      //   Color(0xFF6366F1),
      //   Routes.operatorSabha,
      // ),
      // _OperatorAction(
      //   'Deposits & Debits',
      //   'Post wallet ledger transactions & adjustments',
      //   Icons.account_balance_wallet_rounded,
      //   AppColors.successGreen,
      //   Routes.operatorDepositDebit,
      // ),
    ]),
  ];

  Future<void> _logout() async {
    await Get.find<SessionStore>().clear();
    Get.offAllNamed(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverGradientHeader(
            overline: 'Operator console',
            title: 'Hostel admin',
            subtitle: 'Manage students, approvals and finance',
            expandedHeight: 220.0,
            actions: [
              HeaderIconButton(
                icon: Icons.logout_rounded,
                tooltip: 'Log out',
                onPressed: _logout,
              ),
            ],
            child: HeaderPill(
              icon: Icons.calendar_today_rounded,
              label: DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapXl,
                AppDimens.screenPadding,
                AppDimens.gapXxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in _groups) ...[
                    SectionHeader(title: group.title),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppDimens.gapMd,
                      crossAxisSpacing: AppDimens.gapMd,
                      childAspectRatio: 1.25,
                      children: [
                        for (int i = 0; i < group.actions.length; i++)
                          StaggeredSlideFade(
                            index: i,
                            child: _ActionTile(action: group.actions[i]),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.gapXl),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final _OperatorAction action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.gapLg),
      onTap: () => Get.toNamed(action.route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: action.icon, color: action.color),
          const Spacer(),
          Text(
            action.title,
            style: AppTextStyles.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            action.subtitle,
            style: AppTextStyles.bodySm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
