import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../common_models/charts/chart_point.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import 'app_card.dart';

/// Bar chart card whose bars grow up from zero on first appearance (and
/// animate between values afterwards), with gradient rods over faint
/// full-height tracks.
class ChartCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<ChartPoint> points;
  final Color barColor;
  final String Function(double value)? valueLabel;

  const ChartCard({
    super.key,
    required this.title,
    required this.points,
    this.subtitle,
    this.barColor = AppColors.primaryLight,
    this.valueLabel,
  });

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // First frame renders empty bars; flipping on the next frame lets
    // fl_chart's implicit animation grow them from zero.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final peak = points.isEmpty
        ? 0.0
        : points.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxY = peak == 0 ? 10.0 : peak * 1.25;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppTextStyles.subtitle),
          if (widget.subtitle != null)
            Text(widget.subtitle!, style: AppTextStyles.bodySm),
          const SizedBox(height: 18),
          SizedBox(
            height: 170,
            child: points.isEmpty
                ? Center(child: Text('No data yet', style: AppTextStyles.bodySm))
                : BarChart(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.deepSlate,
                          tooltipBorderRadius: BorderRadius.circular(10),
                          getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                            widget.valueLabel?.call(rod.toY) ??
                                rod.toY.toStringAsFixed(0),
                            AppTextStyles.caption.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  points[i].label,
                                  style: AppTextStyles.caption,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < points.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: _shown ? points[i].value : 0,
                                width: 20,
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [AppColors.indigo, widget.barColor],
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: AppColors.surfaceMuted,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
