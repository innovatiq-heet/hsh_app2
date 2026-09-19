import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../common_models/charts/chart_point.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';
import 'app_card.dart';

/// Donut breakdown card with a legend. Segments sweep open on first
/// appearance; tapping a segment pops it out.
class DonutChartCard extends StatefulWidget {
  final String title;
  final List<ChartPoint> points;
  final Widget? center;
  final String Function(double value) valueLabel;

  static const palette = [
    AppColors.indigo,
    AppColors.primaryLight,
    AppColors.cyan,
    AppColors.violet,
    AppColors.warningOrange,
    AppColors.successGreen,
  ];

  const DonutChartCard({
    super.key,
    required this.title,
    required this.points,
    required this.valueLabel,
    this.center,
  });

  @override
  State<DonutChartCard> createState() => _DonutChartCardState();
}

class _DonutChartCardState extends State<DonutChartCard> {
  bool _shown = false;
  int _touched = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  Color _color(int i) =>
      DonutChartCard.palette[i % DonutChartCard.palette.length];

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppTextStyles.subtitle),
          const SizedBox(height: AppDimens.gapLg),
          Row(
            children: [
              SizedBox.square(
                dimension: 138,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      PieChartData(
                        centerSpaceRadius: 44,
                        sectionsSpace: 3,
                        startDegreeOffset: -90,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            final i =
                                response?.touchedSection?.touchedSectionIndex ?? -1;
                            if (!event.isInterestedForInteractions) {
                              if (_touched != -1) setState(() => _touched = -1);
                              return;
                            }
                            if (i != _touched) setState(() => _touched = i);
                          },
                        ),
                        sections: [
                          for (int i = 0; i < points.length; i++)
                            PieChartSectionData(
                              value: points[i].value,
                              color: _color(i),
                              showTitle: false,
                              radius: !_shown ? 0 : (i == _touched ? 24 : 18),
                            ),
                        ],
                      ),
                    ),
                    ?widget.center,
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.gapXl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < points.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _color(i),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                points[i].label,
                                style: AppTextStyles.bodySm,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              widget.valueLabel(points[i].value),
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
