import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/m24_theme.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';

class M24KitScreen extends StatefulWidget {
  const M24KitScreen({super.key});
  @override
  State<M24KitScreen> createState() => _M24KitScreenState();
}

class _M24KitScreenState extends State<M24KitScreen> {
  bool dark = false;
  bool desktop = false;
  @override
  Widget build(BuildContext context) => Theme(data: dark ? M24Theme.dark : M24Theme.light, child: Builder(builder: (context) { final double previewWidth = desktop ? 1920 : 390; return Scaffold(appBar: AppBar(title: const Text('Medical 24 - UI Kit'), actions: <Widget>[const Text('390'), Switch(value: desktop, onChanged: (value) => setState(() => desktop = value)), const Text('1920'), const SizedBox(width: 16), const Icon(M24Icons.settings), Switch(value: dark, onChanged: (value) => setState(() => dark = value)), const SizedBox(width: 16)]), body: ColoredBox(color: context.m24.colors.bg, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: previewWidth, child: MediaQuery(data: MediaQuery.of(context).copyWith(size: Size(previewWidth, MediaQuery.sizeOf(context).height)), child: SingleChildScrollView(padding: EdgeInsets.all(desktop ? 32 : 16), child: const _KitContent())))))); }));
}

class _KitContent extends StatefulWidget {
  const _KitContent();
  @override
  State<_KitContent> createState() => _KitContentState();
}

class _KitContentState extends State<_KitContent> {
  int segment = 0;
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final List<Widget> sections = <Widget>[
      const M24AppHeader(initials: 'AR', bellTooltip: 'Notifiche', avatarTooltip: 'Profilo', hasUnreadAlerts: true),
      const M24Breadcrumb(segments: <String>['Il mio spazio salute', 'Kit componenti']),
      M24PageHeader(title: 'La mia salute', subtitle: 'Quadro aggiornato al 20 ottobre 2026', action: M24Button(label: 'Carica referto', icon: M24Icons.upload, onPressed: () {})),
      const M24SectionHeader(title: 'Stati e azioni', actionLabel: 'Vedi tutte'),
      Wrap(spacing: 8, runSpacing: 8, children: const <Widget>[M24StatusPill(label: 'Archiviato', variant: M24StatusPillVariant.info), M24StatusPill(label: 'Analizzato', variant: M24StatusPillVariant.success), M24StatusPill(label: 'Da verificare', variant: M24StatusPillVariant.warning), M24StatusPill(label: 'Critico', variant: M24StatusPillVariant.danger), M24StatusPill(label: 'Caricato', variant: M24StatusPillVariant.neutral)]),
      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[M24Button(label: 'Carica documento', icon: M24Icons.upload, onPressed: () {}), M24Button(label: 'Secondario', variant: M24ButtonVariant.secondary, onPressed: () {}), M24Button(label: 'Outline', variant: M24ButtonVariant.outline, onPressed: () {}), M24Button(label: 'Apri lo storico', variant: M24ButtonVariant.tertiary, onPressed: () {}), M24Button(label: 'Revoca', variant: M24ButtonVariant.destructiveOutline, onPressed: () {}), M24Button(label: 'Verifica i 2 valori', variant: M24ButtonVariant.warning, onPressed: () {}), const M24Button(label: 'Disabilitato', onPressed: null), M24Button(label: 'Caricamento', loading: true, onPressed: () {})]),
      M24Segmented<int>(segments: const <M24Segment<int>>[M24Segment(value: 0, label: 'Valori', icon: M24Icons.chart), M24Segment(value: 1, label: 'Sintomi', icon: M24Icons.symptoms), M24Segment(value: 2, label: 'Avvisi', icon: M24Icons.alerts)], selected: segment, onChanged: (value) => setState(() => segment = value)),
      Wrap(spacing: 8, children: <Widget>[M24FilterChip(label: 'Tutti', selected: true, onSelected: (_) {}), M24FilterChip(label: '2026', selected: false, hasMenu: true, onSelected: (_) {}), M24FilterChip(label: 'Filtri', selected: false, icon: M24Icons.settings, onSelected: (_) {})]),
      const M24SearchField(hintText: 'Cerca un documento'),
      M24Card(padding: EdgeInsets.zero, child: Column(children: <Widget>[M24ListRow(icon: M24Icons.archive, title: 'Esami del sangue', subtitle: '20 ott 2026 - Esami', status: const M24StatusPill(label: 'Analizzato', variant: M24StatusPillVariant.success), onTap: () {}), Divider(color: context.m24.colors.divider), M24ListRow(icon: M24Icons.review, title: 'Referto cardiologico', subtitle: '12 ott 2026 - Referti', status: const M24StatusPill(label: 'Da verificare', variant: M24StatusPillVariant.warning), onTap: () {})])),
      Wrap(spacing: 12, runSpacing: 12, children: const <Widget>[SizedBox(width: 260, child: M24StatTile(icon: M24Icons.archive, label: 'Documenti', value: '12')), M24DateTile(day: '20', month: 'OTT'), M24DateTile(day: '24', month: 'OTT', variant: M24DateTileVariant.warning)]),
      M24Banner(title: '2 valori da verificare', subtitle: 'Dal referto del 20 ottobre', onTap: () {}),
      const M24Disclaimer(),
      M24Tabs(labels: const <String>['Tutti i valori', 'Storico', 'Sintomi', 'Avvisi'], index: tab, onChanged: (value) => setState(() => tab = value)),
      M24Table(columns: const <String>['Documento', 'Data', 'Categoria', 'Stato'], rows: const <List<Widget>>[[Text('Esami del sangue'), Text('20 ott 2026'), Text('Esami'), M24StatusPill(label: 'Confermato', variant: M24StatusPillVariant.success)], [Text('Referto cardiologico'), Text('12 ott 2026'), Text('Referti'), M24StatusPill(label: 'Da verificare', variant: M24StatusPillVariant.warning)]], selectedRow: 0),
      SizedBox(height: 240, child: M24Card(child: LineChart(LineChartData(minX: 0, maxX: 3, minY: 60, maxY: 120, gridData: M24ChartStyle.grid(context), titlesData: M24ChartStyle.titles(context), borderData: FlBorderData(show: false), rangeAnnotations: M24ChartStyle.referenceBand(context, minY: 75, maxY: 105), lineTouchData: M24ChartStyle.touch(context), lineBarsData: <LineChartBarData>[M24ChartStyle.line(context, const <FlSpot>[FlSpot(0, 82), FlSpot(1, 96), FlSpot(2, 91), FlSpot(3, 108)])])))),
      const M24EmptyState(icon: M24Icons.archive, title: 'Nessun documento', message: 'Carica il primo referto per iniziare.', actionLabel: 'Carica documento'),
      M24Sheet(items: <M24SheetItem>[M24SheetItem(icon: M24Icons.upload, label: 'Carica un documento', onTap: () {}), M24SheetItem(icon: M24Icons.plus, label: 'Aggiungi un valore', onTap: () {})]),
    ];
    return Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: desktop ? 1440 : 390), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections.expand((widget) => <Widget>[widget, const SizedBox(height: 24)]).toList())));
  }
}