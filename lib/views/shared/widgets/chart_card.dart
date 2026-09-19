import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../common_models/charts/chart_point.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import 'app_card.dart';

/// Thin fl_chart wrapper used for laundry/fees stats.
class ChartCard extends StatelessWidget {
  final String title;
  final List<ChartPoint> points;
  final Color barColor;

  const ChartCard({
    super.key,
    required this.title,
    required this.points,
    this.barColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = points.isEmpty
        ? 10.0
        : (points.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.subtitle),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: points.isEmpty
                ? const Center(child: Text('No data'))
                : BarChart(
                    BarChartData(
                      maxY: maxY == 0 ? 10 : maxY,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
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
                                toY: points[i].value,
                                color: barColor,
                                width: 18,
                                borderRadius: BorderRadius.circular(4),
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
