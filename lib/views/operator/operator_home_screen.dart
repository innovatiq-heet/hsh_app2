import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../storage/session_store.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/icon_badge.dart';
import '../shared/widgets/section_header.dart';

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
    _OperatorGroup('Students', [
      _OperatorAction(
        'Directory',
        'Search all students',
        Icons.people_alt_outlined,
        AppColors.primary,
        Routes.operatorDirectory,
      ),
      _OperatorAction(
        'Admissions',
        'Approve new students',
        Icons.how_to_reg_outlined,
        AppColors.successGreen,
        Routes.operatorAdmissions,
      ),
      _OperatorAction(
        'Room swap',
        'Swap two rooms',
        Icons.swap_horiz_rounded,
        AppColors.secondary,
        Routes.operatorRoomSwap,
      ),
      _OperatorAction(
        'Mark left',
        'Archive a student',
        Icons.person_remove_outlined,
        AppColors.cancelledRed,
        Routes.operatorMarkLeft,
      ),
    ]),
    _OperatorGroup('Approvals', [
      _OperatorAction(
        'Leave requests',
        'Approve or reject',
        Icons.event_available_outlined,
        AppColors.warningOrange,
        Routes.operatorLeaveApprovals,
      ),
      _OperatorAction(
        'Fee slips',
        'Verify payments',
        Icons.fact_check_outlined,
        AppColors.primaryLight,
        Routes.operatorFeeApprovals,
      ),
      _OperatorAction(
        'Complaints desk',
        'Inspect and resolve',
        Icons.handyman_outlined,
        AppColors.secondary,
        Routes.complainSolverModule,
      ),
    ]),
    _OperatorGroup('Finance & events', [
      _OperatorAction(
        'Deposits & debits',
        'Post ledger entries',
        Icons.account_balance_wallet_outlined,
        AppColors.successGreen,
        Routes.operatorDepositDebit,
      ),
      _OperatorAction(
        'Sabha',
        'Schedule sessions',
        Icons.event_outlined,
        AppColors.primaryLight,
        Routes.operatorSabha,
      ),
      _OperatorAction(
        'Attendance',
        'Log on behalf',
        Icons.edit_calendar_outlined,
        AppColors.secondary,
        Routes.operatorAttendanceOnBehalf,
      ),
      _OperatorAction(
        'Dynamic QR',
        'Display rotating code',
        Icons.qr_code_2_rounded,
        AppColors.primary,
        Routes.operatorAttendanceQrDisplay,
      ),
    ]),
  ];

  Future<void> _logout() async {
    await SessionStore.instance.clear();
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
                      for (final action in group.actions)
                        _ActionTile(action: action),
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
