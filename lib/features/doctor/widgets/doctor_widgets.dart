import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/features/doctor/data/doctor_models.dart';
import 'package:medical24/l10n/generated/app_localizations.dart';

class DoctorFeatureCard extends StatelessWidget {
  const DoctorFeatureCard({super.key, required this.icon, required this.title, required this.body, required this.onTap});
  final IconData icon;
  final String title, body;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => M24Card(selectable: true, onTap: onTap, child: Row(children: <Widget>[M24IconTile(icon: icon), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: context.m24.text.h3), const SizedBox(height: 4), Text(body, style: context.m24.text.bodySmall)])), const SizedBox(width: 12), const Icon(M24Icons.chevronRight, size: 20)]));
}

class DoctorLinkStatusPill extends StatelessWidget {
  const DoctorLinkStatusPill({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => M24StatusPill(label: _label(AppLocalizations.of(context)), variant: switch (status) { 'active' => M24StatusPillVariant.success, 'locked' => M24StatusPillVariant.warning, 'revoked' => M24StatusPillVariant.danger, _ => M24StatusPillVariant.neutral });
  String _label(AppLocalizations l10n) => switch (status) { 'active' => l10n.doctorStatusActive, 'expired' => l10n.doctorStatusExpired, 'revoked' => l10n.doctorStatusRevoked, 'locked' => l10n.doctorStatusLocked, 'exhausted' => l10n.doctorStatusExhausted, _ => status };
}

class DoctorRelativeDate extends StatelessWidget {
  const DoctorRelativeDate({super.key, required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Duration difference = DateTime.now().difference(date.toLocal());
    final String relative = difference.inMinutes < 1 ? l10n.doctorRelativeNow : difference.inHours < 1 ? l10n.doctorRelativeMinutes(difference.inMinutes) : difference.inDays < 1 ? l10n.doctorRelativeHours(difference.inHours) : difference.inDays <= 30 ? l10n.doctorRelativeDays(difference.inDays) : DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(date.toLocal());
    return Tooltip(message: DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(date.toLocal()), child: Text(relative));
  }
}

class DoctorLinkCard extends StatelessWidget {
  const DoctorLinkCard({super.key, required this.link, required this.onTap});
  final DoctorShareLink link;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final String expiry = DateFormat.yMMMd(locale).add_Hm().format(link.expiresAt.toLocal());
    return M24Card(selectable: true, onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[Expanded(child: Text(link.code, style: context.m24.text.h3)), DoctorLinkStatusPill(status: link.status)]),
      const SizedBox(height: 12), Text(l10n.doctorLinkExpires(expiry), style: context.m24.text.bodySmall),
      const SizedBox(height: 4), Text(l10n.doctorLinkUsage(link.opensCount, link.maxOpens), style: context.m24.text.bodySmall),
      if (link.lastOpenedAt != null) ...<Widget>[const SizedBox(height: 4), Row(children: <Widget>[Text('${l10n.doctorLastOpen}: ', style: context.m24.text.bodySmall), DoctorRelativeDate(date: link.lastOpenedAt!)])],
    ]));
  }
}

class DoctorQuestionStatusPill extends StatelessWidget {
  const DoctorQuestionStatusPill({super.key, required this.status});
  final DoctorQuestionStatus status;
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String label = switch (status) { DoctorQuestionStatus.draft => l10n.doctorQuestionStatusDraft, DoctorQuestionStatus.sent => l10n.doctorQuestionStatusSent, DoctorQuestionStatus.answered => l10n.doctorQuestionStatusAnswered, DoctorQuestionStatus.closed => l10n.doctorQuestionStatusClosed };
    final M24StatusPillVariant variant = switch (status) { DoctorQuestionStatus.draft => M24StatusPillVariant.neutral, DoctorQuestionStatus.sent => M24StatusPillVariant.info, DoctorQuestionStatus.answered => M24StatusPillVariant.success, DoctorQuestionStatus.closed => M24StatusPillVariant.neutral };
    return M24StatusPill(label: label, variant: variant);
  }
}

class DoctorQuestionCard extends StatelessWidget {
  const DoctorQuestionCard({super.key, required this.question, required this.onTap});
  final DoctorQuestion question;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => M24Card(selectable: true, onTap: onTap, child: Row(children: <Widget>[M24IconTile(icon: M24Icons.help), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(question.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.m24.text.title), const SizedBox(height: 6), DoctorRelativeDate(date: question.updatedAt)])), const SizedBox(width: 12), DoctorQuestionStatusPill(status: question.status), const SizedBox(width: 8), const Icon(M24Icons.chevronRight, size: 20)]));
}