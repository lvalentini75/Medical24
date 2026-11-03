import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/treatments/data/treatment_models.dart';
import 'package:medical24/features/treatments/providers/treatments_providers.dart';
import 'package:medical24/features/treatments/widgets/treatment_widgets.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class TreatmentDetailScreen extends ConsumerWidget {
  const TreatmentDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(treatmentDetailProvider(id)).when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.t('treatmentsLoadError'), onRetry: () => ref.invalidate(treatmentDetailProvider(id))), data: (detail) => detail == null ? AppEmptyView(title: context.l10n.t('treatmentsNotFound'), body: context.l10n.t('treatmentsEmptyBody')) : TreatmentDetailContent(detail: detail));
}

class TreatmentDetailContent extends ConsumerWidget {
  const TreatmentDetailContent({super.key, required this.detail});
  final TreatmentDetail detail;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, dynamic> doctor = detail.map('doctor'), facility = detail.map('facility'), rating = detail.map('rating'), sections = detail.map('description_sections');
    final bool desktop = MediaQuery.sizeOf(context).width >= 1000;
    final TreatmentSummary selectionItem = TreatmentSummary(id: detail.id, title: detail.title, priceFromCents: detail.integer('price_from_cents'), sessionMinutes: detail.integer('session_minutes'), facilityName: facility['name']?.toString());
    return SectionPage(title: detail.title, subtitle: facility['name']?.toString(), showDisclaimer: true, action: Wrap(spacing: 8, children: <Widget>[M24Button(label: context.l10n.t('treatmentsFavorite'), icon: M24Icons.favorite, variant: M24ButtonVariant.outlinePrimary, onPressed: () async { final bool active = await ref.read(treatmentsRepositoryProvider).toggleFavorite(detail.id); ref.invalidate(favoriteTreatmentsProvider); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.t(active ? 'treatmentsFavoriteAdded' : 'treatmentsFavoriteRemoved')))); }), M24Button(label: context.l10n.t('treatmentsAddCompare'), icon: M24Icons.compare, onPressed: () => ref.read(treatmentCompareSelectionProvider.notifier).toggle(selectionItem))]), child: ListView(children: <Widget>[
      SizedBox(height: desktop ? 300 : 220, child: TreatmentCover(url: detail.text('cover_url'), isDemo: detail.flag('is_demo'))), const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[for (final String key in <String>['family','scope','evidence_level','modality']) if (detail.text(key) != null) Chip(label: Text(treatmentLabel(context, detail.text(key)!)))]),
      const SizedBox(height: 20), TreatmentFacts(detail: detail), const SizedBox(height: 24),
      if (desktop) Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Expanded(flex: 8, child: TreatmentDescription(sections: sections, contraindications: detail.list('contraindications'), requirements: detail.text('requirements'), outcome: detail.text('expected_outcome'))), const SizedBox(width: 24), Expanded(flex: 4, child: Column(children: <Widget>[if (doctor.isNotEmpty) ProviderCard(title: context.l10n.t('treatmentsProfessional'), data: doctor, doctor: true), if (doctor.isNotEmpty && facility.isNotEmpty) const SizedBox(height: 16), if (facility.isNotEmpty) ProviderCard(title: context.l10n.t('treatmentsFacility'), data: facility)]))]) else ...<Widget>[TreatmentDescription(sections: sections, contraindications: detail.list('contraindications'), requirements: detail.text('requirements'), outcome: detail.text('expected_outcome')), if (doctor.isNotEmpty) ...<Widget>[const SizedBox(height: 16), ProviderCard(title: context.l10n.t('treatmentsProfessional'), data: doctor, doctor: true)], if (facility.isNotEmpty) ...<Widget>[const SizedBox(height: 16), ProviderCard(title: context.l10n.t('treatmentsFacility'), data: facility)]],
      const SizedBox(height: 24), TreatmentRatingSummary(data: rating), const SizedBox(height: 24), TreatmentReviews(treatmentId: detail.id), const SizedBox(height: 24), ref.watch(myTreatmentReviewProvider(detail.id)).when(loading: () => const AppLoadingView(), error: (_, __) => const SizedBox.shrink(), data: (existing) => TreatmentReviewForm(treatmentId: detail.id, existing: existing)), const SizedBox(height: 24)
    ]));
  }
}

class TreatmentFacts extends StatelessWidget {
  const TreatmentFacts({super.key, required this.detail});
  final TreatmentDetail detail;
  @override
  Widget build(BuildContext context) {
    final List<(String, String)> facts = <(String, String)>[(context.l10n.t('treatmentsSessions'), '${detail.integer('sessions_count') ?? '-'}'), (context.l10n.t('treatmentsDuration'), '${detail.integer('session_minutes') ?? '-'} min'), (context.l10n.t('treatmentsWeeks'), '${detail.integer('course_weeks') ?? '-'}'), (context.l10n.t('treatmentsWaiting'), '${detail.integer('waiting_days') ?? '-'} ${context.l10n.t('treatmentsDays')}'), (context.l10n.t('treatmentsCost'), '${treatmentPrice(context, detail.integer('price_from_cents'))} – ${treatmentPrice(context, detail.integer('price_to_cents'))}')];
    return M24Card(child: Wrap(spacing: 28, runSpacing: 16, children: <Widget>[for (final fact in facts) SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(fact.$1, style: context.m24.text.caption), Text(fact.$2, style: context.m24.text.title)])), if (detail.flag('ssn_covered')) const Chip(label: Text('SSN')), if (detail.text('price_notes') != null) SizedBox(width: 300, child: Text(detail.text('price_notes')!, style: context.m24.text.bodySmall))]));
  }
}

