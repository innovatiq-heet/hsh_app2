import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/notice_banner.dart';
import '../controllers/student_forms_controller.dart';
import '../widgets/forms_widgets.dart';

/// Student → Polls & Forms → one form: answer it, or see what was sent.
/// Route argument: the form id.
class StudentFormFillScreen extends StatefulWidget {
  const StudentFormFillScreen({super.key});

  @override
  State<StudentFormFillScreen> createState() => _StudentFormFillScreenState();
}

class _StudentFormFillScreenState extends State<StudentFormFillScreen> {
  final controller = Get.find<StudentFormsController>();
  late final int? _id = int.tryParse(Get.arguments?.toString() ?? '');
  final _answers = <String, dynamic>{};
  final _text = <String, TextEditingController>{};
  FormResponse? _response;

  /// Reads the observable list even when the id is missing, so the screen's
  /// Obx always has something to watch (GetX throws otherwise).
  StudentForm? get _form {
    final forms = controller.forms.toList();
    return _id == null ? null : forms.firstWhereOrNull((f) => f.id == _id);
  }

  @override
  void initState() {
    super.initState();
    final form = _form;
    if (form == null) return;
    controller.markViewed(form);
    if (form.hasSubmitted) {
      controller.responseFor(form).then((r) {
        if (mounted) setState(() => _response = r);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _textFor(FormFieldDef f) => _text.putIfAbsent(f.answerKey, TextEditingController.new);

  Future<void> _submit(StudentForm form) async {
    FocusScope.of(context).unfocus();
    final error = await controller.submit(form, Map.of(_answers));
    if (!mounted) return;
    if (error != null) {
      AppSnackbar.error('Not Submitted', error);
      return;
    }
    AppSnackbar.success('Submitted', form.kind == FormKind.poll ? 'Your vote is in.' : 'Thanks for your answers.');
    // Close with Navigator, not Get.back(): that would close the snackbar.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final form = _form;
      final submitted = form?.hasSubmitted ?? false;
      final closed = form?.endTime != null && form!.endTime!.isBefore(DateTime.now().toUtc());
      return Scaffold(
        backgroundColor: AppColors.mainBackground,
        bottomNavigationBar: form == null || submitted || closed
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapSm, AppDimens.screenPadding, AppDimens.gapMd),
                  child: AppButton(
                    label: form.kind == FormKind.poll ? 'Vote' : 'Submit',
                    icon: Icons.send_rounded,
                    isLoading: controller.submitting.contains(form.id),
                    onPressed: () => _submit(form),
                  ),
                ),
              ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverGradientHeader(
              overline: form?.kind == FormKind.poll ? 'Poll' : 'Form',
              title: form?.title ?? 'Not available',
              titleMaxLines: 2,
              subtitle: form?.endTime == null ? null : 'Closes ${DateFormatting.dateTime(form!.endTime!)}',
              leading: HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            if (form == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'This poll is no longer open',
                  message: 'Pull to refresh the list and try again.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapXl, AppDimens.screenPadding, 40),
                sliver: SliverList.list(children: [
                  if (form.description != null) ...[
                    Text(form.description!, style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: AppDimens.gapLg),
                  ],
                  if (submitted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.gapLg),
                      child: NoticeBanner(
                        icon: Icons.check_circle_rounded,
                        color: AppColors.successGreen,
                        message: (_response ?? form.myResponse)?.submittedAt == null
                            ? 'You have answered this.'
                            : 'You answered on ${DateFormatting.dateTime((_response ?? form.myResponse)!.submittedAt!)}.',
                      ),
                    )
                  else if (closed)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppDimens.gapLg),
                      child: NoticeBanner(
                        icon: Icons.event_busy_rounded,
                        color: AppColors.textSecondary,
                        message: 'This has closed. Answers are no longer accepted.',
                      ),
                    ),
                  for (var i = 0; i < form.fields.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _QuestionTitle(
                              number: form.fields.length > 1 ? i + 1 : null,
                              label: form.fields[i].label,
                              required: form.fields[i].required && !submitted,
                            ),
                            const SizedBox(height: AppDimens.gapMd),
                            if (submitted)
                              _SubmittedAnswer(
                                text: describeAnswer(
                                  form.fields[i],
                                  (_response ?? form.myResponse)?.answers[form.fields[i].answerKey],
                                ),
                              )
                            else
                              AnswerInput(
                                field: form.fields[i],
                                value: _answers[form.fields[i].answerKey],
                                textController: switch (form.fields[i].type) {
                                  FormFieldType.text || FormFieldType.textarea || FormFieldType.number => _textFor(form.fields[i]),
                                  _ => null,
                                },
                                onChanged: (v) => setState(() => _answers[form.fields[i].answerKey] = v),
                              ),
                          ],
                        ),
                      ),
                    ),
                ]),
              ),
          ],
        ),
      );
    });
  }
}

/// "2  Rate the mess *": a small number badge, the question, a required mark.
class _QuestionTitle extends StatelessWidget {
  final int? number;
  final String label;
  final bool required;

  const _QuestionTitle({required this.number, required this.label, required this.required});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (number != null) ...[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Text('$number', style: AppTextStyles.label.copyWith(color: AppColors.primaryLight)),
          ),
          const SizedBox(width: AppDimens.gapMd),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: label),
                if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.errorRed)),
              ]),
              style: AppTextStyles.subtitle.copyWith(height: 1.35),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmittedAnswer extends StatelessWidget {
  final String text;

  const _SubmittedAnswer({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, size: 20, color: AppColors.successGreen),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(child: Text(text, style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
