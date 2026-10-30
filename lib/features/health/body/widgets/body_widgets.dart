import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/features/health/body/data/body_models.dart';
import 'package:medical24/features/health/body/data/body_map_data.dart';
import 'package:medical24/features/health/widgets/biomarker_list.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

M24StatusPillVariant organPillVariant(OrganHealthState? state) => switch (state) { OrganHealthState.ok => M24StatusPillVariant.success, OrganHealthState.monitor => M24StatusPillVariant.warning, OrganHealthState.attention => M24StatusPillVariant.danger, _ => M24StatusPillVariant.neutral };
M24IconTileVariant organTileVariant(OrganHealthState? state) => switch (state) { OrganHealthState.ok => M24IconTileVariant.success, OrganHealthState.monitor => M24IconTileVariant.warning, OrganHealthState.attention => M24IconTileVariant.danger, _ => M24IconTileVariant.neutral };
String organStateLabel(BuildContext context, OrganHealthState? state) => switch (state) { OrganHealthState.ok => context.l10n.bodyState_ok, OrganHealthState.monitor => context.l10n.bodyState_monitor, OrganHealthState.attention => context.l10n.bodyState_attention, _ => context.l10n.bodyState_missing };
String organConfidenceLabel(BuildContext context, double confidence) => confidence >= .8 ? context.l10n.bodyConfidenceComplete : confidence >= .3 ? context.l10n.bodyConfidencePartial : confidence > 0 ? context.l10n.bodyConfidenceIncomplete : context.l10n.bodyConfidenceMissing;
IconData organIcon(String value) => switch (value) { 'heart-pulse' => LucideIcons.heartPulse, 'wind' => LucideIcons.wind, 'flask-conical' => LucideIcons.flaskConical, 'filter' => LucideIcons.filter, 'flame' => LucideIcons.flame, 'utensils-crossed' => LucideIcons.utensilsCrossed, 'droplet' => LucideIcons.droplet, 'shield-check' => LucideIcons.shieldCheck, 'brain' => LucideIcons.brain, 'bone' => LucideIcons.bone, _ => LucideIcons.circleDot };

class OrganStatusPill extends StatelessWidget {
  const OrganStatusPill({super.key, required this.state});
  final OrganHealthState? state;
  @override
  Widget build(BuildContext context) => M24StatusPill(label: organStateLabel(context, state), variant: organPillVariant(state));
}

class OrganStressBar extends StatelessWidget {
  const OrganStressBar({super.key, required this.value, this.compact = false});
  final double? value;
  final bool compact;
  @override
  Widget build(BuildContext context) => FutureBuilder<BodyMapData>(future: BodyMapData.load(), builder: (BuildContext context, AsyncSnapshot<BodyMapData> snapshot) {
    final Color color = snapshot.data?.colorFor(value) ?? context.m24.colors.neutralTint;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Row(children: <Widget>[Expanded(child: Text(context.l10n.bodyDeviationLabel, style: compact ? context.m24.text.caption : context.m24.text.label)), Text(value == null ? context.l10n.bodyNotAvailable : value!.toStringAsFixed(2), style: context.m24.text.label)]),
      const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(999), child: SizedBox(height: compact ? 6 : 8, child: Stack(children: <Widget>[Positioned.fill(child: ColoredBox(color: context.m24.colors.neutralTint)), if (value != null) FractionallySizedBox(widthFactor: value!.clamp(0, 1), child: ColoredBox(color: color))])))
    ]);
  });
}

class BodyGradientLegend extends StatelessWidget {
  const BodyGradientLegend({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<BodyMapData>(future: BodyMapData.load(), builder: (BuildContext context, AsyncSnapshot<BodyMapData> snapshot) {
    final BodyMapData? data = snapshot.data;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Row(children: <Widget>[Expanded(child: Text(context.l10n.bodyLegendNormal, style: context.m24.text.caption)), Text(context.l10n.bodyLegendAttention, style: context.m24.text.caption)]),
      const SizedBox(height: 4), Container(height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), gradient: data == null ? null : LinearGradient(colors: data.scale.map(((double, Color) stop) => stop.$2).toList(growable: false), stops: data.scale.map(((double, Color) stop) => stop.$1).toList(growable: false)), color: data == null ? context.m24.colors.neutralTint : null)),
      const SizedBox(height: 8), Row(children: <Widget>[CustomPaint(size: const Size(14, 14), painter: MissingLegendPainter(fill: data?.missingFill ?? context.m24.colors.neutralTint, stroke: data?.missingStroke ?? context.m24.colors.neutral)), const SizedBox(width: 6), Text(context.l10n.bodyState_missing, style: context.m24.text.caption)])
    ]);
  });
}

