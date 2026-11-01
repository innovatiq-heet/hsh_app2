import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_dimens.dart';
import 'screen_time_sub_header.dart';

/// Chrome shared by the Screen Time sub-screens (usage, apps, history, daily
/// limit, blocked apps): theme background, the navy [ScreenTimeSubHeader] with
/// a back button, and a padded, scrolling body that stays clear of the
/// keyboard. Pass [onRefresh] to make the body pull-to-refresh.
class ScreenTimePage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget body;
  final Future<void> Function()? onRefresh;

  const ScreenTimePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.onRefresh,
  });

  /// Opens [page] on top of everything, including the shell's bottom bar.
  static Future<void> push(BuildContext context, Widget page) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// "Name • Room 306" under a sub-screen title.
  static String studentLine(dynamic student) {
    final name = student is Map ? (student['name'] ?? 'Student').toString() : 'Student';
    final room = student is Map ? (student['room'] ?? '').toString() : '';
    return room.isEmpty || room == 'N/A' ? name : '$name • Room $room';
  }

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        ScreenTimeSubHeader(
          title: title,
          subtitle: subtitle,
          onBack: () => Navigator.of(context).pop(),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            AppDimens.gapMd,
            16,
            AppDimens.gapXl +
                MediaQuery.of(context).padding.bottom +
                MediaQuery.viewInsetsOf(context).bottom,
          ),
          sliver: SliverToBoxAdapter(child: body),
        ),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: onRefresh == null
            ? scroll
            : RefreshIndicator(
                onRefresh: onRefresh!,
                color: const Color(0xFF0284C7),
                backgroundColor: Colors.white,
                child: scroll,
              ),
      ),
    );
  }
}
