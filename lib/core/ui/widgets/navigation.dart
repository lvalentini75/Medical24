import 'package:flutter/material.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';

class M24Breadcrumb extends StatelessWidget {
  const M24Breadcrumb({super.key, required this.segments});
  final List<String> segments;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 1200) return const SizedBox.shrink();
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[for (int i = 0; i < segments.length; i++) ...<Widget>[Text(segments[i], style: context.m24.text.label.copyWith(color: i == segments.length - 1 ? context.m24.colors.ink : context.m24.colors.inkSecondary)), if (i < segments.length - 1) Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(M24Icons.chevronRight, size: 16, color: context.m24.colors.inkMuted))]]);
  }
}

class M24SheetItem {
  const M24SheetItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class M24Sheet extends StatelessWidget {
  const M24Sheet({super.key, required this.items});
  final List<M24SheetItem> items;
  @override
  Widget build(BuildContext context) => Material(color: context.m24.colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[Container(width: 36, height: 4, decoration: BoxDecoration(color: context.m24.colors.border, borderRadius: BorderRadius.circular(999))), const SizedBox(height: 10), ...items.map((item) => InkWell(onTap: item.onTap, hoverColor: context.m24.colors.surfaceAlt, focusColor: context.m24.colors.focusRing, borderRadius: BorderRadius.circular(12), child: SizedBox(height: 56, child: Row(children: <Widget>[Container(width: 36, height: 36, decoration: BoxDecoration(color: context.m24.colors.primaryTint, borderRadius: BorderRadius.circular(12)), child: Icon(item.icon, size: 20, color: context.m24.colors.primary)), const SizedBox(width: 12), Text(item.label, style: context.m24.text.title)]))))])));
}