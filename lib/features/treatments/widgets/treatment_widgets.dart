import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/features/treatments/data/treatment_models.dart';
import 'package:medical24/features/treatments/providers/treatments_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

String treatmentLabel(BuildContext context, String value) => context.l10n.t('treatmentsValue_$value');
String treatmentPrice(BuildContext context, int? cents) => cents == null ? context.l10n.t('treatmentsPriceOnRequest') : NumberFormat.currency(locale: Localizations.localeOf(context).toLanguageTag(), symbol: '€', decimalDigits: cents % 100 == 0 ? 0 : 2).format(cents / 100);

String treatmentRelativeDate(BuildContext context, DateTime date, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(date).isNegative ? Duration.zero : (now ?? DateTime.now()).difference(date);
  if (difference.inMinutes < 1) return context.l10n.treatmentsRelativeNow;
  if (difference.inHours < 1) return context.l10n.treatmentsRelativeMinutes(difference.inMinutes);
  if (difference.inDays < 1) return context.l10n.treatmentsRelativeHours(difference.inHours);
  if (difference.inDays <= 30) return context.l10n.treatmentsRelativeDays(difference.inDays);
  return DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(date.toLocal());
}

/// Relative review date with the complete localized timestamp in a tooltip.
class TreatmentRelativeDate extends StatelessWidget {
  const TreatmentRelativeDate({super.key, required this.date, this.now});
  final DateTime date;
  final DateTime? now;
  @override Widget build(BuildContext context) => Tooltip(message: DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(date.toLocal()), child: Text(treatmentRelativeDate(context, date, now: now)));
}

class TreatmentCard extends ConsumerWidget {
  const TreatmentCard({super.key, required this.treatment, this.compact = false, this.onRemoveFavorite});
  final TreatmentSummary treatment;
  final bool compact;
  final VoidCallback? onRemoveFavorite;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TreatmentSummary> selected = ref.watch(treatmentCompareSelectionProvider);
    final bool compared = selected.any((item) => item.id == treatment.id);
    return M24Card(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      TreatmentCover(url: treatment.coverUrl, isDemo: treatment.isDemo, compared: compared, onCompare: compact ? null : () { final bool accepted = ref.read(treatmentCompareSelectionProvider.notifier).toggle(treatment); if (!accepted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.t('treatmentsCompareLimit')))); }),
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(treatment.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.m24.text.h3),
        if (treatment.facilityName != null) ...<Widget>[const SizedBox(height: 4), Text(treatment.facilityName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.m24.text.bodySmall)],
        const SizedBox(height: 10), Wrap(spacing: 12, runSpacing: 4, children: <Widget>[if (treatment.sessionMinutes != null) Text(context.l10n.t('treatmentsMinutes', args: <String, String>{'count': '${treatment.sessionMinutes}'}), style: context.m24.text.label), Text(context.l10n.t('treatmentsFromPrice', args: <String, String>{'price': treatmentPrice(context, treatment.priceFromCents)}), style: context.m24.text.label.copyWith(color: context.m24.colors.primary))]),
        const SizedBox(height: 10), TreatmentRating(average: treatment.ratingAverage, count: treatment.ratingCount),
        if (!compact) ...<Widget>[const SizedBox(height: 10), TextButton(onPressed: () => context.push('${AppRoutes.treatment(treatment.id)}#evidence'), child: Text(context.l10n.t('treatmentsEvidenceLink')))],
        const SizedBox(height: 8), Row(children: <Widget>[Expanded(child: M24Button(label: context.l10n.t('treatmentsDetails'), onPressed: () => context.push(AppRoutes.treatment(treatment.id)), size: M24ButtonSize.small)), if (onRemoveFavorite != null) ...<Widget>[const SizedBox(width: 8), M24IconButton(icon: M24Icons.delete, tooltip: context.l10n.t('treatmentsRemoveFavorite'), onPressed: onRemoveFavorite)]])
      ]))
    ]));
  }
}

class TreatmentCover extends StatelessWidget {
  const TreatmentCover({super.key, this.url, required this.isDemo, this.compared = false, this.onCompare});
  final String? url;
  final bool isDemo, compared;
  final VoidCallback? onCompare;
  @override
  Widget build(BuildContext context) => SizedBox(height: 150, child: Stack(fit: StackFit.expand, children: <Widget>[
    ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), child: url == null || url!.isEmpty ? ColoredBox(color: context.m24.colors.primarySoft, child: Icon(M24Icons.treatments, size: 44, color: context.m24.colors.primary)) : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: context.m24.colors.primarySoft, child: Icon(M24Icons.treatments, size: 44, color: context.m24.colors.primary)))),
    if (isDemo) Positioned(left: 10, top: 10, child: M24StatusPill(label: context.l10n.t('treatmentsDemo'), variant: M24StatusPillVariant.info)),
    if (onCompare != null) Positioned(right: 8, top: 8, child: DecoratedBox(decoration: BoxDecoration(color: context.m24.colors.surface, shape: BoxShape.circle), child: Checkbox(value: compared, onChanged: (_) => onCompare!())))
  ]));
}

