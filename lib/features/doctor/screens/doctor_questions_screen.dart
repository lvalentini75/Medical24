import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/doctor/data/doctor_models.dart';
import 'package:medical24/features/doctor/data/doctor_repository.dart';
import 'package:medical24/features/doctor/providers/doctor_providers.dart';
import 'package:medical24/features/doctor/widgets/doctor_widgets.dart';
import 'package:medical24/l10n/generated/app_localizations.dart';

class DoctorQuestionsScreen extends ConsumerStatefulWidget {
  const DoctorQuestionsScreen({super.key});
  @override
  ConsumerState<DoctorQuestionsScreen> createState() => _DoctorQuestionsScreenState();
}

class _DoctorQuestionsScreenState extends ConsumerState<DoctorQuestionsScreen> {
  DoctorQuestionStatus? filter;
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SectionPage(title: l10n.doctorQuestionsTitle, subtitle: l10n.doctorQuestionsSubtitle, action: M24Button(label: l10n.doctorQuestionNew, icon: M24Icons.plus, onPressed: () => context.push(AppRoutes.doctorQuestionNew)), showDisclaimer: true, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: <Widget>[
        M24FilterChip(label: l10n.doctorQuestionFilterAll, selected: filter == null, onSelected: (_) => setState(() => filter = null)),
        const SizedBox(width: 8),
        for (final DoctorQuestionStatus status in DoctorQuestionStatus.values) ...<Widget>[M24FilterChip(label: _statusLabel(l10n, status), selected: filter == status, onSelected: (_) => setState(() => filter = status)), const SizedBox(width: 8)],
      ])),
      const SizedBox(height: 16), Expanded(child: ref.watch(doctorQuestionsProvider).when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: l10n.doctorQuestionsError, onRetry: () => ref.invalidate(doctorQuestionsProvider)), data: (items) {
        final List<DoctorQuestion> visible = items.where((item) => filter == null || item.status == filter).toList(growable: false);
        if (visible.isEmpty) return AppEmptyView(icon: M24Icons.help, title: l10n.doctorQuestionsEmpty, body: l10n.doctorQuestionsEmptyBody, action: M24Button(label: l10n.doctorQuestionNew, onPressed: () => context.push(AppRoutes.doctorQuestionNew)));
        return ListView.separated(itemCount: visible.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (_, index) => DoctorQuestionCard(question: visible[index], onTap: () => context.push(AppRoutes.doctorQuestion(visible[index].id))));
      })),
    ]));
  }

  String _statusLabel(AppLocalizations l10n, DoctorQuestionStatus status) => switch (status) { DoctorQuestionStatus.draft => l10n.doctorQuestionStatusDraft, DoctorQuestionStatus.sent => l10n.doctorQuestionStatusSent, DoctorQuestionStatus.answered => l10n.doctorQuestionStatusAnswered, DoctorQuestionStatus.closed => l10n.doctorQuestionStatusClosed };
}

class DoctorQuestionFormScreen extends ConsumerStatefulWidget {
  const DoctorQuestionFormScreen({super.key});
  @override
  ConsumerState<DoctorQuestionFormScreen> createState() => _DoctorQuestionFormScreenState();
}