class MissingLegendPainter extends CustomPainter {
  const MissingLegendPainter({required this.fill, required this.stroke});
  final Color fill, stroke;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    final Paint paint = Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = 1;
    const double dash = 2, gap = 1.5;
    for (double x = 0; x < size.width; x += dash + gap) { canvas.drawLine(Offset(x, 0), Offset((x + dash).clamp(0, size.width), 0), paint); canvas.drawLine(Offset(x, size.height), Offset((x + dash).clamp(0, size.width), size.height), paint); }
    for (double y = 0; y < size.height; y += dash + gap) { canvas.drawLine(Offset(0, y), Offset(0, (y + dash).clamp(0, size.height)), paint); canvas.drawLine(Offset(size.width, y), Offset(size.width, (y + dash).clamp(0, size.height)), paint); }
  }
  @override
  bool shouldRepaint(covariant MissingLegendPainter oldDelegate) => oldDelegate.fill != fill || oldDelegate.stroke != stroke;
}

class OrganAnchor extends StatelessWidget {
  const OrganAnchor({super.key, required this.state, required this.selected});
  final OrganHealthState? state;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final M24Colors colors = context.m24.colors;
    final Color color = switch (state) { OrganHealthState.ok => colors.success, OrganHealthState.monitor => colors.warning, OrganHealthState.attention => colors.danger, _ => colors.neutralTint };
    return Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? color.withValues(alpha: .20) : Colors.transparent), child: Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: state == null || state == OrganHealthState.missing ? colors.neutral : colors.surface, width: 2), boxShadow: selected ? <BoxShadow>[BoxShadow(color: color.withValues(alpha: .35), blurRadius: 8, spreadRadius: 3)] : null)));
  }
}

class OrganListRow extends StatefulWidget {
  const OrganListRow({super.key, required this.organ, required this.onTap, this.selected = false, this.dimmed = false});
  final OrganOverview organ;
  final VoidCallback onTap;
  final bool selected, dimmed;
  @override
  State<OrganListRow> createState() => _OrganListRowState();
}

class _OrganListRowState extends State<OrganListRow> {
  @override
  void didUpdateWidget(covariant OrganListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300), alignment: .5); });
  }

  @override
  Widget build(BuildContext context) => Opacity(opacity: widget.dimmed ? .7 : 1, child: Material(color: Colors.transparent, child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(12), child: Container(
    key: ValueKey<String>('organ-row-${widget.organ.id}'), constraints: const BoxConstraints(minHeight: 52), padding: EdgeInsets.fromLTRB(widget.selected ? 7 : 10, 10, 10, 10),
    decoration: BoxDecoration(color: widget.selected ? context.m24.colors.primaryTint : context.m24.colors.surface, border: Border(left: BorderSide(color: widget.selected ? context.m24.colors.primary : context.m24.colors.border, width: widget.selected ? 3 : 1), top: BorderSide(color: context.m24.colors.border), right: BorderSide(color: context.m24.colors.border), bottom: BorderSide(color: context.m24.colors.border)), borderRadius: BorderRadius.circular(12)),
    child: Row(children: <Widget>[M24IconTile(icon: organIcon(widget.organ.icon), variant: organTileVariant(widget.organ.state), small: true), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(widget.organ.name(Localizations.localeOf(context).languageCode), style: context.m24.text.label.copyWith(color: widget.selected ? context.m24.colors.primary : null), maxLines: 2, overflow: TextOverflow.ellipsis), Text(organStateLabel(context, widget.organ.state), style: context.m24.text.caption)])), Icon(LucideIcons.chevronRight, size: 18, color: context.m24.colors.inkMuted)])
  ))));
}

class OrganRuleNote extends StatelessWidget {
  const OrganRuleNote({super.key, required this.rule});
  final OrganRuleVersion? rule;
  @override
  Widget build(BuildContext context) => Text(context.l10n.bodyRuleNote(rule?.version ?? context.l10n.bodyNotAvailable), style: context.m24.text.caption.copyWith(color: context.m24.colors.inkSecondary));
}