class TreatmentRating extends StatelessWidget {
  const TreatmentRating({super.key, required this.average, required this.count});
  final double? average;
  final int count;
  @override
  Widget build(BuildContext context) => average == null || count == 0 ? Text(context.l10n.t('treatmentsNoReviews'), style: context.m24.text.bodySmall) : Row(children: <Widget>[Icon(M24Icons.star, size: 17, color: context.m24.colors.warning), const SizedBox(width: 5), Expanded(child: Text(context.l10n.t('treatmentsPatientExperience', args: <String, String>{'rating': average!.toStringAsFixed(1), 'count': '$count'}), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.m24.text.bodySmall))]);
}

class TreatmentFiltersPanel extends StatelessWidget {
  const TreatmentFiltersPanel({super.key, required this.filters, required this.facets, required this.onChanged});
  final TreatmentFilters filters;
  final TreatmentFacets facets;
  final ValueChanged<TreatmentFilters> onChanged;
  static const List<String> scopes = <String>['riabilitazione','prevenzione','benessere','diagnostica','terapia'];
  static const List<String> families = <String>['tradizionale','sperimentale','naturale','altro'];
  static const List<String> modalities = <String>['presenza','online','ibrido','domicilio'];
  static const List<String> evidence = <String>['linee_guida','studi_clinici','osservazionale','esperienziale','non_valutato'];
  @override
  Widget build(BuildContext context) => M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Text(context.l10n.t('treatmentsFiltersTitle'), style: context.m24.text.h2), const SizedBox(height: 14),
    Text(context.l10n.t('treatmentsScope'), style: context.m24.text.title),
    for (final String value in scopes) RadioListTile<String>(dense: true, contentPadding: EdgeInsets.zero, title: Text('${treatmentLabel(context, value)} (${facets.scope[value] ?? 0})'), value: value, groupValue: filters.scope, onChanged: (value) => onChanged(filters.copyWith(scope: value))),
    TreatmentDropdown(label: context.l10n.t('treatmentsCity'), value: filters.city, values: facets.city.keys.toList()..sort(), onChanged: (value) => onChanged(filters.copyWith(city: value, clearCity: value == null))),
    TreatmentDropdown(label: context.l10n.t('treatmentsModality'), value: filters.modality, values: modalities, translate: true, onChanged: (value) => onChanged(filters.copyWith(modality: value, clearModality: value == null))),
    const SizedBox(height: 12), Text(context.l10n.t('treatmentsDuration'), style: context.m24.text.title), const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: <Widget>[for (final String value in <String>['30','45','60','90']) M24FilterChip(label: '$value min', selected: filters.duration == value, onSelected: (selected) => onChanged(filters.copyWith(duration: selected ? value : null, clearDuration: !selected)))]),
    const SizedBox(height: 14), Text(context.l10n.t('treatmentsFamily'), style: context.m24.text.title), const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: <Widget>[for (final String value in families) M24FilterChip(label: treatmentLabel(context, value), selected: filters.family == value, onSelected: (selected) => onChanged(filters.copyWith(family: selected ? value : null, clearFamily: !selected)))]),
    const SizedBox(height: 14), TreatmentDropdown(label: context.l10n.t('treatmentsEvidence'), value: filters.evidenceLevel, values: evidence, translate: true, onChanged: (value) => onChanged(filters.copyWith(evidenceLevel: value, clearEvidence: value == null))),
    TreatmentDropdown(label: context.l10n.t('treatmentsMinRating'), value: filters.minRating?.toString(), values: const <String>['3.0','4.0','4.5'], onChanged: (value) => onChanged(filters.copyWith(minRating: double.tryParse(value ?? ''), clearRating: value == null))),
    const SizedBox(height: 12), M24Button(label: context.l10n.t('treatmentsResetFilters'), variant: M24ButtonVariant.tertiary, onPressed: () => onChanged(const TreatmentFilters()))
  ]));
}

class TreatmentDropdown extends StatelessWidget {
  const TreatmentDropdown({super.key, required this.label, required this.value, required this.values, required this.onChanged, this.translate = false});
  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;
  final bool translate;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 12), child: DropdownButtonFormField<String>(value: value, isExpanded: true, decoration: InputDecoration(labelText: label), items: <DropdownMenuItem<String>>[DropdownMenuItem<String>(value: null, child: Text(context.l10n.t('treatmentsAll'))), ...values.map((item) => DropdownMenuItem<String>(value: item, child: Text(translate ? treatmentLabel(context, item) : item)))], onChanged: onChanged));
}

class TreatmentComparePanel extends ConsumerWidget {
  const TreatmentComparePanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TreatmentSummary> items = ref.watch(treatmentCompareSelectionProvider);
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(context.l10n.t('treatmentsYourCompare'), style: context.m24.text.h2), const SizedBox(height: 10),
      if (items.isEmpty) Text(context.l10n.t('treatmentsCompareEmpty'), style: context.m24.text.bodySmall),
      for (final TreatmentSummary item in items) ListTile(contentPadding: EdgeInsets.zero, title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text('${item.sessionMinutes ?? '-'} min · ${treatmentPrice(context, item.priceFromCents)}'), trailing: IconButton(icon: const Icon(M24Icons.discard, size: 18), onPressed: () => ref.read(treatmentCompareSelectionProvider.notifier).toggle(item))),
      if (items.isNotEmpty) M24Button(label: context.l10n.t('treatmentsOpenCompare'), onPressed: items.length < 2 ? null : () => context.push(AppRoutes.treatmentCompare(items.map((item) => item.id).toList())))
    ]));
  }
}

