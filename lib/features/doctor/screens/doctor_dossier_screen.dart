import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/doctor/data/doctor_models.dart';
import 'package:medical24/features/doctor/providers/doctor_providers.dart';
import 'package:medical24/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class DoctorDossierScreen extends ConsumerWidget {
  const DoctorDossierScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SectionPage(title: l10n.doctorDossierTitle, showDisclaimer: true, child: ref.watch(doctorDossierProvider).when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: l10n.doctorDossierError, onRetry: () => ref.invalidate(doctorDossierProvider)), data: (dossier) => dossier == null ? AppEmptyView(icon: M24Icons.document, title: l10n.doctorDossierEmpty, body: l10n.doctorDossierEmptyBody, action: DoctorDossierGenerateButton()) : DoctorDossierContent(dossier: dossier)));
  }
}

class DoctorDossierGenerateButton extends ConsumerStatefulWidget {
  const DoctorDossierGenerateButton({super.key});
  @override ConsumerState<DoctorDossierGenerateButton> createState() => _DoctorDossierGenerateButtonState();
}

class _DoctorDossierGenerateButtonState extends ConsumerState<DoctorDossierGenerateButton> {
  bool loading = false;
  @override Widget build(BuildContext context) => M24Button(label: AppLocalizations.of(context).doctorDossierGenerate, loading: loading, onPressed: _generate);
  Future<void> _generate() async { setState(() => loading = true); try { await ref.read(doctorRepositoryProvider).buildDossier(); ref.invalidate(doctorDossierProvider); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).doctorDossierError))); } if (mounted) setState(() => loading = false); }
}

class DoctorDossierContent extends ConsumerStatefulWidget {
  const DoctorDossierContent({super.key, required this.dossier});
  final DoctorDossier dossier;
  @override ConsumerState<DoctorDossierContent> createState() => _DoctorDossierContentState();
}

class _DoctorDossierContentState extends ConsumerState<DoctorDossierContent> {
  bool pdfLoading = false;
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Map<String, dynamic> payload = widget.dossier.payload;
    final String generated = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(widget.dossier.generatedAt.toLocal());
    return ListView(children: <Widget>[
      Row(children: <Widget>[Expanded(child: Text(l10n.doctorDossierGenerated(generated), style: context.m24.text.bodySmall)), M24Button(label: l10n.doctorDownloadPdf, icon: M24Icons.download, loading: pdfLoading, onPressed: _pdf)]), const SizedBox(height: 16),
      DoctorDossierSection(title: l10n.doctorHealthStatus, rows: _health(l10n, payload['health_status'])),
      DoctorDossierSection(title: l10n.doctorAreasToFollow, rows: _rows(payload['organs'], (row) => '${_organ(l10n, row['organ_id'].toString())}: ${_state(l10n, row['state'].toString())}')),
      DoctorDossierSection(title: l10n.doctorRisks, rows: _rows(payload['risks'], (row) => '${row['family']}: ${row['level']}')),
      DoctorDossierSection(title: l10n.doctorOutOfRange, rows: _rows(payload['out_of_range'], (row) => '${row['name'] ?? row['code']}: ${row['value']} ${row['unit'] ?? ''} · ${_trend(l10n, row['trend']?.toString())}')),
      DoctorDossierSection(title: l10n.doctorRecommendedExams, rows: _rows(payload['recommended_exams'], (row) => row['title']?.toString() ?? row['kind']?.toString() ?? '')),
      DoctorDossierSection(title: l10n.doctorDocuments, rows: _rows(payload['documents'], (row) => '${row['title']} · ${row['document_date'] ?? ''}')),
      DoctorDossierSection(title: l10n.doctorRuleVersions, rows: <String>[..._versionRows(widget.dossier.ruleVersions)]),
      DoctorDossierSection(title: l10n.doctorDisclaimerTitle, rows: <String>[l10n.doctorDossierDisclaimer]),
    ]);
  }

  List<String> _health(AppLocalizations l10n, dynamic raw) { final Map<String, dynamic> row = Map<String, dynamic>.from(raw as Map? ?? const <String, dynamic>{}); return <String>[_state(l10n, row['level']?.toString() ?? 'missing'), l10n.doctorHealthCounts((row['organs_ok'] as num?)?.toInt() ?? 0, (row['organs_monitor'] as num?)?.toInt() ?? 0, (row['organs_attention'] as num?)?.toInt() ?? 0)]; }
  List<String> _rows(dynamic raw, String Function(Map<String, dynamic>) format) => (raw as List? ?? const <dynamic>[]).whereType<Map>().map((row) => format(Map<String, dynamic>.from(row))).where((value) => value.isNotEmpty).toList();
  Iterable<String> _versionRows(Map<String, dynamic> values) sync* { for (final MapEntry<String, dynamic> entry in values.entries) { final List<dynamic> versions = entry.value as List? ?? const <dynamic>[]; if (versions.isNotEmpty) yield '${entry.key}: ${versions.join(', ')}'; } }
  String _state(AppLocalizations l10n, String state) => switch (state) { 'ok' => l10n.bodyState_ok, 'monitor' => l10n.bodyState_monitor, 'attention' => l10n.bodyState_attention, _ => l10n.bodyState_missing };
  String _trend(AppLocalizations l10n, String? trend) => switch (trend) { 'up' => l10n.doctorTrendUp, 'down' => l10n.doctorTrendDown, 'stable' => l10n.doctorTrendStable, _ => l10n.doctorTrendUnknown };
  String _organ(AppLocalizations l10n, String id) => <String, String>{'heart': l10n.doctorOrganHeart, 'lung': l10n.doctorOrganLung, 'liver': l10n.doctorOrganLiver, 'kidney': l10n.doctorOrganKidney, 'metabolism': l10n.doctorOrganMetabolism, 'gut': l10n.doctorOrganGut, 'blood': l10n.doctorOrganBlood, 'immune': l10n.doctorOrganImmune, 'thyroid': l10n.doctorOrganThyroid, 'brain': l10n.doctorOrganBrain, 'musculoskeletal': l10n.doctorOrganMusculoskeletal, 'reproductive': l10n.doctorOrganReproductive, 'breast': l10n.doctorOrganBreast, 'reproductive_f': l10n.doctorOrganReproductiveFemale, 'prostate': l10n.doctorOrganProstate, 'reproductive_m': l10n.doctorOrganReproductiveMale}[id] ?? id;
  Future<void> _pdf() async { setState(() => pdfLoading = true); try { final Uri uri = await ref.read(doctorRepositoryProvider).pdf(widget.dossier.id, Localizations.localeOf(context).languageCode); await launchUrl(uri, mode: LaunchMode.externalApplication); ref.invalidate(doctorDossierProvider); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).doctorPdfError))); } if (mounted) setState(() => pdfLoading = false); }
}

class DoctorDossierSection extends StatelessWidget {
  const DoctorDossierSection({super.key, required this.title, required this.rows});
  final String title;
  final List<String> rows;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: context.m24.text.h2), const SizedBox(height: 10), if (rows.isEmpty) Text(AppLocalizations.of(context).doctorNoData, style: context.m24.text.bodySmall) else for (final String row in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(row, style: context.m24.text.body))])));
}