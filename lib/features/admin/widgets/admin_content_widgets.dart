import 'package:flutter/material.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/data_display.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:medical24/features/admin/data/admin_models.dart';
import 'package:medical24/features/admin/widgets/admin_editor_fields.dart';
import 'package:medical24/features/admin/widgets/admin_widgets.dart';
import 'package:medical24/features/treatments/widgets/treatment_widgets.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class AdminTreatmentStatusBar extends StatelessWidget {
  const AdminTreatmentStatusBar({super.key, required this.status, this.version = 1, this.publishedAt, this.onTransition});
  final String status;
  final int version;
  final DateTime? publishedAt;
  final ValueChanged<String>? onTransition;
  @override Widget build(BuildContext context) {
    final List<(String, String, M24ButtonVariant)> actions = switch (status) {
      'draft' => <(String, String, M24ButtonVariant)>[('verified', context.l10n.adminMarkVerified, M24ButtonVariant.outlinePrimary)],
      'verified' => <(String, String, M24ButtonVariant)>[('published', context.l10n.adminPublish, M24ButtonVariant.primary)],
      'published' => <(String, String, M24ButtonVariant)>[('retired', context.l10n.adminWithdraw, M24ButtonVariant.destructiveOutline), ('verified', context.l10n.adminReturnToReview, M24ButtonVariant.outline)],
      _ => <(String, String, M24ButtonVariant)>[],
    };
    return M24Card(child: Row(children: <Widget>[AdminContentStatusPill(status: status), const SizedBox(width: 16), Text('${context.l10n.adminVersion} $version'), if (publishedAt != null) ...<Widget>[const SizedBox(width: 16), Text('${context.l10n.adminPublishedAt}: ${adminDate(context, publishedAt)}')], const Spacer(), for (final action in actions) Padding(padding: const EdgeInsets.only(left: 8), child: M24Button(label: action.$2, variant: action.$3, onPressed: onTransition == null ? null : () => onTransition!(action.$1))) ]));
  }
}

class AdminContentStatusPill extends StatelessWidget {
  const AdminContentStatusPill({super.key, required this.status});
  final String status;
  @override Widget build(BuildContext context) { final (String, M24StatusPillVariant) value = switch (status) {'verified' => (context.l10n.adminVerified, M24StatusPillVariant.info), 'published' => (context.l10n.adminPublished, M24StatusPillVariant.success), 'retired' || 'withdrawn' => (context.l10n.adminRetired, M24StatusPillVariant.neutral), 'approved' => (context.l10n.adminApproved, M24StatusPillVariant.success), 'rejected' => (context.l10n.adminRejected, M24StatusPillVariant.danger), _ => (context.l10n.adminPendingOrDraft(status), M24StatusPillVariant.warning)}; return M24StatusPill(label: value.$1, variant: value.$2); }
}

class AdminTreatmentEditor extends StatefulWidget {
  const AdminTreatmentEditor({super.key, this.treatment, this.doctors = const <AdminDoctor>[], this.facilities = const <AdminFacility>[], this.tags = const <AdminTreatmentTag>[], required this.onSave, this.onTransition});
  final AdminTreatment? treatment;
  final List<AdminDoctor> doctors;
  final List<AdminFacility> facilities;
  final List<AdminTreatmentTag> tags;
  final Future<void> Function(Map<String, dynamic> patch) onSave;
  final ValueChanged<String>? onTransition;
  @override State<AdminTreatmentEditor> createState() => _AdminTreatmentEditorState();
}

