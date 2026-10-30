import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/core/ui/formatters.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/chart_style.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// M24 history chart with institutional range and flag-colored points.
class BiomarkerChart extends StatelessWidget {
  const BiomarkerChart({super.key, required this.primary, this.comparison, this.selectedEpisode});
  final List<BiomarkerPoint> primary;
  final List<BiomarkerPoint>? comparison;
  final BiomarkerEpisode? selectedEpisode;

  @override
  Widget build(BuildContext context) {
    if (primary.isEmpty) return Center(child: Text(context.l10n.t('healthHistoryNoPoints')));
    final List<BiomarkerPoint> first = _sample(_sorted(primary));
    final List<BiomarkerPoint> second = _sample(_sorted(comparison ?? const <BiomarkerPoint>[]));
    final bool normalized = second.isNotEmpty;
    final _Scale firstScale = _Scale(primary);
    final _Scale secondScale = _Scale(comparison ?? const <BiomarkerPoint>[]);
    final List<FlSpot> firstSpots = first.indexed.map(((int, BiomarkerPoint) entry) => FlSpot(entry.$1.toDouble(), normalized ? firstScale.normalize(entry.$2.value) : entry.$2.value)).toList(growable: false);
    final List<FlSpot> secondSpots = second.indexed.map(((int, BiomarkerPoint) entry) => FlSpot(entry.$1.toDouble(), secondScale.normalize(entry.$2.value))).toList(growable: false);
    const double minX = 0;
    final double maxX = math.max(first.length, second.length).toDouble() <= 1 ? 1 : math.max(first.length, second.length).toDouble() - 1;
    final String language = Localizations.localeOf(context).languageCode;
    return Semantics(label: context.l10n.t('healthChartSemantics'), child: LineChart(LineChartData(
      minX: minX,
      maxX: maxX,
      rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: _bands(context, primary, normalized ? firstScale : null), verticalRangeAnnotations: selectedEpisode == null ? const <VerticalRangeAnnotation>[] : <VerticalRangeAnnotation>[VerticalRangeAnnotation(x1: selectedEpisode!.start.millisecondsSinceEpoch.toDouble(), x2: (selectedEpisode!.end ?? DateTime.now()).millisecondsSinceEpoch.toDouble(), color: context.m24.colors.warningTint)]),
      gridData: M24ChartStyle.grid(context),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(topTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, interval: 1, getTitlesWidget: (double value, TitleMeta meta) {
        final int index = value.round();
        if (value != index || index < 0 || index >= first.length) return const SizedBox.shrink();
        return Padding(padding: EdgeInsets.only(top: index.isEven ? 0 : 12), child: Text(formatValue(first[index].value, rawValue: first[index].valueRaw, locale: language), style: context.m24.text.caption, maxLines: 1));
      })), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 68, getTitlesWidget: (double value, TitleMeta meta) => Text(normalized ? '${value.round()}%' : '${NumberFormat.compact(locale: language).format(value)} ${formatUnit(first.first.unit)}', style: context.m24.text.caption, maxLines: 1))), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: 1, getTitlesWidget: (double value, TitleMeta meta) {
        final int index = value.round();
        if (value != index || index < 0 || index >= first.length || index > 0 && _sameDay(first[index - 1].at, first[index].at)) return const SizedBox.shrink();
        final DateFormat date = first.length == 1 ? DateFormat.yMMMd(language) : DateFormat.Md(language);
        return Padding(padding: const EdgeInsets.only(top: 8), child: Text(date.format(first[index].at.toLocal()), style: context.m24.text.caption));
      }))),
      lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => context.m24.colors.ink, tooltipRoundedRadius: 10, getTooltipItems: (List<LineBarSpot> spots) => spots.map((LineBarSpot touched) {
        final List<BiomarkerPoint> source = touched.barIndex == 0 ? first : second;
        final BiomarkerPoint point = source[touched.spotIndex.clamp(0, source.length - 1)];
        return LineTooltipItem('${DateFormat.yMMMd(language).format(point.at)}\n${formatMeasurement(point.value, point.unit, rawValue: point.valueRaw, locale: language)}', context.m24.text.caption.copyWith(color: M24Colors.white));
      }).toList(growable: false))),
      lineBarsData: <LineChartBarData>[_bar(context, firstSpots, first, context.m24.colors.chart), if (secondSpots.isNotEmpty) _bar(context, secondSpots, second, context.m24.colors.indigo)],
    )));
  }

  LineChartBarData _bar(BuildContext context, List<FlSpot> spots, List<BiomarkerPoint> points, Color color) => LineChartBarData(spots: spots, isCurved: false, color: color, barWidth: 2.5, belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[color.withValues(alpha: .22), color.withValues(alpha: 0)])), dotData: FlDotData(show: true, getDotPainter: (FlSpot spot, double percent, LineChartBarData bar, int index) => FlDotCirclePainter(radius: selectedEpisode?.items.any((EpisodeItem item) => item.id == points[index].id) == true ? 6 : 5, color: _flagColor(context, points[index].flag), strokeWidth: 2, strokeColor: context.m24.colors.surface)));

  Color _flagColor(BuildContext context, ObservationFlag flag) => switch (flag) { ObservationFlag.within => context.m24.colors.success, ObservationFlag.below || ObservationFlag.above => context.m24.colors.warning, ObservationFlag.criticalLow || ObservationFlag.criticalHigh => context.m24.colors.danger, _ => context.m24.colors.neutral };

  List<HorizontalRangeAnnotation> _bands(BuildContext context, List<BiomarkerPoint> points, _Scale? scale) {
    final BiomarkerPoint point = points.last;
    double value(double input) => scale?.normalize(input) ?? input;
    final List<HorizontalRangeAnnotation> result = <HorizontalRangeAnnotation>[];
    if (point.institutionalLow != null && point.institutionalHigh != null) result.add(HorizontalRangeAnnotation(y1: value(point.institutionalLow!), y2: value(point.institutionalHigh!), color: context.m24.colors.primaryTint.withValues(alpha: .6)));
    return result;
  }

  List<BiomarkerPoint> _sample(List<BiomarkerPoint> source) {
    if (source.length <= 500) return source;
    final double step = (source.length - 1) / 499;
    return List<BiomarkerPoint>.generate(500, (int index) => source[(index * step).round()], growable: false);
  }

  List<BiomarkerPoint> _sorted(List<BiomarkerPoint> source) => List<BiomarkerPoint>.of(source)..sort((BiomarkerPoint a, BiomarkerPoint b) {
    final int byDate = a.at.compareTo(b.at);
    if (byDate != 0) return byDate;
    final int byCreated = (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
  });

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Scale {
  _Scale(List<BiomarkerPoint> points) : min = points.isEmpty ? 0 : points.map((BiomarkerPoint p) => p.value).reduce(math.min), max = points.isEmpty ? 1 : points.map((BiomarkerPoint p) => p.value).reduce(math.max);
  final double min, max;
  double normalize(double value) => max == min ? 50 : ((value - min) / (max - min)) * 100;
}