class OrganComparisonRow extends StatelessWidget {
  const OrganComparisonRow({super.key, required this.comparison});
  final OrganComparison comparison;
  @override
  Widget build(BuildContext context) {
    final List<(String, OrganHealthState?)> values = <(String, OrganHealthState?)>[(context.l10n.bodyToday, comparison.currentState), (context.l10n.bodySixMonthsAgo, comparison.state6m), (context.l10n.bodyTwelveMonthsAgo, comparison.state12m)];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[for (int i = 0; i < values.length; i++) ...<Widget>[Expanded(child: Column(children: <Widget>[Text(values[i].$1, style: context.m24.text.caption, textAlign: TextAlign.center), const SizedBox(height: 8), if (values[i].$2 == null) Text(context.l10n.bodyNotAvailable, style: context.m24.text.label) else OrganStatusPill(state: values[i].$2)])), if (i < 2) Padding(padding: const EdgeInsets.only(top: 28), child: OrganTrendIcon(newer: values[i].$2, older: values[i + 1].$2))]]);
  }
}

class OrganTrendIcon extends StatelessWidget {
  const OrganTrendIcon({super.key, required this.newer, required this.older});
  final OrganHealthState? newer, older;
  @override
  Widget build(BuildContext context) {
    final int? current = newer?.comparisonRank, previous = older?.comparisonRank;
    if (current == null || previous == null) return const SizedBox(width: 20);
    final int delta = current - previous;
    final IconData icon = delta < 0 ? LucideIcons.trendingDown : delta > 0 ? LucideIcons.trendingUp : LucideIcons.arrowRight;
    final Color color = delta < 0 ? context.m24.colors.success : delta > 0 ? context.m24.colors.danger : context.m24.colors.neutral;
    return Tooltip(message: delta < 0 ? context.l10n.bodyTrendImproved : delta > 0 ? context.l10n.bodyTrendWorsened : context.l10n.bodyTrendStable, child: Icon(icon, size: 20, color: color));
  }
}

class OrganEpisodesCard extends StatelessWidget {
  const OrganEpisodesCard({super.key, required this.episodes});
  final List<OrganEpisode> episodes;
  @override
  Widget build(BuildContext context) {
    final DateFormat date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode);
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.bodyAttentionEpisodes, style: context.m24.text.h3), const SizedBox(height: 10), if (episodes.isEmpty) Text(context.l10n.bodyNoEpisodes, style: context.m24.text.bodySmall) else for (final OrganEpisode episode in episodes) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: <Widget>[Expanded(child: Text('${date.format(episode.start)} - ${episode.end == null ? context.l10n.healthEpisodeOngoing : date.format(episode.end!)}', style: context.m24.text.bodySmall)), Text(_duration(context, episode), style: context.m24.text.caption)]))]));
  }
  String _duration(BuildContext context, OrganEpisode episode) { final int days = (episode.end ?? DateTime.now()).difference(episode.start).inDays + 1; return context.l10n.bodyDurationDays(days); }
}

class OrganHistoryTimeline extends StatefulWidget {
  const OrganHistoryTimeline({super.key, required this.entries, required this.biomarkers});
  final List<OrganHistoryEntry> entries;
  final List<OrganBiomarker> biomarkers;
  @override
  State<OrganHistoryTimeline> createState() => _OrganHistoryTimelineState();
}

class _OrganHistoryTimelineState extends State<OrganHistoryTimeline> {
  String? expandedId;
  @override
  Widget build(BuildContext context) {
    final String language = Localizations.localeOf(context).languageCode;
    final DateFormat date = DateFormat.yMMMd(language).add_Hm();
    return Column(children: <Widget>[
      for (final OrganHistoryEntry entry in widget.entries.reversed)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: M24Card(selectable: true, selected: expandedId == entry.id, onTap: () => setState(() => expandedId = expandedId == entry.id ? null : entry.id), child: Column(children: <Widget>[
          Row(children: <Widget>[Expanded(child: Text(date.format(entry.computedAt.toLocal()), style: context.m24.text.label)), OrganStatusPill(state: entry.state), const SizedBox(width: 8), Icon(expandedId == entry.id ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18)]),
          const SizedBox(height: 6),
          Row(children: <Widget>[Expanded(child: Text(organConfidenceLabel(context, entry.confidence), style: context.m24.text.caption)), Text(context.l10n.bodyValuesCount(entry.inputs.length), style: context.m24.text.caption)]), const SizedBox(height: 8), OrganStressBar(value: entry.stressScore, compact: true),
          if (expandedId == entry.id) ...<Widget>[const Divider(height: 20), for (final OrganHistoryInput input in entry.inputs) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: <Widget>[Expanded(child: Text(widget.biomarkers.where((OrganBiomarker item) => item.code == input.code).firstOrNull?.name(language) ?? input.code, style: context.m24.text.bodySmall)), BiomarkerFlagChip(flag: input.flag)]))]
        ])))
    ]);
  }
}