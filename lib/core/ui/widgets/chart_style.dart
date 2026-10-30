import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:medical24/core/ui/tokens.dart';

class M24ChartStyle {
  const M24ChartStyle._();

  static LineChartBarData line(BuildContext context, List<FlSpot> spots) {
    final M24Colors c = context.m24.colors;
    return LineChartBarData(spots: spots, isCurved: true, color: c.chart, barWidth: 2.5, dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 5, color: c.surface, strokeWidth: 2, strokeColor: c.chart)), belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[c.chart.withValues(alpha: .22), c.chart.withValues(alpha: 0)])));
  }

  static FlGridData grid(BuildContext context) => FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: context.m24.colors.divider, strokeWidth: 1));
  static FlTitlesData titles(BuildContext context) => FlTitlesData(topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0), style: context.m24.text.caption))), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0), style: context.m24.text.caption))));
  static LineTouchData touch(BuildContext context) => LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => context.m24.colors.ink, tooltipRoundedRadius: 10, getTooltipItems: (spots) => spots.map((spot) => LineTooltipItem(spot.y.toStringAsFixed(1), context.m24.text.label.copyWith(color: M24Colors.white, fontWeight: FontWeight.w600))).toList()));
  static RangeAnnotations referenceBand(BuildContext context, {required double minY, required double maxY}) => RangeAnnotations(horizontalRangeAnnotations: <HorizontalRangeAnnotation>[HorizontalRangeAnnotation(y1: minY, y2: maxY, color: context.m24.colors.primaryTint.withValues(alpha: .6))]);
}