import 'package:flutter/material.dart';
import 'package:medical24/core/ui/tokens.dart';

enum M24CardTint { none, primary, info, warning }

class M24Card extends StatefulWidget {
  const M24Card({super.key, required this.child, this.tint = M24CardTint.none, this.selectable = false, this.selected = false, this.onTap, this.padding});
  final Widget child;
  final M24CardTint tint;
  final bool selectable, selected;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  @override
  State<M24Card> createState() => _M24CardState();
}

class _M24CardState extends State<M24Card> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final M24Colors c = context.m24.colors;
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final Color base = switch (widget.tint) { M24CardTint.primary => c.primarySoft, M24CardTint.info => c.infoTint, M24CardTint.warning => c.warningTint, _ => c.surface };
    final Color color = widget.selected ? c.primaryTint : hovered && widget.selectable ? c.surfaceAlt : base;
    return MouseRegion(onEnter: (_) => setState(() => hovered = true), onExit: (_) => setState(() => hovered = false), child: Material(color: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(desktop ? 14 : 16), side: BorderSide(color: c.border)), child: InkWell(onTap: widget.onTap, focusColor: c.focusRing, borderRadius: BorderRadius.circular(desktop ? 14 : 16), child: Padding(padding: widget.padding ?? EdgeInsets.all(desktop ? 20 : 16), child: widget.child))));
  }
}

enum M24IconTileVariant { info, success, warning, danger, neutral, primary }

class M24IconTile extends StatelessWidget {
  const M24IconTile({super.key, required this.icon, this.variant = M24IconTileVariant.primary, this.small = false});
  final IconData icon;
  final M24IconTileVariant variant;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final M24Colors c = context.m24.colors;
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final (Color, Color) palette = switch (variant) { M24IconTileVariant.info => (c.infoTint, c.info), M24IconTileVariant.success => (c.successTint, c.success), M24IconTileVariant.warning => (c.warningTint, c.warning), M24IconTileVariant.danger => (c.dangerTint, c.danger), M24IconTileVariant.neutral => (c.neutralTint, c.neutral), M24IconTileVariant.primary => (c.primaryTint, c.primary) };
    final double side = small ? 36 : desktop ? 44 : 48;
    return Container(width: side, height: side, decoration: BoxDecoration(color: palette.$1, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Icon(icon, size: small ? 20 : desktop ? 24 : 28, color: palette.$2));
  }
}

enum M24StatusPillVariant { info, success, warning, danger, neutral }

class M24StatusPill extends StatelessWidget {
  const M24StatusPill({super.key, required this.label, required this.variant, this.strikethrough = false});
  final String label;
  final M24StatusPillVariant variant;
  final bool strikethrough;
  @override
  Widget build(BuildContext context) {
    final M24Colors c = context.m24.colors;
    final (Color, Color) palette = switch (variant) { M24StatusPillVariant.info => (c.infoTint, c.info), M24StatusPillVariant.success => (c.successTint, c.success), M24StatusPillVariant.warning => (c.warningTint, c.warning), M24StatusPillVariant.danger => (c.dangerTint, c.danger), M24StatusPillVariant.neutral => (c.neutralTint, c.neutral) };
    return Container(height: 28, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: palette.$1, borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[Container(width: 8, height: 8, decoration: BoxDecoration(color: palette.$2, shape: BoxShape.circle)), const SizedBox(width: 7), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.m24.text.label.copyWith(color: palette.$2, decoration: strikethrough ? TextDecoration.lineThrough : null)))]));
  }
}