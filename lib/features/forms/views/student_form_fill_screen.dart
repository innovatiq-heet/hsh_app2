import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/empty_state.dart';
import '../controllers/student_forms_controller.dart';
import '../widgets/forms_widgets.dart';

/// Student → Polls & Forms → Form Fill & Details screen.
/// Executive Hostel Design featuring deep navy gradient orb header,
/// styled question cards, response states, and executive submit button.
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

  TextEditingController _textFor(FormFieldDef f) =>
      _text.putIfAbsent(f.answerKey, TextEditingController.new);

  Future<void> _submit(StudentForm form) async {
    FocusScope.of(context).unfocus();
    final error = await controller.submit(form, Map.of(_answers));
    if (!mounted) return;
    if (error != null) {
      AppSnackbar.error('Not Submitted', error);
      return;
    }
    AppSnackbar.success(
      'Submitted',
      form.kind == FormKind.poll ? 'Your vote is in.' : 'Thanks for your response.',
    );
    // Close with Navigator, not Get.back(): that would close the snackbar.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Obx(() {
        final form = _form;
        final submitted = form?.hasSubmitted ?? false;
        final closed =
            form?.endTime != null && form!.endTime!.isBefore(DateTime.now().toUtc());
        final isPoll = form?.kind == FormKind.poll;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          bottomNavigationBar: form == null || submitted || closed
              ? null
              : Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    MediaQuery.of(context).padding.bottom + 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Obx(() {
                    final isSubmitting = controller.submitting.contains(form.id);
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isSubmitting ? null : () => _submit(form),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF032B4F),
                                Color(0xFF025A8D),
                                Color(0xFF0284C7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isPoll ? Icons.how_to_vote_rounded : Icons.send_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isPoll ? 'Submit Vote' : 'Submit Answers',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  }),
                ),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Signature Deep Navy Executive Header
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF03192E),
                        Color(0xFF032B4F),
                        Color(0xFF025A8D),
                        Color(0xFF0369A1),
                      ],
                      stops: [0.0, 0.38, 0.75, 1.0],
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF03192E),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _HeaderOrbPainter())),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Back button & Status Pill
                          Row(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.of(context).maybePop(),
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.16),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (form != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: submitted
                                        ? const Color(0xFF10B981).withValues(alpha: 0.28)
                                        : (closed
                                            ? const Color(0xFF64748B).withValues(alpha: 0.28)
                                            : (form.isMandatory
                                                ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                                : Colors.white.withValues(alpha: 0.16))),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: submitted
                                          ? const Color(0xFF34D399)
                                          : (closed
                                              ? const Color(0xFF94A3B8)
                                              : (form.isMandatory
                                                  ? const Color(0xFFF87171)
                                                  : Colors.white.withValues(alpha: 0.28))),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        submitted
                                            ? Icons.check_circle_rounded
                                            : (closed
                                                ? Icons.event_busy_rounded
                                                : (form.isMandatory
                                                    ? Icons.priority_high_rounded
                                                    : Icons.edit_note_rounded)),
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        submitted
                                            ? 'Submitted'
                                            : (closed
                                                ? 'Ended'
                                                : (form.isMandatory
                                                    ? 'Required'
                                                    : 'Active')),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Overline Kind Pill
                          if (form != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPoll ? Icons.how_to_vote_rounded : Icons.assignment_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isPoll ? 'HOSTEL POLL' : 'HOSTEL FORM',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Form Title
                          Text(
                            form?.title ?? 'Poll Not Available',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Closes metadata pill
                          if (form?.endTime != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.event_outlined,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Closes ${DateFormatting.dateTime(form!.endTime!)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Description Card (if any)
                      if (form.description != null && form.description!.trim().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFBAE6FD)),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFF0284C7),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  form.description!,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF475569),
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Submitted Banner
                      if (submitted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDCFCE7),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF16A34A),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Response Recorded',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF166534),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (_response ?? form.myResponse)?.submittedAt == null
                                            ? 'You have answered this.'
                                            : 'Submitted on ${DateFormatting.dateTime((_response ?? form.myResponse)!.submittedAt!)}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (closed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFE4E6),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.event_busy_rounded,
                                    color: Color(0xFFE11D48),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Poll Ended',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF991B1B),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'This has closed. Answers are no longer accepted.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Questions list
                      for (var i = 0; i < form.fields.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ExecutiveQuestionTitle(
                                  number: form.fields.length > 1 ? i + 1 : null,
                                  label: form.fields[i].label,
                                  required: form.fields[i].required && !submitted,
                                ),
                                const SizedBox(height: 14),
                                if (submitted)
                                  _ExecutiveSubmittedAnswer(
                                    text: describeAnswer(
                                      form.fields[i],
                                      (_response ?? form.myResponse)
                                          ?.answers[form.fields[i].answerKey],
                                    ),
                                  )
                                else
                                  AnswerInput(
                                    field: form.fields[i],
                                    value: _answers[form.fields[i].answerKey],
                                    textController: switch (form.fields[i].type) {
                                      FormFieldType.text ||
                                      FormFieldType.textarea ||
                                      FormFieldType.number =>
                                        _textFor(form.fields[i]),
                                      _ => null,
                                    },
                                    onChanged: (v) =>
                                        setState(() => _answers[form.fields[i].answerKey] = v),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

/// Executive Question title with squircle number pill and required mark
class _ExecutiveQuestionTitle extends StatelessWidget {
  final int? number;
  final String label;
  final bool required;

  const _ExecutiveQuestionTitle({
    required this.number,
    required this.label,
    required this.required,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (number != null) ...[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'Q$number',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF032B4F),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: label,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Color(0xFFE11D48),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Executive Answer display card when already submitted
class _ExecutiveSubmittedAnswer extends StatelessWidget {
  final String text;

  const _ExecutiveSubmittedAnswer({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              size: 15,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ambient glowing orbs in the header background
class _HeaderOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final orb1 = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.2), 65, orb1);

    final orb2 = Paint()
      ..color = const Color(0xFF7C3AED).withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.8), 75, orb2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
