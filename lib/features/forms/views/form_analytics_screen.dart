import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/utils/string_formatting.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/meta_text.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_strip.dart';
import '../controllers/form_analytics_controller.dart';
import '../widgets/forms_widgets.dart';

/// Operator → Forms & Polls → Results.
class FormAnalyticsScreen extends GetView<FormAnalyticsController> {
  const FormAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: AppRefreshIndicator(
          onRefresh: () => controller.load(showLoading: false),
          child: Obx(() {
            final a = controller.analytics.value;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverGradientHeader(
                  overline: 'Results',
                  title: controller.title.value.isEmpty ? 'Results' : controller.title.value,
                  titleMaxLines: 2,
                  leading: HeaderIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  child: a == null ? null : HeaderPill(icon: Icons.percent_rounded, label: '${a.responseRate}% answered'),
                ),
                if (a == null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: controller.hasError.value
                        ? EmptyState(
                            icon: Icons.cloud_off_rounded,
                            title: 'Could not load results',
                            message: controller.errorMessage.value,
                            actionLabel: 'Retry',
                            onAction: controller.load,
                          )
                        : const Center(child: CircularProgressIndicator()),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapXl, AppDimens.screenPadding, 40),
                    sliver: SliverList.list(children: [
                      _Summary(a: a),
                      const SizedBox(height: AppDimens.gapXl),
                      const SectionHeader(title: 'Answers'),
                      if (a.fields.isEmpty)
                        const NoticeBanner(icon: Icons.hourglass_empty_rounded, message: 'No answers yet.'),
                      for (final f in a.fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                          child: _FieldResult(field: f, analytics: a),
                        ),
                      const SizedBox(height: AppDimens.gapLg),
                      const SectionHeader(title: 'Students'),
                      _PeopleTabs(a: a),
                    ]),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final FormAnalytics a;

  const _Summary({required this.a});

  @override
  Widget build(BuildContext context) {
    return StatStrip(items: [
      StatStripItem(value: '${a.totalTargeted}', label: 'Targeted'),
      StatStripItem(value: '${a.totalResponded}', label: 'Answered', color: AppColors.successGreen),
      StatStripItem(value: '${a.seenNotAnswered}', label: 'Seen only', color: AppColors.warningOrange),
      StatStripItem(value: '${a.neverSeen}', label: 'Not seen', color: AppColors.textMuted),
    ]);
  }
}

class _FieldResult extends StatelessWidget {
  final FieldAnalytics field;
  final FormAnalytics analytics;

  const _FieldResult({required this.field, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final top = field.breakdown.isEmpty
        ? 0
        : field.breakdown.map((b) => b.count).reduce((x, y) => x > y ? x : y);
    final def = analytics.form.fields.firstWhereOrNull((f) => f.answerKey == field.fieldId);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label.isEmpty ? field.fieldId : field.label, style: AppTextStyles.subtitle),
          const SizedBox(height: AppDimens.gapXs),
          MetaText(icon: Icons.check_circle_outline_rounded, text: '${field.totalAnswered} answered · ${field.type.label}'),
          const SizedBox(height: AppDimens.gapLg),
          if (field.breakdown.isNotEmpty)
            for (final b in field.breakdown) BreakdownBar(item: b, isTop: b.count == top && top > 0)
          else
            // Free text / number: list the answers themselves.
            ..._textAnswers(def),
        ],
      ),
    );
  }

  List<Widget> _textAnswers(FormFieldDef? def) {
    final answers = [
      for (final p in analytics.responses)
        if (p.answers[field.fieldId] != null && p.answers[field.fieldId].toString().trim().isNotEmpty)
          (p, p.answers[field.fieldId]),
    ];
    if (answers.isEmpty) {
      return [Text('No answers yet.', style: AppTextStyles.bodySm)];
    }
    return [
      for (final (p, v) in answers.take(30))
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppDimens.gapSm),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapMd, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatPersonName(p.name), style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(def == null ? v.toString() : describeAnswer(def, v), style: AppTextStyles.bodyMd),
            ],
          ),
        ),
      if (answers.length > 30)
        Text('+${answers.length - 30} more', style: AppTextStyles.caption),
    ];
  }
}

class _PeopleTabs extends StatefulWidget {
  final FormAnalytics a;

  const _PeopleTabs({required this.a});

  @override
  State<_PeopleTabs> createState() => _PeopleTabsState();
}

class _PeopleTabsState extends State<_PeopleTabs> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final lists = [a.responses, a.seenNotAnsweredList, a.notResponded];
    final labels = [
      'Answered (${a.responses.length})',
      'Seen (${a.seenNotAnsweredList.length})',
      'Not answered (${a.notResponded.length})',
    ];
    final people = lists[_tab];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: AppDimens.gapSm),
                child: ChoiceChip(label: Text(labels[i]), selected: _tab == i, onSelected: (_) => setState(() => _tab = i)),
              ),
          ]),
        ),
        const SizedBox(height: AppDimens.gapMd),
        if (people.isEmpty)
          const AppCard(
            child: Center(child: Text('Nobody here.')),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardPadding, vertical: AppDimens.gapXs),
            child: Column(
              children: [
                for (var i = 0; i < people.length; i++) ...[
                  if (i > 0) const Divider(color: AppColors.borderLight),
                  _PersonRow(person: people[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  final AnalyticsPerson person;

  const _PersonRow({required this.person});

  @override
  Widget build(BuildContext context) {
    final p = person;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.gapMd),
      child: Row(
        children: [
          const IconBadge(icon: Icons.person_rounded, size: 36),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPersonName(p.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(p.room.isEmpty ? 'No room' : 'Room ${p.room}', style: AppTextStyles.bodySm),
              ],
            ),
          ),
          if (p.at != null) MetaText(icon: Icons.schedule_rounded, text: DateFormatting.relativeTime(p.at!)),
        ],
      ),
    );
  }
}