class _DoctorQuestionFormScreenState extends ConsumerState<DoctorQuestionFormScreen> {
  final TextEditingController title = TextEditingController(), body = TextEditingController(), email = TextEditingController();
  String? linkId, error;
  bool saving = false;
  @override
  void initState() { super.initState(); body.addListener(_refresh); }
  void _refresh() => setState(() {});
  @override
  void dispose() { body.removeListener(_refresh); title.dispose(); body.dispose(); email.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SectionPage(title: l10n.doctorQuestionNew, showDisclaimer: true, child: SingleChildScrollView(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      TextField(controller: title, maxLength: 120, decoration: InputDecoration(labelText: l10n.doctorQuestionTitleLabel)), const SizedBox(height: 12),
      TextField(controller: body, maxLength: 4000, minLines: 6, maxLines: 12, decoration: InputDecoration(labelText: l10n.doctorQuestionBodyLabel, counterText: l10n.doctorCharacterCounter(body.text.characters.length, 4000))), const SizedBox(height: 12),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: l10n.doctorQuestionEmailLabel, hintText: l10n.commonOptional)), const SizedBox(height: 12),
      ref.watch(doctorLinksProvider).when(loading: () => const LinearProgressIndicator(), error: (_, __) => const SizedBox.shrink(), data: (links) { final active = links.where((link) => link.status == 'active').toList(); return DropdownButtonFormField<String?>(initialValue: linkId, decoration: InputDecoration(labelText: l10n.doctorQuestionLinkLabel), items: <DropdownMenuItem<String?>>[DropdownMenuItem<String?>(value: null, child: Text(l10n.doctorQuestionNoLink)), ...active.map((link) => DropdownMenuItem<String?>(value: link.id, child: Text(link.code)))], onChanged: (value) => setState(() => linkId = value)); }),
      if (error != null) ...<Widget>[const SizedBox(height: 12), Text(error!, style: context.m24.text.bodySmall.copyWith(color: context.m24.colors.danger))],
      const SizedBox(height: 20), Align(alignment: Alignment.centerLeft, child: M24Button(label: l10n.doctorQuestionSaveDraft, loading: saving, onPressed: _save)),
    ])))));
  }

  Future<void> _save() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) { setState(() => error = l10n.doctorQuestionRequired); return; }
    setState(() { saving = true; error = null; });
    try {
      final String id = await ref.read(doctorRepositoryProvider).createQuestion(title: title.text, body: body.text, shareLinkId: linkId, doctorEmail: email.text.trim().isEmpty ? null : email.text.trim());
      ref.invalidate(doctorQuestionsProvider);
      if (mounted) context.go(AppRoutes.doctorQuestion(id));
    } on DoctorException catch (exception) { if (mounted) setState(() => error = _questionError(l10n, exception.code)); } catch (_) { if (mounted) setState(() => error = l10n.doctorQuestionErrorUnknown); }
    if (mounted) setState(() => saving = false);
  }
}

class DoctorQuestionDetailScreen extends ConsumerWidget {
  const DoctorQuestionDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SectionPage(title: l10n.doctorQuestionDetail, showDisclaimer: true, child: ref.watch(doctorQuestionsProvider).when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: l10n.doctorQuestionsError, onRetry: () => ref.invalidate(doctorQuestionsProvider)), data: (items) {
      final DoctorQuestion? question = items.cast<DoctorQuestion?>().firstWhere((item) => item?.id == id, orElse: () => null);
      if (question == null) return AppEmptyView(icon: M24Icons.help, body: l10n.doctorQuestionMissing);
      return DoctorQuestionDetailContent(question: question);
    }));
  }
}

