import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';

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
          final leftDone = stages[i ~/ 2].isDone;
          return Expanded(
            child: Container(
              height: 2,
              color: leftDone ? AppColors.successGreen : AppColors.border,
            ),
          );
        }
        final stage = stages[i ~/ 2];
        return Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: stage.isDone
                    ? AppColors.successGreen
                    : AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: stage.isDone
                      ? AppColors.successGreen
                      : AppColors.border,
                  width: 2,
                ),
              ),
              child: stage.isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: AppDimens.gapXs),
            SizedBox(
              width: 72,
              child: Text(
                stage.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: stage.isDone
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
            if (stage.timestamp != null)
              Text(
                '${stage.timestamp!.hour.toString().padLeft(2, '0')}:${stage.timestamp!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        );
      }),
    );
  }
}
