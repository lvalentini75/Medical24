import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/features/health/body/data/body_map_data.dart';
import 'package:medical24/features/health/body/data/body_models.dart';
import 'package:medical24/features/health/body/widgets/body_widgets.dart';

/// Interactive 200x440 body map drawn from board-provided paths.
class M24BodyMap extends StatefulWidget {
  const M24BodyMap({super.key, required this.organs, this.selectedId, required this.onTap, required this.onDoubleTap, this.onEmptyTap, this.onHover});
  final List<OrganOverview> organs;
  final String? selectedId;
  final ValueChanged<OrganOverview> onTap, onDoubleTap;
  final VoidCallback? onEmptyTap;
  final ValueChanged<String?>? onHover;
  @override
  State<M24BodyMap> createState() => _M24BodyMapState();
}

class _M24BodyMapState extends State<M24BodyMap> with TickerProviderStateMixin {
  final GlobalKey<TooltipState> tooltipKey = GlobalKey<TooltipState>();
  late final AnimationController colorAnimation = AnimationController(vsync: this, duration: const Duration(milliseconds: 300), value: 1);
  late final AnimationController pulseAnimation = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800), value: 1);
  Map<String, double?> previousScores = const <String, double?>{};
  String tooltipMessage = '';
  String? hoveredId;
  Offset? pointer;

  @override
  void didUpdateWidget(covariant M24BodyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Map<String, double?> oldScores = <String, double?>{for (final OrganOverview organ in oldWidget.organs) organ.id: organ.stressScore};
    final Map<String, double?> newScores = <String, double?>{for (final OrganOverview organ in widget.organs) organ.id: organ.stressScore};
    if (_different(oldScores, newScores)) { previousScores = oldScores; colorAnimation.forward(from: 0); }
    if (widget.selectedId != oldWidget.selectedId && widget.selectedId != null) {
      if (MediaQuery.maybeOf(context)?.disableAnimations != true) pulseAnimation.forward(from: 0);
    }
  }

  bool _different(Map<String, double?> a, Map<String, double?> b) => a.length != b.length || b.entries.any((MapEntry<String, double?> entry) => a[entry.key] != entry.value);
  String get sex => widget.organs.any((OrganOverview organ) => organ.sex == 'female') ? 'female' : widget.organs.any((OrganOverview organ) => organ.sex == 'male') ? 'male' : 'neutral';

  @override
  Widget build(BuildContext context) => FutureBuilder<BodyMapData>(future: BodyMapData.load(), builder: (BuildContext context, AsyncSnapshot<BodyMapData> snapshot) {
    if (!snapshot.hasData) return const AspectRatio(aspectRatio: 200 / 440, child: Center(child: CircularProgressIndicator()));
    final BodyMapData data = snapshot.requireData;
    final Map<String, OrganOverview> organs = <String, OrganOverview>{for (final OrganOverview organ in widget.organs) organ.id: organ};
    return AspectRatio(aspectRatio: 200 / 440, child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      final Size size = Size(constraints.maxWidth, constraints.maxHeight);
      String? hitId(Offset point) => M24BodyMapPainter(data: data, organs: organs, sex: sex, selectedId: widget.selectedId, hoveredId: hoveredId, primary: context.m24.colors.primary, progress: colorAnimation.value, pulse: 1, previousScores: previousScores).hitTestArea(point, size);
      OrganOverview? hit(Offset point) { final String? id = hitId(point); return id == null ? null : organs[id]; }
      void updateHover(Offset point) { final String? value = hitId(point); if (value == hoveredId) return; setState(() => hoveredId = value); widget.onHover?.call(value); }
      return MouseRegion(
        cursor: hoveredId == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onHover: (PointerHoverEvent event) => updateHover(event.localPosition),
        onExit: (_) { if (hoveredId != null) setState(() => hoveredId = null); widget.onHover?.call(null); },
        child: Tooltip(key: tooltipKey, message: tooltipMessage, triggerMode: TooltipTriggerMode.manual, child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails details) => pointer = details.localPosition,
          onTap: () { final OrganOverview? organ = pointer == null ? null : hit(pointer!); organ == null ? widget.onEmptyTap?.call() : widget.onTap(organ); },
          onDoubleTapDown: (TapDownDetails details) => pointer = details.localPosition,
          onDoubleTap: () { final OrganOverview? organ = pointer == null ? null : hit(pointer!); if (organ != null) widget.onDoubleTap(organ); },
          onLongPressStart: (LongPressStartDetails details) { final OrganOverview? organ = hit(details.localPosition); if (organ == null) return; setState(() => tooltipMessage = '${organ.name(Localizations.localeOf(context).languageCode)}, ${organStateLabel(context, organ.state)}'); WidgetsBinding.instance.addPostFrameCallback((_) => tooltipKey.currentState?.ensureTooltipVisible()); },
          child: AnimatedBuilder(animation: Listenable.merge(<Listenable>[colorAnimation, pulseAnimation]), builder: (_, __) {
            final bool animate = !MediaQuery.of(context).disableAnimations && pulseAnimation.isAnimating;
            final double pulse = animate ? 1 + .06 * math.sin(2 * math.pi * pulseAnimation.value).abs() : 1;
            return CustomPaint(painter: M24BodyMapPainter(data: data, organs: organs, sex: sex, selectedId: widget.selectedId, hoveredId: hoveredId, primary: context.m24.colors.primary, progress: colorAnimation.value, pulse: pulse, previousScores: previousScores, stateLabels: <String, String>{for (final OrganOverview organ in widget.organs) organ.id: '${organ.name(Localizations.localeOf(context).languageCode)}, ${organStateLabel(context, organ.state)}'}, onSemanticTap: (String id) { final OrganOverview? organ = organs[id]; if (organ != null) widget.onTap(organ); }), size: Size.infinite);
          }),
        )),
      );
    }));
  });

  @override
  void dispose() { colorAnimation.dispose(); pulseAnimation.dispose(); super.dispose(); }
}