class _AdminTreatmentEditorState extends State<AdminTreatmentEditor> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final Map<String, dynamic> original = Map<String, dynamic>.from(widget.treatment?.data ?? const <String, dynamic>{});
  late final TextEditingController title = _controller('title'), summary = _controller('summary'), category = _controller('category'), priceFrom = _moneyController('price_from_cents'), priceTo = _moneyController('price_to_cents'), priceNotes = _controller('price_notes'), duration = _controller('session_minutes'), sessions = _controller('sessions_count'), weeks = _controller('course_weeks'), waiting = _controller('waiting_days'), requirements = _controller('requirements'), outcome = _controller('expected_outcome');
  late final Map<String, TextEditingController> sections = <String, TextEditingController>{for (final key in <String>['per_chi','come_funziona','durata','rischi_e_controindicazioni','evidenze_e_limiti']) key: TextEditingController(text: _map(original['description_sections'])[key]?.toString() ?? '')};
  late String scope = '${original['scope'] ?? 'terapia'}', family = '${original['family'] ?? 'tradizionale'}', evidence = '${original['evidence_level'] ?? 'non_valutato'}', modality = '${original['modality'] ?? 'presenza'}';
  late bool demo = original['is_demo'] == true, featured = original['featured'] == true, ssn = original['ssn_covered'] == true;
  late String? doctorId = original['doctor_id']?.toString(), facilityId = original['facility_id']?.toString();
  late List<String> conditions = (original['conditions'] as List? ?? const <dynamic>[]).map((value) => '$value').toList();
  late List<Map<String, dynamic>> contraindications = _maps(original['contraindications']);
  late List<Map<String, dynamic>> media = _maps(original['media']);
  late Set<String> selectedTags = (original['tags'] as List? ?? const <dynamic>[]).map((e) => '$e').toSet();
  bool saving = false;
  TextEditingController _controller(String key) => TextEditingController(text: original[key]?.toString() ?? '');
  TextEditingController _moneyController(String key) => TextEditingController(text: original[key] is num ? ((original[key] as num) / 100).toStringAsFixed(2) : '');
  @override void dispose() { for (final controller in <TextEditingController>[title,summary,category,priceFrom,priceTo,priceNotes,duration,sessions,weeks,waiting,requirements,outcome,...sections.values]) controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Form(key: formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    if (widget.treatment != null) AdminTreatmentStatusBar(status: widget.treatment!.status, version: widget.treatment!.version, publishedAt: widget.treatment!.publishedAt, onTransition: widget.onTransition),
    const SizedBox(height: 16), AdminEditorSection(anchorKey: const Key('adminTreatmentIdentity'), title: context.l10n.adminIdentity, children: <Widget>[
      TextFormField(controller: title, decoration: InputDecoration(labelText: context.l10n.adminTitle), validator: _required),
      TextFormField(key: const Key('adminTreatmentSummary'), controller: summary, maxLength: 240, decoration: InputDecoration(labelText: context.l10n.adminSummary), validator: (value) => (value ?? '').length > 240 ? context.l10n.adminSummaryTooLong : null),
      TextFormField(controller: category, decoration: InputDecoration(labelText: context.l10n.adminCategory)), AdminEditorDropdown(label: context.l10n.adminScope, value: scope, values: const <String>['terapia','riabilitazione','prevenzione','benessere','diagnostica'], onChanged: (v) => scope = v), AdminEditorDropdown(label: context.l10n.adminFamily, value: family, values: const <String>['tradizionale','sperimentale','naturale','altro'], onChanged: (v) => family = v), AdminEditorDropdown(label: context.l10n.adminEvidenceLevel, value: evidence, values: const <String>['linee_guida','studi_clinici','osservazionale','esperienziale','non_valutato'], onChanged: (v) => evidence = v), AdminEditorDropdown(label: context.l10n.adminModality, value: modality, values: const <String>['presenza','online','ibrido','domicilio'], onChanged: (v) => modality = v), SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.adminDemo), value: demo, onChanged: (v) => setState(() => demo = v)), SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.adminFeatured), value: featured, onChanged: (v) => setState(() => featured = v)),
    ]),
    AdminEditorSection(title: context.l10n.adminContents, children: <Widget>[for (final entry in sections.entries) TextFormField(key: Key('adminSection-${entry.key}'), controller: entry.value, minLines: 3, maxLines: 8, decoration: InputDecoration(labelText: context.l10n.adminSectionLabel(entry.key), helperText: entry.key == 'evidenze_e_limiti' ? context.l10n.adminEvidenceRequiredPublish : null))]),
    AdminEditorSection(title: context.l10n.adminConditionsTags, children: <Widget>[AdminChipInput(label: context.l10n.adminConditions, values: conditions, onChanged: (value) => setState(() => conditions = value)), AdminTagSelector(tags: widget.tags, selected: selectedTags, onChanged: (value) => setState(() => selectedTags = value))]),
    AdminEditorSection(title: context.l10n.adminContraindications, children: <Widget>[AdminContraindicationsEditor(rows: contraindications, onChanged: (value) => setState(() => contraindications = value))]),
    AdminEditorSection(anchorKey: const Key('adminTreatmentCosts'), title: context.l10n.adminCostsTimes, children: <Widget>[Row(children: <Widget>[Expanded(child: TextFormField(key: const Key('adminPriceFrom'), controller: priceFrom, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.l10n.adminPriceFrom), validator: (_) => _priceError())), const SizedBox(width: 12), Expanded(child: TextFormField(key: const Key('adminPriceTo'), controller: priceTo, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.l10n.adminPriceTo), validator: (_) => null))]), TextFormField(controller: priceNotes, decoration: InputDecoration(labelText: context.l10n.adminPriceNotes)), SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.adminSsn), value: ssn, onChanged: (v) => setState(() => ssn = v)), for (final field in <(TextEditingController,String)>[(duration,context.l10n.adminMinutes),(sessions,context.l10n.adminSessions),(weeks,context.l10n.adminWeeks),(waiting,context.l10n.adminWaitingDays)]) TextFormField(controller: field.$1, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: field.$2))]),
    AdminEditorSection(title: context.l10n.adminRequirementsOutcome, children: <Widget>[TextFormField(controller: requirements, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: context.l10n.adminRequirements)), TextFormField(controller: outcome, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: context.l10n.adminExpectedOutcome))]),
    AdminEditorSection(title: context.l10n.adminMedia, children: <Widget>[AdminMediaEditor(rows: media, onChanged: (value) => setState(() => media = value))]),
    AdminEditorSection(title: context.l10n.adminProfessionalFacility, children: <Widget>[DropdownButtonFormField<String>(value: doctorId, decoration: InputDecoration(labelText: context.l10n.adminProfessional), items: widget.doctors.map((d) => DropdownMenuItem<String>(value: d.id, child: Text(d.name))).toList(), onChanged: (v) => setState(() => doctorId = v)), DropdownButtonFormField<String>(value: facilityId, decoration: InputDecoration(labelText: context.l10n.adminFacility), items: widget.facilities.map((f) => DropdownMenuItem<String>(value: f.id, child: Text(f.name))).toList(), onChanged: (v) => setState(() => facilityId = v))]),
    M24Button(key: const Key('adminTreatmentSave'), label: context.l10n.commonSave, loading: saving, onPressed: _save),
  ]));
  String? _required(String? value) => (value ?? '').trim().isEmpty ? context.l10n.commonRequired : null;
  String? _priceError() { final from = double.tryParse(priceFrom.text), to = double.tryParse(priceTo.text); return from != null && to != null && from > to ? context.l10n.adminInvalidPriceRange : null; }
  Future<void> _save() async { if (!formKey.currentState!.validate()) return; final current = <String, dynamic>{'title':title.text.trim(),'summary':summary.text.trim(),'category':category.text.trim(),'scope':scope,'family':family,'evidence_level':evidence,'modality':modality,'is_demo':demo,'featured':featured,'description_sections':<String,dynamic>{for(final e in sections.entries)e.key:e.value.text.trim()},'conditions':conditions,'tags':selectedTags.toList(),'contraindications':contraindications.map((row) => <String,dynamic>{'text':'${row['text'] ?? ''}'.trim(),'severity':row['severity'] ?? 'bassa'}).toList(),'price_from_cents':_cents(priceFrom.text),'price_to_cents':_cents(priceTo.text),'price_notes':priceNotes.text.trim(),'ssn_covered':ssn,'session_minutes':_int(duration.text),'sessions_count':_int(sessions.text),'course_weeks':_int(weeks.text),'waiting_days':_int(waiting.text),'requirements':requirements.text.trim(),'expected_outcome':outcome.text.trim(),'media':media.map((row) => <String,dynamic>{'type':row['type'] ?? 'image','url':'${row['url'] ?? ''}'.trim(),'caption':'${row['caption'] ?? ''}'.trim()}).toList(),'doctor_id':doctorId,'facility_id':facilityId}; if (widget.treatment?.id != null) current['id'] = widget.treatment!.id; setState(() => saving=true); try { await widget.onSave(current); } finally { if(mounted)setState(()=>saving=false); } }
  int? _int(String value) => value.trim().isEmpty ? null : int.tryParse(value); int? _cents(String value) => value.trim().isEmpty ? null : ((double.tryParse(value) ?? 0)*100).round(); Map<String,dynamic> _map(dynamic value)=>value is Map?Map<String,dynamic>.from(value):<String,dynamic>{}; List<Map<String,dynamic>> _maps(dynamic value)=>value is List?value.whereType<Map>().map((row)=>Map<String,dynamic>.from(row)).toList():<Map<String,dynamic>>[];
}

