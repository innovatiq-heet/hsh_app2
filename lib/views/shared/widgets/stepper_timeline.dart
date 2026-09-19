import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../utils/date_formatting.dart';
import 'status_badge.dart';

class TimelineStage {
  final String label;
  final DateTime? timestamp;
  final bool isDone;

  const TimelineStage({
    required this.label,
    this.timestamp,
    required this.isDone,
  });
}

/// Horizontal stage tracker for flows with a fixed set of ordered
/// timestamps (laundry pending→accepted→washed→received). Connectors fill
/// one after another; the latest completed node glows and the next one
/// pulses. [compact] drops timestamps and shrinks nodes for list cards.
class StepperTimeline extends StatelessWidget {
  final List<TimelineStage> stages;
  final bool compact;
  final Color color;

  const StepperTimeline({
    super.key,
    required this.stages,
    this.compact = false,
    this.color = AppColors.primaryLight,
  });

  @override
  Widget build(BuildContext context) {
    final lastDone = stages.lastIndexWhere((s) => s.isDone);
    final nodeSize = compact ? 22.0 : 30.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < stages.length; i++) ...[
          _Node(
            stage: stages[i],
            size: nodeSize,
            color: color,
            compact: compact,
            isCurrent: i == lastDone,
            isNext: i == lastDone + 1,
          ),
          if (i < stages.length - 1)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: nodeSize / 2 - 1.5),
                child: _Connector(
                  filled: i < lastDone,
                  color: color,
                  delay: i,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Node extends StatelessWidget {
  final TimelineStage stage;
  final double size;
  final Color color;
  final bool compact;
  final bool isCurrent;
  final bool isNext;

  const _Node({
    required this.stage,
    required this.size,
    required this.color,
    required this.compact,
    required this.isCurrent,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    final done = stage.isDone;
    return SizedBox(
      width: compact ? 54 : 66,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: done
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.indigo, color],
                    )
                  : null,
              color: done ? null : AppColors.surface,
              border: done
                  ? null
                  : Border.all(
                      color: isNext
                          ? color.withValues(alpha: 0.5)
                          : AppColors.border,
                      width: 2,
                    ),
              boxShadow: isCurrent ? AppColors.glow(color, 0.55) : null,
            ),
            child: Center(
              child: done
                  ? Icon(Icons.check_rounded, size: size * 0.55, color: Colors.white)
                  : (isNext ? PulsingDot(color: color, size: size * 0.24) : null),
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            stage.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: compact ? 10 : 11,
              color: done ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: done ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          if (!compact && stage.timestamp != null)
            Text(
              DateFormatting.time(stage.timestamp!),
              style: AppTextStyles.caption.copyWith(fontSize: 10),
            ),
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  final bool filled;
  final Color color;
  final int delay;

  const _Connector({
    required this.filled,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(2),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: filled ? 1 : 0),
        duration: Duration(milliseconds: 500 + delay * 220),
        curve: Interval(delay * 0.2, 1, curve: Curves.easeOutCubic),
        builder: (context, v, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: v,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.indigo, color]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
