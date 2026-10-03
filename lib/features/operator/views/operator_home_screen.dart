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
    _OperatorGroup('Student Management', [
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
