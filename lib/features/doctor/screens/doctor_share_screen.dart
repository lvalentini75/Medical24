import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/util/public_urls.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/doctor/data/doctor_models.dart';
import 'package:medical24/features/doctor/data/doctor_repository.dart';
import 'package:medical24/features/doctor/providers/doctor_providers.dart';
import 'package:medical24/l10n/generated/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class DoctorShareScreen extends ConsumerStatefulWidget {
  const DoctorShareScreen({super.key});
  @override
  ConsumerState<DoctorShareScreen> createState() => _DoctorShareScreenState();
}

class _DoctorShareScreenState extends ConsumerState<DoctorShareScreen> {
  static const List<String> organs = <String>['heart', 'lung', 'liver', 'kidney', 'metabolism', 'gut', 'blood', 'immune', 'thyroid', 'brain', 'musculoskeletal', 'reproductive'];
  static const List<String> categories = <String>['exams', 'reports', 'prescriptions', 'radiology', 'vaccinations', 'other'];
  final TextEditingController pin = TextEditingController(), confirmPin = TextEditingController();
  final Set<String> selectedOrgans = <String>{}, selectedCategories = <String>{};
  bool all = true, loading = false, pdfLoading = false;
  int step = 0, expiryDays = 7, maxOpens = 20;
  DateTime? from, to;
  DoctorShareLink? created;
  String? error;

