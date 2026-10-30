import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

class BodyExtraPath {
  const BodyExtraPath({required this.path, required this.fill});
  final ui.Path path;
  final ui.Color fill;
}

class BodyAreaPath {
  const BodyAreaPath({required this.id, required this.sex, required this.side, required this.anchor, required this.back, required this.backWidth, required this.paths, required this.extra, required this.strokes, required this.strokeWidth, required this.detail, required this.breast});
  final String id, sex, side;
  final ui.Offset anchor;
  final List<ui.Path> back, paths, strokes, detail;
  final List<BodyExtraPath> extra;
  final double backWidth, strokeWidth;
  final bool breast;

  ui.Rect get hitBounds {
    final List<ui.Path> values = <ui.Path>[...paths, ...strokes, ...back];
    if (values.isEmpty) return ui.Rect.fromCenter(center: anchor, width: 1, height: 1);
    return values.map((ui.Path path) => path.getBounds()).reduce((ui.Rect a, ui.Rect b) => a.expandToInclude(b));
  }
}

class BodyMapData {
  const BodyMapData({required this.areas, required this.scale, required this.missingFill, required this.missingStroke, required this.outlineDarken, required this.detailWhiteOpacity, required this.images});
  final List<BodyAreaPath> areas;
  final List<(double, ui.Color)> scale;
  final ui.Color missingFill, missingStroke;
  final double outlineDarken, detailWhiteOpacity;
  final Map<String, ui.Image> images;

  static Future<BodyMapData>? _cached;
  static Future<BodyMapData> load() => _cached ??= _load();

  static Future<BodyMapData> _load() async {
    final Map<String, dynamic> json = jsonDecode(await rootBundle.loadString('doc/body/organ_paths.json')) as Map<String, dynamic>;
    final Map<String, dynamic> colors = Map<String, dynamic>.from(json['colors'] as Map);
    final Map<String, dynamic> bodies = Map<String, dynamic>.from(json['bodies'] as Map);
    final Map<String, ui.Image> images = <String, ui.Image>{};
    for (final MapEntry<String, dynamic> entry in bodies.entries) images[entry.key] = await _image(entry.value.toString());
    return BodyMapData(
      areas: (json['areas'] as List).whereType<Map>().map((Map raw) {
        final Map<String, dynamic> area = Map<String, dynamic>.from(raw);
        List<ui.Path> paths(String key) => (area[key] as List? ?? const <dynamic>[]).map((dynamic value) => parseSvgPathData(value.toString())).toList(growable: false);
        final List<dynamic> anchor = area['anchor_px'] as List;
        final List<BodyExtraPath> extra = (area['extra'] as List? ?? const <dynamic>[]).whereType<Map>().map((Map rawExtra) { final Map<String, dynamic> value = Map<String, dynamic>.from(rawExtra); return BodyExtraPath(path: parseSvgPathData(value['d'].toString()), fill: _color(value['fill'].toString())); }).toList(growable: false);
        return BodyAreaPath(id: area['id'].toString(), sex: area['sex'].toString(), side: area['side'].toString(), anchor: ui.Offset((anchor[0] as num).toDouble(), (anchor[1] as num).toDouble()), back: paths('back'), backWidth: (area['backWidth'] as num).toDouble(), paths: paths('paths'), extra: extra, strokes: paths('strokes'), strokeWidth: (area['sw'] as num).toDouble(), detail: paths('detail'), breast: area['breast'] == true);
      }).toList(growable: false),
      scale: (colors['color_scale'] as List).whereType<List>().map((List stop) => ((stop[0] as num).toDouble(), _color(stop[1].toString()))).toList(growable: false),
      missingFill: _color(colors['missing_fill'].toString()), missingStroke: _color(colors['missing_stroke'].toString()), outlineDarken: (colors['outline_darken'] as num).toDouble(), detailWhiteOpacity: (colors['detail_white_opacity'] as num).toDouble(), images: images,
    );
  }

  ui.Color colorFor(double? value) {
    if (value == null) return missingFill;
    final double normalized = value.clamp(0, 1).toDouble();
    for (int i = 1; i < scale.length; i++) {
      if (normalized <= scale[i].$1) {
        final double t = (normalized - scale[i - 1].$1) / (scale[i].$1 - scale[i - 1].$1);
        return ui.Color.lerp(scale[i - 1].$2, scale[i].$2, t)!;
      }
    }
    return scale.last.$2;
  }

  static ui.Color _color(String value) {
    final String digits = value.substring(1);
    final int parsed = int.parse(digits, radix: 16);
    return ui.Color(digits.length == 8 ? parsed : parsed | 0xFF000000);
  }

  static Future<ui.Image> _image(String asset) async { final ui.Codec codec = await ui.instantiateImageCodec((await rootBundle.load(asset)).buffer.asUint8List()); return (await codec.getNextFrame()).image; }
}