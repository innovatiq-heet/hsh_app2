import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';
import 'fade_slide_in.dart';
import 'status_badge.dart';

enum TimelineState { done, active, upcoming }

class VerticalTimelineStep {
  final String title;
  final String? subtitle;
  final IconData icon;
  final TimelineState state;

  const VerticalTimelineStep({
    required this.title,
    required this.icon,
    required this.state,
    this.subtitle,
  });
}

/// Vertical status history (e.g. complaint ticket lifecycle). Done steps
/// are gradient-filled, the active step pulses, upcoming steps are muted;
/// rows stagger in.
class VerticalTimeline extends StatelessWidget {
  final List<VerticalTimelineStep> steps;
  final Color color;

  const VerticalTimeline({
    super.key,
    required this.steps,
    this.color = AppColors.primaryLight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          FadeSlideIn(
            index: i,
            offset: 16,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 40,
                    child: Column(
                      children: [
                        _StepNode(step: steps[i], color: color),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                gradient: steps[i].state == TimelineState.done
                                    ? LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [AppColors.indigo, color],
                                      )
                                    : null,
                                color: steps[i].state == TimelineState.done
                                    ? null
                                    : AppColors.border,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapMd),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: 8,
                        bottom: i < steps.length - 1 ? AppDimens.gapXl : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: AppTextStyles.subtitle.copyWith(
                              color: steps[i].state == TimelineState.upcoming
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (steps[i].subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(steps[i].subtitle!, style: AppTextStyles.bodySm),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  final VerticalTimelineStep step;
  final Color color;

  const _StepNode({required this.step, required this.color});

  @override
  Widget build(BuildContext context) {
    switch (step.state) {
      case TimelineState.done:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [AppColors.indigo, color]),
            boxShadow: AppColors.glow(color, 0.4),
          ),
          child: Icon(step.icon, size: 18, color: Colors.white),
        );
      case TimelineState.active:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(child: PulsingDot(color: color, size: 9)),
        );
      case TimelineState.upcoming:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceMuted,
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Icon(step.icon, size: 16, color: AppColors.textMuted),
        );
    }
  }
}
