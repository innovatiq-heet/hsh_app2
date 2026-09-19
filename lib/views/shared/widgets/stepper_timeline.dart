import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../utils/date_formatting.dart';

class TimelineStage {
  final String label;
  final DateTime? timestamp;
  final bool isDone;
  final bool isActive;
  final VoidCallback? onTap;

  const TimelineStage({
    required this.label,
    this.timestamp,
    required this.isDone,
    this.isActive = false,
    this.onTap,
  });
}

/// Horizontal stage tracker for flows with a fixed set of ordered
/// timestamps (laundry pending→accepted→washed→received, complaint
/// pending→reviewed→resolved).
class StepperTimeline extends StatelessWidget {
  final List<TimelineStage> stages;

  const StepperTimeline({super.key, required this.stages});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(stages.length * 2 - 1, (i) {
        if (i.isOdd) {
          final leftIdx = i ~/ 2;
          final rightIdx = leftIdx + 1;
          final isConnectingDone =
              stages[leftIdx].isDone && (stages[rightIdx].isDone || stages[rightIdx].isActive);
          return Expanded(
            child: Container(
              height: 2.5,
              color: isConnectingDone
                  ? AppColors.successGreen
                  : AppColors.border,
            ),
          );
        }
        final stageIndex = i ~/ 2;
        final stage = stages[stageIndex];

        Color circleBg;
        Color circleBorder;
        Widget? circleChild;

        if (stage.isDone) {
          circleBg = AppColors.successGreen;
          circleBorder = AppColors.successGreen;
          circleChild = const Icon(Icons.check_rounded, size: 16, color: Colors.white);
        } else if (stage.isActive) {
          circleBg = AppColors.primary;
          circleBorder = AppColors.primary;
          circleChild = Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          );
        } else {
          circleBg = AppColors.surface;
          circleBorder = AppColors.border;
          circleChild = Text(
            '${stageIndex + 1}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          );
        }

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: circleBorder,
                  width: 2,
                ),
                boxShadow: stage.isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(child: circleChild),
            ),
            const SizedBox(height: AppDimens.gapXs),
            SizedBox(
              width: 72,
              child: Text(
                stage.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: stage.isDone || stage.isActive
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: stage.isDone
                      ? AppColors.textPrimary
                      : (stage.isActive
                          ? AppColors.primary
                          : AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 2),
            if (stage.isDone && stage.timestamp != null)
              Text(
                DateFormatting.time(stage.timestamp!),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              )
            else if (stage.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: Text(
                  'Current',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              )
            else
              const Text(
                '—',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        );

        if (stage.onTap != null) {
          return InkWell(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            onTap: stage.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: content,
            ),
          );
        }

        return content;
      }),
    );
  }
}