class M24BodyMapPainter extends CustomPainter {
  M24BodyMapPainter({required this.data, required this.organs, required this.sex, required this.selectedId, this.hoveredId, required this.primary, required this.progress, required this.pulse, required this.previousScores, this.stateLabels = const <String, String>{}, this.onSemanticTap});
  final BodyMapData data;
  final Map<String, OrganOverview> organs;
  final String sex;
  final String? selectedId, hoveredId;
  final Color primary;
  final double progress, pulse;
  final Map<String, double?> previousScores;
  final Map<String, String> stateLabels;
  final ValueChanged<String>? onSemanticTap;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 200;
    final ui.Image body = data.images[sex] ?? data.images['neutral']!;
    canvas.drawImageRect(body, Rect.fromLTWH(0, 0, body.width.toDouble(), body.height.toDouble()), Offset.zero & size, Paint()..filterQuality = FilterQuality.high);
    canvas.save();
    canvas.scale(scale);
    final List<BodyAreaPath> visible = data.areas.where((BodyAreaPath area) => organs.containsKey(area.id)).toList(growable: false);
    for (final BodyAreaPath area in visible) _withAreaTransform(canvas, area, () => _paintBack(canvas, area, scale));
    for (final BodyAreaPath area in visible) _withAreaTransform(canvas, area, () => _paintArea(canvas, area, scale));
    if (selectedId != null) {
      final BodyAreaPath? selected = visible.where((BodyAreaPath area) => area.id == selectedId).firstOrNull;
      if (selected != null) _withAreaTransform(canvas, selected, () => _paintSelection(canvas, selected, scale));
    }
    canvas.restore();
  }

  void _withAreaTransform(Canvas canvas, BodyAreaPath area, VoidCallback paint) {
    canvas.save();
    if (selectedId == area.id && pulse != 1) { canvas.translate(area.anchor.dx, area.anchor.dy); canvas.scale(pulse); canvas.translate(-area.anchor.dx, -area.anchor.dy); }
    paint();
    canvas.restore();
  }

  Color _areaColor(BodyAreaPath area) {
    final OrganOverview organ = organs[area.id]!;
    final Color target = data.colorFor(organ.stressScore);
    final Color start = data.colorFor(previousScores.containsKey(area.id) ? previousScores[area.id] : organ.stressScore);
    Color color = Color.lerp(start, target, progress)!;
    if (hoveredId == area.id) color = Color.lerp(color, Colors.white, .14)!;
    final double opacity = selectedId == null || selectedId == area.id ? 1 : .7;
    return color.withValues(alpha: color.a * opacity);
  }

  void _paintBack(Canvas canvas, BodyAreaPath area, double scale) {
    final OrganOverview organ = organs[area.id]!;
    final bool missing = organ.stressScore == null;
    final Color color = missing ? data.missingStroke : _areaColor(area);
    for (final Path path in area.back) _layeredStroke(canvas, path, color, area.backWidth, missing);
  }

  void _paintArea(Canvas canvas, BodyAreaPath area, double scale) {
    final OrganOverview organ = organs[area.id]!;
    final bool missing = organ.stressScore == null;
    final Color color = _areaColor(area);
    final Color outline = missing ? data.missingStroke : _darken(color);
    for (final Path path in area.paths) {
      canvas.drawPath(path, Paint()..color = missing ? data.missingFill : color..style = PaintingStyle.fill);
      _stroke(canvas, path, outline, 1 / scale, missing);
    }
    for (final BodyExtraPath extra in area.extra) {
      canvas.drawPath(extra.path, Paint()..color = missing ? data.missingFill : extra.fill.withValues(alpha: color.a)..style = PaintingStyle.fill);
      _stroke(canvas, extra.path, outline, 1 / scale, missing);
    }
    for (final Path path in area.strokes) _layeredStroke(canvas, path, missing ? data.missingStroke : color, area.strokeWidth, missing);
    final Color detail = missing ? data.missingStroke : area.breast ? color : Colors.white.withValues(alpha: data.detailWhiteOpacity * color.a);
    for (final Path path in area.detail) _stroke(canvas, path, detail, 1, missing);
  }

  void _layeredStroke(Canvas canvas, Path path, Color color, double width, bool missing) {
    if (!missing && width > 4) {
      _stroke(canvas, path, _darken(color), width, false);
      _stroke(canvas, path, color, width * data.outlineDarken, false);
    } else {
      _stroke(canvas, path, color, width, missing);
    }
  }

  void _paintSelection(Canvas canvas, BodyAreaPath area, double scale) {
    final List<Path> paths = <Path>[...area.back, ...area.paths, ...area.extra.map((BodyExtraPath value) => value.path), ...area.strokes];
    for (final Path path in paths) canvas.drawPath(path, Paint()..color = primary.withValues(alpha: .25)..style = PaintingStyle.stroke..strokeWidth = 7 / scale..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    for (final Path path in paths) _stroke(canvas, path, primary, 2 / scale, false);
  }

  void _stroke(Canvas canvas, Path path, Color color, double width, bool dashed) {
    final Path rendered = dashed ? dashPath(path, dashArray: CircularIntervalList<double>(<double>[2, 1.5])) : path;
    canvas.drawPath(rendered, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = width..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  Color _darken(Color color) => Color.fromARGB((color.a * 255).round(), (color.r * 255 * data.outlineDarken).round(), (color.g * 255 * data.outlineDarken).round(), (color.b * 255 * data.outlineDarken).round());

  String? hitTestArea(Offset position, Size size) {
    final double scale = size.width / 200;
    final Offset point = position / scale;
    final List<BodyAreaPath> hits = data.areas.where((BodyAreaPath area) {
      if (!organs.containsKey(area.id)) return false;
      if (area.paths.any((Path path) => path.contains(point))) return true;
      return <Path>[...area.strokes, ...area.back].any((Path path) => _near(path, point, 8 / scale));
    }).toList(growable: false);
    if (hits.isEmpty) return null;
    hits.sort((BodyAreaPath a, BodyAreaPath b) => (a.hitBounds.width * a.hitBounds.height).compareTo(b.hitBounds.width * b.hitBounds.height));
    return hits.first.id;
  }

  bool _near(Path path, Offset point, double tolerance) {
    for (final ui.PathMetric metric in path.computeMetrics()) for (double d = 0; d <= metric.length; d += math.max(1, tolerance / 2)) if (((metric.getTangentForOffset(d)?.position ?? Offset.infinite) - point).distance <= tolerance) return true;
    return false;
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) => <CustomPainterSemantics>[for (final BodyAreaPath area in data.areas) if (organs.containsKey(area.id)) CustomPainterSemantics(rect: Rect.fromCenter(center: Offset(area.anchor.dx * size.width / 200, area.anchor.dy * size.height / 440), width: 44, height: 44), properties: SemanticsProperties(label: stateLabels[area.id], button: true, onTap: onSemanticTap == null ? null : () => onSemanticTap!(area.id)))];
  @override
  bool shouldRepaint(covariant M24BodyMapPainter oldDelegate) => oldDelegate.organs != organs || oldDelegate.selectedId != selectedId || oldDelegate.hoveredId != hoveredId || oldDelegate.progress != progress || oldDelegate.pulse != pulse || oldDelegate.sex != sex || oldDelegate.primary != primary;
  @override
  bool shouldRebuildSemantics(covariant M24BodyMapPainter oldDelegate) => oldDelegate.stateLabels != stateLabels;
}

/// Wide layout with synchronized labels and callout lines.
class M24ExplodedBodyMap extends StatefulWidget {
  const M24ExplodedBodyMap({super.key, required this.organs, this.selectedId, required this.onTap, required this.onDoubleTap, this.onEmptyTap});
  final List<OrganOverview> organs;
  final String? selectedId;
  final ValueChanged<OrganOverview> onTap, onDoubleTap;
  final VoidCallback? onEmptyTap;
  @override
  State<M24ExplodedBodyMap> createState() => _M24ExplodedBodyMapState();
}

class _M24ExplodedBodyMapState extends State<M24ExplodedBodyMap> {
  String? hoveredId;
  @override
  Widget build(BuildContext context) => FutureBuilder<BodyMapData>(future: BodyMapData.load(), builder: (BuildContext context, AsyncSnapshot<BodyMapData> snapshot) {
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    final BodyMapData data = snapshot.requireData;
    final Map<String, BodyAreaPath> paths = <String, BodyAreaPath>{for (final BodyAreaPath area in data.areas) area.id: area};
    final List<OrganOverview> left = widget.organs.where((OrganOverview organ) => paths[organ.id]?.side == 'L').toList()..sort((a, b) => paths[a.id]!.anchor.dy.compareTo(paths[b.id]!.anchor.dy));
    final List<OrganOverview> right = widget.organs.where((OrganOverview organ) => paths[organ.id]?.side == 'R').toList()..sort((a, b) => paths[a.id]!.anchor.dy.compareTo(paths[b.id]!.anchor.dy));
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      final double labelWidth = 150;
      final double mapWidth = constraints.maxWidth - labelWidth * 2;
      if (mapWidth < 200) return M24BodyMap(organs: widget.organs, selectedId: widget.selectedId, onTap: widget.onTap, onDoubleTap: widget.onDoubleTap, onEmptyTap: widget.onEmptyTap, onHover: _hover);
      final double height = constraints.hasBoundedHeight ? constraints.maxHeight : 520;
      return SizedBox(height: height, child: CustomPaint(painter: BodyCalloutPainter(left: left, right: right, paths: paths, color: context.m24.colors.border, primary: context.m24.colors.primary, selectedId: widget.selectedId, hoveredId: hoveredId, labelWidth: labelWidth, mapWidth: mapWidth), child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        SizedBox(width: labelWidth, child: BodyAreaLabels(organs: left, selectedId: widget.selectedId, hoveredId: hoveredId, onTap: widget.onTap, onHover: _hover, alignRight: true)),
        SizedBox(width: mapWidth, child: Center(child: M24BodyMap(organs: widget.organs, selectedId: widget.selectedId, onTap: widget.onTap, onDoubleTap: widget.onDoubleTap, onEmptyTap: widget.onEmptyTap, onHover: _hover))),
        SizedBox(width: labelWidth, child: BodyAreaLabels(organs: right, selectedId: widget.selectedId, hoveredId: hoveredId, onTap: widget.onTap, onHover: _hover))
      ])));
    });
  });
  void _hover(String? value) { if (hoveredId != value) setState(() => hoveredId = value); }
}