  @override
  void dispose() { pin.dispose(); confirmPin.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SectionPage(title: l10n.doctorShareTitle, subtitle: created == null ? l10n.doctorShareStep(step + 1, 3) : l10n.doctorShareReady, showDisclaimer: true, child: SingleChildScrollView(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 880), child: created == null ? _form(l10n) : _result(l10n))));
  }

  Widget _form(AppLocalizations l10n) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    if (step == 0) _scope(l10n),
    if (step == 1) _security(l10n),
    if (step == 2) _review(l10n),
    if (error != null) ...<Widget>[const SizedBox(height: 12), Text(error!, style: context.m24.text.bodySmall.copyWith(color: context.m24.colors.danger))],
    const SizedBox(height: 20), Row(children: <Widget>[if (step > 0) M24Button(label: l10n.commonBack, variant: M24ButtonVariant.outline, onPressed: loading ? null : () => setState(() { step--; error = null; })), const Spacer(), M24Button(label: step == 2 ? l10n.doctorCreateLink : l10n.commonContinue, loading: loading, onPressed: _next)]),
  ]);

  Widget _scope(AppLocalizations l10n) => M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Text(l10n.doctorShareWhat, style: context.m24.text.h2), SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l10n.doctorShareEverything), value: all, onChanged: (value) => setState(() => all = value)),
    if (!all) ...<Widget>[Text(l10n.doctorBodyAreas, style: context.m24.text.title), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: organs.map((id) => FilterChip(label: Text(_organ(l10n, id)), selected: selectedOrgans.contains(id), onSelected: (value) => setState(() => value ? selectedOrgans.add(id) : selectedOrgans.remove(id)))).toList()), const SizedBox(height: 20), Text(l10n.doctorPeriod, style: context.m24.text.title), const SizedBox(height: 8), Wrap(spacing: 12, runSpacing: 8, children: <Widget>[OutlinedButton.icon(icon: const Icon(M24Icons.calendar), label: Text(from == null ? l10n.doctorFrom : DateFormat.yMd(Localizations.localeOf(context).toLanguageTag()).format(from!)), onPressed: () => _date(true)), OutlinedButton.icon(icon: const Icon(M24Icons.calendar), label: Text(to == null ? l10n.doctorTo : DateFormat.yMd(Localizations.localeOf(context).toLanguageTag()).format(to!)), onPressed: () => _date(false))]), const SizedBox(height: 20), Text(l10n.doctorDocumentCategories, style: context.m24.text.title), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: categories.map((id) => FilterChip(label: Text(_category(l10n, id)), selected: selectedCategories.contains(id), onSelected: (value) => setState(() => value ? selectedCategories.add(id) : selectedCategories.remove(id)))).toList())],
  ]));

  Widget _security(AppLocalizations l10n) => M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Text(l10n.doctorShareProtect, style: context.m24.text.h2), const SizedBox(height: 8), Text(l10n.doctorPinHelp, style: context.m24.text.bodySmall), const SizedBox(height: 16), TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: l10n.doctorPin)), const SizedBox(height: 8), TextField(controller: confirmPin, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: l10n.doctorPinConfirm)), const SizedBox(height: 16), Text(l10n.doctorExpiryDays(expiryDays), style: context.m24.text.title), Slider(value: expiryDays.toDouble(), min: 1, max: 30, divisions: 29, label: '$expiryDays', onChanged: (value) => setState(() => expiryDays = value.round())), Text(l10n.doctorMaxOpens(maxOpens), style: context.m24.text.title), Slider(value: maxOpens.toDouble(), min: 1, max: 100, divisions: 99, label: '$maxOpens', onChanged: (value) => setState(() => maxOpens = value.round())),
  ]));

  Widget _review(AppLocalizations l10n) => M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(l10n.doctorShareReview, style: context.m24.text.h2), const SizedBox(height: 12), Text(all ? l10n.doctorShareEverything : l10n.doctorShareSelection(selectedOrgans.length, selectedCategories.length), style: context.m24.text.body), const SizedBox(height: 8), Text(l10n.doctorShareLimits(expiryDays, maxOpens), style: context.m24.text.bodySmall)]));

  Widget _result(AppLocalizations l10n) {
    final DoctorShareLink link = created!;
    final Uri publicAddress = publicUrl('/d?code=${Uri.encodeQueryComponent(link.code)}');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      M24Card(child: Column(children: <Widget>[Text(l10n.doctorShareCode, style: context.m24.text.title), const SizedBox(height: 8), SelectableText(link.code, style: context.m24.text.display), IconButton(icon: const Icon(M24Icons.copy), tooltip: l10n.doctorCopy, onPressed: () => _copy(link.code, l10n)), const SizedBox(height: 8), Text(l10n.doctorPinVoiceWarning, textAlign: TextAlign.center, style: context.m24.text.body.copyWith(color: context.m24.colors.warningInk))])),
      const SizedBox(height: 12), M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(l10n.doctorPublicAddress, style: context.m24.text.title), const SizedBox(height: 8), SelectableText(publicAddress.toString()), const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: <Widget>[M24Button(label: l10n.doctorCopy, icon: M24Icons.copy, variant: M24ButtonVariant.outline, onPressed: () => _copy(publicAddress.toString(), l10n)), M24Button(label: l10n.doctorShareAction, icon: M24Icons.share, variant: M24ButtonVariant.secondary, onPressed: () => SharePlus.instance.share(ShareParams(text: publicAddress.toString())))])])),
      const SizedBox(height: 12), M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(l10n.doctorLinkExpires(DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(link.expiresAt.toLocal()))), const SizedBox(height: 4), Text(l10n.doctorOpensLeft(link.opensLeft)), const SizedBox(height: 16), M24Button(label: l10n.doctorGeneratePdf, icon: M24Icons.download, loading: pdfLoading, onPressed: _pdf)])),
    ]);
  }

  Future<void> _next() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => error = null);
    if (step == 0 && !all && selectedOrgans.isEmpty && selectedCategories.isEmpty && from == null && to == null) { setState(() => error = l10n.doctorErrorInvalidScope); return; }
    if (step == 1 && !_validPin(pin.text)) { setState(() => error = l10n.doctorErrorWeakPin); return; }
    if (step == 1 && pin.text != confirmPin.text) { setState(() => error = l10n.doctorErrorPinMismatch); return; }
    if (step < 2) { setState(() => step++); return; }
    setState(() => loading = true);
    try {
      final DoctorShareLink link = await ref.read(doctorRepositoryProvider).createLink(pin: pin.text, scope: DoctorShareScope(all: all, organs: selectedOrgans.toList(), categories: selectedCategories.toList(), from: from, to: to), expiresDays: expiryDays, maxOpens: maxOpens);
      ref.invalidate(doctorLinksProvider); ref.invalidate(doctorDossierProvider);
      if (mounted) setState(() => created = link);
    } on DoctorException catch (exception) {
      if (mounted) setState(() => error = switch (exception.code) { 'weak_pin' => l10n.doctorErrorWeakPin, 'too_many_links' => l10n.doctorErrorTooManyLinks, 'invalid_scope' => l10n.doctorErrorInvalidScope, _ => l10n.doctorErrorCreate });
    } catch (_) { if (mounted) setState(() => error = l10n.doctorErrorCreate); }
    if (mounted) setState(() => loading = false);
  }

  bool _validPin(String value) { if (!RegExp(r'^\d{4,6}$').hasMatch(value) || RegExp(r'^(\d)\1*$').hasMatch(value)) return false; bool ascending = true, descending = true; for (int i = 1; i < value.length; i++) { final int delta = value.codeUnitAt(i) - value.codeUnitAt(i - 1); ascending &= delta == 1; descending &= delta == -1; } return !ascending && !descending; }
  Future<void> _date(bool isFrom) async { final DateTime? value = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialDate: (isFrom ? from : to) ?? DateTime.now()); if (value != null) setState(() { if (isFrom) from = value; else to = value; }); }
  Future<void> _copy(String value, AppLocalizations l10n) async { await Clipboard.setData(ClipboardData(text: value)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.doctorCopied))); }
  Future<void> _pdf() async { setState(() => pdfLoading = true); try { final Uri uri = await ref.read(doctorRepositoryProvider).pdf(created!.snapshotId!, Localizations.localeOf(context).languageCode); await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).doctorPdfError))); } if (mounted) setState(() => pdfLoading = false); }
  String _organ(AppLocalizations l10n, String id) => <String, String>{'heart': l10n.doctorOrganHeart, 'lung': l10n.doctorOrganLung, 'liver': l10n.doctorOrganLiver, 'kidney': l10n.doctorOrganKidney, 'metabolism': l10n.doctorOrganMetabolism, 'gut': l10n.doctorOrganGut, 'blood': l10n.doctorOrganBlood, 'immune': l10n.doctorOrganImmune, 'thyroid': l10n.doctorOrganThyroid, 'brain': l10n.doctorOrganBrain, 'musculoskeletal': l10n.doctorOrganMusculoskeletal, 'reproductive': l10n.doctorOrganReproductive}[id]!;
  String _category(AppLocalizations l10n, String id) => <String, String>{'exams': l10n.archiveCategory_exams, 'reports': l10n.archiveCategory_reports, 'prescriptions': l10n.archiveCategory_prescriptions, 'radiology': l10n.archiveCategory_radiology, 'vaccinations': l10n.archiveCategory_vaccinations, 'other': l10n.archiveCategory_other}[id]!;
}