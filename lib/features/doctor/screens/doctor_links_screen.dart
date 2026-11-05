import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/doctor/data/doctor_models.dart';
import 'package:medical24/features/doctor/providers/doctor_providers.dart';
import 'package:medical24/features/doctor/widgets/doctor_widgets.dart';
import 'package:medical24/l10n/generated/app_localizations.dart';

class DoctorLinksScreen extends ConsumerWidget {
  const DoctorLinksScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SectionPage(title: l10n.doctorLinksTitle, action: M24Button(label: l10n.doctorCreateLink, icon: M24Icons.share, onPressed: () => context.push(AppRoutes.doctorShare)), child: ref.watch(doctorLinksProvider).when(
      loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: l10n.doctorLinksError, onRetry: () => ref.invalidate(doctorLinksProvider)),
      data: (links) => links.isEmpty ? AppEmptyView(icon: M24Icons.share, title: l10n.doctorLinksEmpty, body: l10n.doctorLinksEmptyBody, action: M24Button(label: l10n.doctorCreateLink, onPressed: () => context.push(AppRoutes.doctorShare))) : ListView.separated(itemCount: links.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (_, index) => DoctorLinkCard(link: links[index], onTap: () => context.push(AppRoutes.doctorLink(links[index].id)))),
    ));
  }
}

class DoctorLinkDetailScreen extends ConsumerWidget {
  const DoctorLinkDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SectionPage(title: l10n.doctorLinkDetail, showDisclaimer: true, child: ref.watch(doctorLinksProvider).when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: l10n.doctorLinksError, onRetry: () => ref.invalidate(doctorLinksProvider)), data: (links) {
      final DoctorShareLink? link = links.cast<DoctorShareLink?>().firstWhere((item) => item?.id == id, orElse: () => null);
      if (link == null) return AppEmptyView(icon: M24Icons.share, body: l10n.doctorLinkMissing);
      return ListView(children: <Widget>[DoctorLinkCard(link: link, onTap: () {}), const SizedBox(height: 16), M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(l10n.doctorOpenLog, style: context.m24.text.h2), const SizedBox(height: 12), if (link.opens.isEmpty) Text(l10n.doctorNoOpens) else for (final DoctorLinkOpen open in link.opens) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: <Widget>[Expanded(child: DoctorRelativeDate(date: open.openedAt)), Text(_outcome(l10n, open.outcome), style: context.m24.text.label)]))])), if (link.status != 'revoked') ...<Widget>[const SizedBox(height: 16), Align(alignment: Alignment.centerLeft, child: M24Button(label: l10n.doctorRevoke, variant: M24ButtonVariant.destructiveOutline, onPressed: () => _revoke(context, ref, link.id)))]]);
    }));
  }

  String _outcome(AppLocalizations l10n, String value) => switch (value) { 'ok' => l10n.doctorOutcomeOk, 'wrong_pin' => l10n.doctorOutcomeWrongPin, 'locked' => l10n.doctorStatusLocked, 'expired' => l10n.doctorStatusExpired, 'revoked' => l10n.doctorStatusRevoked, 'exhausted' => l10n.doctorStatusExhausted, _ => value };
  Future<void> _revoke(BuildContext context, WidgetRef ref, String linkId) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(l10n.doctorRevokeConfirmTitle), content: Text(l10n.doctorRevokeConfirmBody), actions: <Widget>[TextButton(onPressed: () => context.pop(false), child: Text(l10n.commonCancel)), TextButton(onPressed: () => context.pop(true), child: Text(l10n.doctorRevoke))])) ?? false;
    if (!confirmed) return;
    try { await ref.read(doctorRepositoryProvider).revokeLink(linkId); ref.invalidate(doctorLinksProvider); if (context.mounted) context.pop(); } catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.doctorRevokeError))); }
  }
}