class BodyAreaLabels extends StatelessWidget {
  const BodyAreaLabels({super.key, required this.organs, required this.selectedId, required this.hoveredId, required this.onTap, required this.onHover, this.alignRight = false});
  final List<OrganOverview> organs;
  final String? selectedId, hoveredId;
  final ValueChanged<OrganOverview> onTap;
  final ValueChanged<String?> onHover;
  final bool alignRight;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: <Widget>[
      for (final OrganOverview organ in organs)
        Opacity(
          opacity: selectedId == null || selectedId == organ.id ? 1 : .7,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => onHover(organ.id),
            onExit: (_) => onHover(null),
            child: InkWell(
              onTap: () => onTap(organ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                key: ValueKey<String>('exploded-label-${organ.id}'),
                constraints: const BoxConstraints(minHeight: 44),
                padding: EdgeInsets.fromLTRB(organ.id == selectedId ? 8 : 11, 6, 8, 6),
                decoration: BoxDecoration(color: organ.id == selectedId ? context.m24.colors.primaryTint : organ.id == hoveredId ? context.m24.colors.surfaceAlt : Colors.transparent, border: organ.id == selectedId ? Border(left: BorderSide(color: context.m24.colors.primary, width: 3)) : null, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[Text(organ.name(Localizations.localeOf(context).languageCode), textAlign: alignRight ? TextAlign.right : TextAlign.left, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.m24.text.label.copyWith(fontWeight: FontWeight.w600, color: organ.id == selectedId ? context.m24.colors.primary : null)), const SizedBox(height: 4), OrganStatusPill(state: organ.state)]),
              ),
            ),
          ),
        )
    ],
  );
}