class DoctorQuestionDetailContent extends ConsumerWidget {
  const DoctorQuestionDetailContent({super.key, required this.question});
  final DoctorQuestion question;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(children: <Widget>[M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Row(children: <Widget>[Expanded(child: Text(question.title, style: context.m24.text.h2)), DoctorQuestionStatusPill(status: question.status)]), const SizedBox(height: 16), Text(question.body, style: context.m24.text.body), if (question.doctorEmail != null) ...<Widget>[const SizedBox(height: 12), Text(l10n.doctorQuestionDoctorEmail(question.doctorEmail!), style: context.m24.text.bodySmall)]])),
      if (question.answer != null) ...<Widget>[const SizedBox(height: 12), M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(l10n.doctorQuestionAnswerTitle, style: context.m24.text.h2), const SizedBox(height: 8), Text(question.answer!, style: context.m24.text.body), const SizedBox(height: 12), Text(question.answeredVia == 'link' ? l10n.doctorAnswerViaLink : l10n.doctorAnswerViaApp, style: context.m24.text.label), if (question.answeredAt != null) DoctorRelativeDate(date: question.answeredAt!)]))],
      const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: _actions(context, ref, l10n)),
    ]);
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, AppLocalizations l10n) => switch (question.status) {
    DoctorQuestionStatus.draft => <Widget>[M24Button(label: l10n.doctorQuestionEdit, variant: M24ButtonVariant.outline, onPressed: () => _edit(context, ref)), M24Button(label: l10n.doctorQuestionSend, onPressed: () => _write(context, ref, () => ref.read(doctorRepositoryProvider).sendQuestion(question.id))), M24Button(label: l10n.doctorQuestionDelete, variant: M24ButtonVariant.destructiveOutline, onPressed: () => _delete(context, ref))],
    DoctorQuestionStatus.sent => <Widget>[M24Button(label: l10n.doctorQuestionRecordAnswer, onPressed: () => _answer(context, ref)), M24Button(label: l10n.doctorQuestionClose, variant: M24ButtonVariant.outline, onPressed: () => _write(context, ref, () => ref.read(doctorRepositoryProvider).closeQuestion(question.id)))],
    DoctorQuestionStatus.answered => <Widget>[M24Button(label: l10n.doctorQuestionClose, variant: M24ButtonVariant.outline, onPressed: () => _write(context, ref, () => ref.read(doctorRepositoryProvider).closeQuestion(question.id)))],
    DoctorQuestionStatus.closed => const <Widget>[],
  };

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context); final title = TextEditingController(text: question.title), body = TextEditingController(text: question.body);
    final bool? save = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text(l10n.doctorQuestionEdit), content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[TextField(controller: title, maxLength: 120, decoration: InputDecoration(labelText: l10n.doctorQuestionTitleLabel)), TextField(controller: body, maxLength: 4000, minLines: 4, maxLines: 8, decoration: InputDecoration(labelText: l10n.doctorQuestionBodyLabel))])), actions: <Widget>[TextButton(onPressed: () => dialogContext.pop(false), child: Text(l10n.commonCancel)), TextButton(onPressed: () => dialogContext.pop(true), child: Text(l10n.commonSave))]));
    if (save == true && context.mounted) await _write(context, ref, () => ref.read(doctorRepositoryProvider).updateQuestion(question.id, title.text, body.text)); title.dispose(); body.dispose();
  }

  Future<void> _answer(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context); final answer = TextEditingController();
    final bool? save = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text(l10n.doctorQuestionRecordAnswer), content: SizedBox(width: 520, child: TextField(controller: answer, maxLength: 8000, minLines: 6, maxLines: 12, decoration: InputDecoration(labelText: l10n.doctorQuestionAnswerLabel))), actions: <Widget>[TextButton(onPressed: () => dialogContext.pop(false), child: Text(l10n.commonCancel)), TextButton(onPressed: () => dialogContext.pop(true), child: Text(l10n.commonSave))]));
    if (save == true && answer.text.trim().isNotEmpty && context.mounted) await _write(context, ref, () => ref.read(doctorRepositoryProvider).recordAnswer(question.id, answer.text)); answer.dispose();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async { final l10n = AppLocalizations.of(context); final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text(l10n.doctorQuestionDeleteConfirm), content: Text(l10n.doctorQuestionDeleteConfirmBody), actions: <Widget>[TextButton(onPressed: () => dialogContext.pop(false), child: Text(l10n.commonCancel)), TextButton(onPressed: () => dialogContext.pop(true), child: Text(l10n.doctorQuestionDelete))])) ?? false; if (confirmed && context.mounted) { await _write(context, ref, () => ref.read(doctorRepositoryProvider).deleteQuestion(question.id)); if (context.mounted) context.go(AppRoutes.doctorQuestions); } }
  Future<void> _write(BuildContext context, WidgetRef ref, Future<void> Function() action) async { final l10n = AppLocalizations.of(context); try { await action(); ref.invalidate(doctorQuestionsProvider); } on DoctorException catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_questionError(l10n, error.code)))); } }
}

String _questionError(AppLocalizations l10n, String code) => switch (code) { 'daily_limit' => l10n.doctorQuestionErrorDailyLimit, 'not_editable' => l10n.doctorQuestionErrorNotEditable, 'not_sendable' => l10n.doctorQuestionErrorNotSendable, 'not_answerable' => l10n.doctorQuestionErrorNotAnswerable, 'invalid_share_link' => l10n.doctorQuestionErrorInvalidLink, _ => l10n.doctorQuestionErrorUnknown };