class AdminEditorSection extends StatelessWidget { const AdminEditorSection({super.key, this.anchorKey, required this.title, required this.children}); final Key? anchorKey; final String title; final List<Widget> children; @override Widget build(BuildContext context) => Padding(key: anchorKey, padding: const EdgeInsets.only(bottom: 16), child: M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(title, style: context.m24.text.h2), const SizedBox(height: 12), for(final child in children) Padding(padding: const EdgeInsets.only(bottom: 12), child: child)]))); }
class AdminEditorDropdown extends StatelessWidget { const AdminEditorDropdown({super.key, required this.label, required this.value, required this.values, required this.onChanged}); final String label,value; final List<String> values; final ValueChanged<String> onChanged; @override Widget build(BuildContext context)=>DropdownButtonFormField<String>(value:value,decoration:InputDecoration(labelText:label),items:values.map((v)=>DropdownMenuItem<String>(value:v,child:Text(context.l10n.adminValueLabel(v)))).toList(),onChanged:(v){if(v!=null)onChanged(v);}); }

class AdminReviewQueue extends StatelessWidget {
  const AdminReviewQueue({super.key, required this.reviews, this.onApprove, this.onReject, this.onOpenTarget});
  final List<AdminReview> reviews;
  final ValueChanged<AdminReview>? onApprove, onReject, onOpenTarget;
  @override Widget build(BuildContext context) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: 1500, child: M24Table(columns: <String>[context.l10n.adminDate,context.l10n.adminAuthor,context.l10n.adminTarget,context.l10n.adminRating,context.l10n.adminTitle,context.l10n.adminPreview,''], fixedColumnWidth: 175, rows: reviews.map((r)=><Widget>[if(r.createdAt != null) TreatmentRelativeDate(date:r.createdAt!) else const Text('-'),Text(r.authorLabel),TextButton(onPressed:onOpenTarget==null?null:()=>onOpenTarget!(r),child:Text(r.targetLabel)),Text('${r.rating}/5 · ${r.subRatings.entries.map((e)=>'${e.key}: ${e.value}').join(', ')}',maxLines:2,overflow:TextOverflow.ellipsis),Text(r.title),Text(r.body,maxLines:2,overflow:TextOverflow.ellipsis),Row(children:<Widget>[IconButton(key:Key('approve-${r.id}'),tooltip:context.l10n.adminApprove,icon:const Icon(M24Icons.confirm),onPressed:onApprove==null?null:()=>onApprove!(r)),IconButton(tooltip:context.l10n.adminReject,icon:const Icon(M24Icons.discard),onPressed:onReject==null?null:()=>onReject!(r))])]).toList())));
}