class BodyCalloutPainter extends CustomPainter {
  const BodyCalloutPainter({required this.left, required this.right, required this.paths, required this.color, required this.primary, required this.selectedId, required this.hoveredId, required this.labelWidth, required this.mapWidth});
  final List<OrganOverview> left, right;
  final Map<String, BodyAreaPath> paths;
  final Color color, primary;
  final String? selectedId, hoveredId;
  final double labelWidth, mapWidth;
  @override
  void paint(Canvas canvas, Size size) {
    final double mapLeft = labelWidth, scale = math.min(mapWidth / 200, size.height / 440), bodyHeight = 440 * scale, bodyTop = (size.height - bodyHeight) / 2;
    void side(List<OrganOverview> values, bool isLeft) {
      for (int i = 0; i < values.length; i++) {
        final OrganOverview organ = values[i];
        final Offset anchor = paths[organ.id]!.anchor;
        final double labelY = size.height * (i + 1) / (values.length + 1);
        final Offset start = Offset(isLeft ? labelWidth - 2 : mapLeft + mapWidth + 2, labelY);
        final Offset end = Offset(mapLeft + (mapWidth - 200 * scale) / 2 + anchor.dx * scale, bodyTop + anchor.dy * scale);
        final bool selected = organ.id == selectedId;
        final Paint paint = Paint()..color = selected ? primary : color..strokeWidth = selected ? 2 : 1..style = PaintingStyle.stroke;
        canvas.drawLine(start, end, paint);
        canvas.drawCircle(end, selected ? 5 : organ.id == hoveredId ? 4 : 3, Paint()..color = selected || organ.id == hoveredId ? primary : color);
      }
    }
    side(left, true); side(right, false);
  }
  @override
  bool shouldRepaint(covariant BodyCalloutPainter oldDelegate) => oldDelegate.left != left || oldDelegate.right != right || oldDelegate.color != color || oldDelegate.primary != primary || oldDelegate.selectedId != selectedId || oldDelegate.hoveredId != hoveredId || oldDelegate.mapWidth != mapWidth;
}