class TreatmentReviewForm extends ConsumerStatefulWidget {
  const TreatmentReviewForm({super.key, required this.treatmentId, this.existing});
  final String treatmentId;
  final Map<String, dynamic>? existing;
  @override
  ConsumerState<TreatmentReviewForm> createState() => _TreatmentReviewFormState();
}
class _TreatmentReviewFormState extends ConsumerState<TreatmentReviewForm> {
  int rating = 0;
  final Map<String, int> sub = <String, int>{'efficacia': 0, 'costo': 0, 'esperienza': 0, 'chiarezza': 0};
  final TextEditingController title = TextEditingController(), body = TextEditingController();
  bool sending = false;
  String? error;
  @override void dispose() { title.dispose(); body.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (widget.existing != null) return M24Card(tint: M24CardTint.info, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(context.l10n.t('treatmentsReviewStatus', args: <String, String>{'status': treatmentLabel(context, widget.existing!['status'].toString())}), style: context.m24.text.title), const SizedBox(height: 10), M24Button(label: context.l10n.t('treatmentsWithdrawReview'), variant: M24ButtonVariant.destructiveOutline, onPressed: () async { await ref.read(treatmentsRepositoryProvider).withdrawReview(widget.existing!['id'].toString()); ref.invalidate(myTreatmentReviewProvider(widget.treatmentId)); })]));
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(context.l10n.t('treatmentsWriteReview'), style: context.m24.text.h2), const SizedBox(height: 10), StarSelector(value: rating, onChanged: (value) => setState(() => rating = value)),
      for (final String key in sub.keys) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: <Widget>[SizedBox(width: 110, child: Text(treatmentLabel(context, key))), Expanded(child: StarSelector(value: sub[key]!, small: true, onChanged: (value) => setState(() => sub[key] = value)))])),
      const SizedBox(height: 12), TextField(controller: title, maxLength: 80, decoration: InputDecoration(labelText: context.l10n.t('treatmentsReviewTitle'))),
      TextField(controller: body, minLines: 4, maxLines: 8, maxLength: 2000, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: context.l10n.t('treatmentsReviewBody'), helperText: context.l10n.t('treatmentsReviewCounter', args: <String, String>{'count': '${body.text.characters.length}'}))),
      if (error != null) Text(error!, style: context.m24.text.bodySmall.copyWith(color: context.m24.colors.danger)),
      const SizedBox(height: 10), M24Button(label: context.l10n.t('treatmentsSubmitReview'), loading: sending, onPressed: rating == 0 || body.text.characters.length < 20 ? null : _submit)
    ]));
  }
  Future<void> _submit() async { setState(() { sending = true; error = null; }); try { await ref.read(treatmentsRepositoryProvider).submitReview(widget.treatmentId, rating, Map<String, int>.fromEntries(sub.entries.where((entry) => entry.value > 0)), title.text.trim().isEmpty ? null : title.text.trim(), body.text.trim()); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.t('treatmentsReviewThanks')))); ref.invalidate(myTreatmentReviewProvider(widget.treatmentId)); } catch (e) { if (!mounted) return; final String code = <String>['review_exists','url_not_allowed','forbidden_content','daily_limit_reached','target_not_found'].firstWhere((value) => e.toString().contains(value), orElse: () => 'unknown'); setState(() => error = context.l10n.t('treatmentsReviewError_$code')); } finally { if (mounted) setState(() => sending = false); } }
}

class StarSelector extends StatelessWidget {
  const StarSelector({super.key, required this.value, required this.onChanged, this.small = false});
  final int value;
  final ValueChanged<int> onChanged;
  final bool small;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: <Widget>[for (int i = 1; i <= 5; i++) IconButton(visualDensity: VisualDensity.compact, constraints: BoxConstraints.tightFor(width: small ? 32 : 40, height: small ? 32 : 40), onPressed: () => onChanged(i), icon: Icon(M24Icons.star, size: small ? 18 : 24, color: i <= value ? context.m24.colors.warning : context.m24.colors.inkMuted, fill: i <= value ? 1 : 0))]);
}

class FeaturedTreatments extends ConsumerWidget {
  const FeaturedTreatments({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(featuredTreatmentsProvider).when(loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())), error: (_, __) => const SizedBox.shrink(), data: (items) { if (items.isEmpty) return const SizedBox.shrink(); return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[M24SectionHeader(title: context.l10n.t('treatmentsFeatured'), actionLabel: context.l10n.t('treatmentsSeeAll'), onAction: () => context.go(AppRoutes.treatments)), const SizedBox(height: 12), SizedBox(height: 355, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, index) => SizedBox(width: 280, child: TreatmentCard(treatment: items[index], compact: true))))]); });
}