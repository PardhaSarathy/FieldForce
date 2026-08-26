import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../models/business.dart';

/// Charts for PharmaConnect (§80).
///
/// Deliberately plain: no gradients, no 3D, no decorative axes. A sales trend
/// exists to answer "is this going up", and every pixel that is not doing that
/// is in the way. Two series maximum — actual and its comparison.

/// Line chart for a value over time, optionally against a target series.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    this.height = 180,
    this.showComparison = false,
    this.comparisonLabel = 'Target',
    this.valueLabel = 'Actual',
    this.compactValues = true,
  });

  final List<ChartPoint> points;
  final double height;
  final bool showComparison;
  final String comparisonLabel;
  final String valueLabel;
  final bool compactValues;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data for this period', style: AppTypography.caption),
        ),
      );
    }

    final maxValue = points
        .map((p) => [p.value, if (showComparison) p.secondary ?? 0].reduce(
            (a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxValue == 0 ? 1 : maxValue * 1.15,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxValue == 0 ? 1 : maxValue / 3,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: maxValue == 0 ? 1 : maxValue / 2,
                    getTitlesWidget: (value, _) => Text(
                      _short(value),
                      style: AppTypography.caption.copyWith(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: (points.length / 6).ceilToDouble().clamp(1, 12),
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          points[index].label,
                          style: AppTypography.caption.copyWith(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.textPrimary,
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            _short(s.y),
                            AppTypography.caption
                                .copyWith(color: Colors.white),
                          ))
                      .toList(),
                ),
              ),
              lineBarsData: [
                _line(
                  [
                    for (var i = 0; i < points.length; i++)
                      FlSpot(i.toDouble(), points[i].value),
                  ],
                  AppColors.brand,
                  fill: true,
                ),
                if (showComparison)
                  _line(
                    [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].secondary ?? 0),
                    ],
                    AppColors.sand,
                    dashed: true,
                  ),
              ],
            ),
          ),
        ),
        if (showComparison) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.brand, label: valueLabel),
              const SizedBox(width: AppSpacing.lg),
              _LegendDot(color: AppColors.sand, label: comparisonLabel),
            ],
          ),
        ],
      ],
    );
  }

  LineChartBarData _line(
    List<FlSpot> spots,
    Color color, {
    bool fill = false,
    bool dashed = false,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      color: color,
      barWidth: 2.5,
      dashArray: dashed ? [5, 4] : null,
      dotData: FlDotData(
        show: spots.length <= 14,
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: 3,
          color: AppColors.surface,
          strokeWidth: 2,
          strokeColor: color,
        ),
      ),
      belowBarData: BarAreaData(
        show: fill,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  String _short(double value) {
    if (!compactValues) return value.round().toString();
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.round().toString();
  }
}

/// Horizontal bars for category comparison — expense split, product mix.
class CategoryBars extends StatelessWidget {
  const CategoryBars({
    super.key,
    required this.entries,
    this.valueFormatter,
    this.color = AppColors.brand,
  });

  final List<({String label, double value})> entries;
  final String Function(double)? valueFormatter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text('No data for this period', style: AppTypography.caption);
    }

    final max = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.label,
                          style: AppTypography.bodySm,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      valueFormatter?.call(entry.value) ??
                          entry.value.round().toString(),
                      style: AppTypography.numeric.copyWith(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : entry.value / max,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceSecondary,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Circular achievement gauge. Used once per screen at most — it is the single
/// figure that answers "am I on target".
class AchievementRing extends StatelessWidget {
  const AchievementRing({
    super.key,
    required this.percent,
    this.size = 150,
    this.label = 'Achieved',
  });

  final double percent;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = percent >= 100
        ? AppColors.success
        : percent >= 75
            ? AppColors.brand
            : percent >= 50
                ? AppColors.warning
                : AppColors.error;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.surfaceSecondary,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percent.round()}%',
                style: AppTypography.metric.copyWith(color: color),
              ),
              Text(label, style: AppTypography.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}