class TreatmentDescription extends StatelessWidget {
  const TreatmentDescription({super.key, required this.sections, required this.contraindications, this.requirements, this.outcome});
  final Map<String, dynamic> sections;
  final List<Map<String, dynamic>> contraindications;
  final String? requirements, outcome;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    for (final String key in <String>['per_chi','come_funziona','durata','rischi_e_controindicazioni','evidenze_e_limiti']) if ((sections[key] ?? '').toString().isNotEmpty) Padding(key: ValueKey<String>(key), padding: const EdgeInsets.only(bottom: 16), child: M24Card(tint: key == 'evidenze_e_limiti' ? M24CardTint.primary : M24CardTint.none, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(context.l10n.t('treatmentsSection_$key'), style: context.m24.text.h2), const SizedBox(height: 8), Text(sections[key].toString()), if (key == 'rischi_e_controindicazioni' && contraindications.isNotEmpty) ...<Widget>[const SizedBox(height: 10), Wrap(spacing: 6, runSpacing: 6, children: contraindications.map((item) => M24StatusPill(label: item['text'].toString(), variant: switch (item['severity']) { 'alta' => M24StatusPillVariant.danger, 'media' => M24StatusPillVariant.warning, _ => M24StatusPillVariant.neutral })).toList())]]))),
    if (requirements != null) M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(context.l10n.t('treatmentsRequirements'), style: context.m24.text.h2), Text(requirements!)])), if (outcome != null) Padding(padding: const EdgeInsets.only(top: 16), child: M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(context.l10n.t('treatmentsExpectedOutcome'), style: context.m24.text.h2), Text(outcome!)])))
  ]);
}

class ProviderCard extends StatelessWidget {
  const ProviderCard({super.key, required this.title, required this.data, this.doctor = false});
  final String title;
  final Map<String, dynamic> data;
  final bool doctor;
  @override
  Widget build(BuildContext context) {
    final String name = (data[doctor ? 'display_name' : 'name'] ?? '').toString();
    final List<String> details = doctor ? <String>[if (data['role'] != null) treatmentLabel(context, data['role'].toString()), ...(data['specialties'] as List? ?? const []).map((value) => value.toString()), ...(data['languages'] as List? ?? const []).map((value) => value.toString())] : <String>[if (data['address'] != null) data['address'].toString(), if (data['city'] != null) data['city'].toString(), if (data['phone'] != null) data['phone'].toString(), if (data['website'] != null) data['website'].toString()];
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: context.m24.text.h2), const SizedBox(height: 8), Row(children: <Widget>[Expanded(child: Text(name, style: context.m24.text.title)), if (data['verified'] == true) Icon(M24Icons.verified, color: context.m24.colors.success)]), for (final String value in details) Padding(padding: const EdgeInsets.only(top: 5), child: Text(value, style: context.m24.text.bodySmall)), if (!doctor && data['ssn_accredited'] == true) const Padding(padding: EdgeInsets.only(top: 8), child: Chip(label: Text('SSN')))]));
  }
}

class TreatmentRatingSummary extends StatelessWidget {
  const TreatmentRatingSummary({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) { final Map<String, dynamic> sub = Map<String, dynamic>.from(data['sub_avgs'] as Map? ?? const {}); return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.t('treatmentsRatings'), style: context.m24.text.h2), const SizedBox(height: 8), TreatmentRating(average: (data['rating_avg'] as num?)?.toDouble(), count: (data['rating_count'] as num?)?.toInt() ?? 0), for (final entry in sub.entries) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: <Widget>[SizedBox(width: 110, child: Text(treatmentLabel(context, entry.key))), Expanded(child: LinearProgressIndicator(value: ((entry.value as num?)?.toDouble() ?? 0) / 5)), const SizedBox(width: 8), Text((entry.value as num).toStringAsFixed(1))]))])); }
}

class TreatmentReviews extends ConsumerWidget {
  const TreatmentReviews({super.key, required this.treatmentId});
  final String treatmentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(treatmentReviewsProvider(treatmentId)).when(loading: () => const AppLoadingView(), error: (_, __) => Text(context.l10n.t('treatmentsLoadError')), data: (reviews) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.t('treatmentsReviews'), style: context.m24.text.h2), if (reviews.isEmpty) Text(context.l10n.t('treatmentsNoReviews')) else for (final TreatmentReview review in reviews) Padding(padding: const EdgeInsets.only(top: 10), child: M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Row(children: <Widget>[Expanded(child: Text(review.author, style: context.m24.text.title)), if (review.createdAt != null) TreatmentRelativeDate(date: review.createdAt!)]), if (review.verified) Text(context.l10n.t('treatmentsVerifiedReview'), style: context.m24.text.caption.copyWith(color: context.m24.colors.success)), const SizedBox(height: 5), Text('${'★' * review.rating}${'☆' * (5 - review.rating)}'), if (review.title != null) Text(review.title!, style: context.m24.text.title), Text(review.body)]))) ]));
}