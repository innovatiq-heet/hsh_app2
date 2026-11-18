import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/utils/string_formatting.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/meta_text.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../controllers/form_analytics_controller.dart';
import '../widgets/forms_widgets.dart';

/// Operator → Forms & Polls → Results, styled to match the Hostel Phonebook theme.
class FormAnalyticsScreen extends GetView<FormAnalyticsController> {
  const FormAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PhonebookTheme.bg,
        body: RefreshIndicator(
          onRefresh: () => controller.load(showLoading: false),
          color: PhonebookTheme.blue,
          backgroundColor: Colors.white,
          child: Obx(() {
            final a = controller.analytics.value;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: PhonebookHeaderDelegate(
                    overline: 'Results',
                    title: controller.title.value.isEmpty ? 'Results' : controller.title.value,
                    topPadding: MediaQuery.of(context).padding.top,
                    onLeadingTap: () => Navigator.of(context).maybePop(),
                    pills: a == null
                        ? null
                        : Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              PhonebookHeaderPill(
                                icon: Icons.percent_rounded,
                                label: '${a.responseRate}% answered',
                              ),
                              PhonebookHeaderPill(
                                icon: Icons.groups_rounded,
                                label: '${a.totalResponded} / ${a.totalTargeted} students',
                              ),
                            ],
                          ),
                  ),
                ),
                if (a == null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: controller.hasError.value
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: EmptyState(
                              icon: Icons.cloud_off_rounded,
                              title: 'Could not load results',
                              message: controller.errorMessage.value,
                              actionLabel: 'Retry',
                              onAction: controller.load,
                            ),
                          )
                        : const Center(child: CircularProgressIndicator(color: PhonebookTheme.blue)),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    sliver: SliverList.list(
                      children: [
                        _Summary(a: a),
                        const SizedBox(height: 18),
                        const PhonebookSectionHeader(title: 'Answers'),
                        if (a.fields.isEmpty)
                          const NoticeBanner(icon: Icons.hourglass_empty_rounded, message: 'No answers yet.'),
                        for (final f in a.fields)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FieldResult(field: f, analytics: a),
                          ),
                        const SizedBox(height: 10),
                        const PhonebookSectionHeader(title: 'Students'),
                        _PeopleTabs(a: a),
                      ],
                    ),
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: PhonebookCountCard(
                value: '${a.totalTargeted}',
                label: 'Targeted',
                icon: Icons.groups_outlined,
                color: PhonebookTheme.blue,
                bgColor: PhonebookTheme.blueSoft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PhonebookCountCard(
                value: '${a.totalResponded}',
                label: 'Answered',
                icon: Icons.check_circle_outline_rounded,
                color: PhonebookTheme.green,
                bgColor: PhonebookTheme.greenSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PhonebookCountCard(
                value: '${a.seenNotAnswered}',
                label: 'Seen only',
                icon: Icons.visibility_outlined,
                color: PhonebookTheme.amber,
                bgColor: PhonebookTheme.amberSoft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PhonebookCountCard(
                value: '${a.neverSeen}',
                label: 'Not seen',
                icon: Icons.visibility_off_outlined,
                color: PhonebookTheme.muted,
                bgColor: const Color(0xFFF1F5F9),
              ),
            ),
          ],
        ),
      ],
    );
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
    return PhonebookCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label.isEmpty ? field.fieldId : field.label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: PhonebookTheme.ink,
            ),
          ),
          const SizedBox(height: 4),
          MetaText(icon: Icons.check_circle_outline_rounded, text: '${field.totalAnswered} answered · ${field.type.label}'),
          const SizedBox(height: 14),
          if (field.breakdown.isNotEmpty)
            for (final b in field.breakdown) BreakdownBar(item: b, isTop: b.count == top && top > 0)
          else
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
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: PhonebookTheme.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PhonebookTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatPersonName(p.name),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: PhonebookTheme.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                def == null ? v.toString() : describeAnswer(def, v),
                style: const TextStyle(fontSize: 13.5, color: PhonebookTheme.ink),
              ),
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
    final colors = [PhonebookTheme.green, PhonebookTheme.amber, PhonebookTheme.muted];
    final people = lists[_tab];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                PhonebookPillTab(
                  label: labels[i],
                  selected: _tab == i,
                  color: colors[i],
                  onTap: () => setState(() => _tab = i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (people.isEmpty)
          const PhonebookCard(
            child: Center(
              child: Text(
                'Nobody here.',
                style: TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          PhonebookCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < people.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: PhonebookTheme.border),
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
          const IconBadge(icon: Icons.person_rounded, color: PhonebookTheme.blue, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPersonName(p.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: PhonebookTheme.ink,
                  ),
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
