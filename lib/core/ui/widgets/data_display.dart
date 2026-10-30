import 'package:flutter/material.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';

class M24ListRow extends StatelessWidget {
  const M24ListRow({super.key, required this.icon, required this.title, required this.subtitle, this.iconVariant = M24IconTileVariant.info, this.status, this.onTap});
  final IconData icon;
  final String title, subtitle;
  final M24IconTileVariant iconVariant;
  final M24StatusPill? status;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ConstrainedBox(constraints: const BoxConstraints(minHeight: 72), child: InkWell(onTap: onTap, focusColor: context.m24.colors.focusRing, hoverColor: context.m24.colors.surfaceAlt, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: <Widget>[M24IconTile(icon: icon, variant: iconVariant), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[Tooltip(message: title, child: Text(title, style: context.m24.text.title, maxLines: 2, overflow: TextOverflow.ellipsis)), Text(subtitle, style: context.m24.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)])), if (status != null) ...<Widget>[const SizedBox(width: 8), status!], const SizedBox(width: 8), Icon(M24Icons.chevronRight, size: 20, color: context.m24.colors.inkMuted)]))));
}

class M24StatTile extends StatelessWidget {
  const M24StatTile({super.key, required this.icon, required this.label, required this.value, this.variant = M24IconTileVariant.primary});
  final IconData icon;
  final String label, value;
  final M24IconTileVariant variant;
  @override
  Widget build(BuildContext context) => M24Card(child: Row(children: <Widget>[M24IconTile(icon: icon, variant: variant), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(label, style: context.m24.text.bodySmall), Text(value, style: context.m24.text.stat)]))]));
}

enum M24DateTileVariant { primary, warning, neutral }

class M24DateTile extends StatelessWidget {
  const M24DateTile({super.key, required this.day, required this.month, this.variant = M24DateTileVariant.primary});
  final String day, month;
  final M24DateTileVariant variant;
  @override
  Widget build(BuildContext context) {
    final M24Colors c = context.m24.colors;
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final (Color, Color) palette = switch (variant) { M24DateTileVariant.primary => (c.primarySoft, c.ink), M24DateTileVariant.warning => (c.warningTint, c.warningInk), M24DateTileVariant.neutral => (c.neutralTint, c.neutral) };
    return Container(width: desktop ? 64 : 72, height: desktop ? 64 : 72, decoration: BoxDecoration(color: palette.$1, borderRadius: BorderRadius.circular(14)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[Text(day, style: context.m24.text.stat.copyWith(color: palette.$2)), Text(month.toUpperCase(), style: context.m24.text.label.copyWith(fontWeight: FontWeight.w600, color: palette.$2))]));
  }
}

class M24Table extends StatefulWidget {
  const M24Table({super.key, required this.columns, required this.rows, this.selectedRow, this.onRowTap, this.fixedColumnWidth = 112});
  final List<String> columns;
  final List<List<Widget>> rows;
  final int? selectedRow;
  final ValueChanged<int>? onRowTap;
  final double fixedColumnWidth;
  @override
  State<M24Table> createState() => _M24TableState();
}

class _M24TableState extends State<M24Table> {
  int? hovered;
  @override
  Widget build(BuildContext context) {
    final List<TableRow> rows = widget.rows.asMap().entries.map((entry) {
      final Color color = widget.selectedRow == entry.key ? context.m24.colors.primaryTint : hovered == entry.key ? context.m24.colors.surfaceAlt : context.m24.colors.surface;
      return TableRow(decoration: BoxDecoration(color: color, border: Border(bottom: BorderSide(color: context.m24.colors.divider))), children: entry.value.map((cell) {
        return MouseRegion(onEnter: (_) => setState(() => hovered = entry.key), onExit: (_) => setState(() => hovered = null), child: InkWell(onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(entry.key), child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Padding(padding: const EdgeInsets.all(12), child: DefaultTextStyle(style: context.m24.text.bodySmall.copyWith(color: context.m24.colors.ink), child: cell)))));
      }).toList());
    }).toList();
    final Map<int, TableColumnWidth> widths = <int, TableColumnWidth>{for (int i = 0; i < widget.columns.length; i++) i: i == 0 ? const FlexColumnWidth() : FixedColumnWidth(widget.fixedColumnWidth)};
    return ClipRRect(borderRadius: BorderRadius.circular(14), child: Table(columnWidths: widths, children: <TableRow>[
      TableRow(decoration: BoxDecoration(color: context.m24.colors.surfaceAlt), children: widget.columns.map((column) => Padding(padding: const EdgeInsets.all(12), child: Text(column, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.m24.text.label.copyWith(color: context.m24.colors.inkSecondary)))).toList()),
      ...rows,
    ]));
  }
}

class M24EmptyState extends StatelessWidget {
  const M24EmptyState({super.key, required this.icon, required this.title, required this.message, required this.actionLabel, this.onAction});
  final IconData icon;
  final String title, message, actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[Container(width: 64, height: 64, decoration: BoxDecoration(color: context.m24.colors.surfaceAlt, shape: BoxShape.circle), child: Icon(icon, size: 40, color: context.m24.colors.inkMuted)), const SizedBox(height: 16), Text(title, style: context.m24.text.h3, textAlign: TextAlign.center), const SizedBox(height: 8), Text(message, style: context.m24.text.body.copyWith(color: context.m24.colors.inkSecondary), textAlign: TextAlign.center), const SizedBox(height: 20), M24Button(label: actionLabel, onPressed: onAction)]));
}