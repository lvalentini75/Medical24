import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:medical24/core/providers/app_providers.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/family/data/family_repository.dart';
import 'package:medical24/features/family/providers/family_providers.dart';
import 'package:medical24/features/family/widgets/family_member_form.dart';
import 'package:medical24/features/family/widgets/family_relationship_field.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FamilySubject>> subjects = ref.watch(mySubjectsProvider);
    final AsyncValue<List<FamilyInvitation>> invitations = ref.watch(pendingInvitationsProvider);
    final AsyncValue<List<FamilyDelegate>> delegates = ref.watch(familyDelegatesProvider);
    final int? limit = ref.watch(familyManagedLimitProvider).value;
    final String? uid = ref.watch(sessionProvider)?.user.id;
    return Scaffold(appBar: AppBar(title: Text(AppLocalizations.of(context).familyTitle)), body: subjects.when(
      loading: () => const AppLoadingView(),
      error: (_, __) => AppErrorView(message: AppLocalizations.of(context).familyLoadError, onRetry: () => _refresh(ref)),
      data: (List<FamilySubject> items) {
        final List<FamilySubject> managed = items.where((FamilySubject item) => item.id != uid && item.managed && item.role == 'owner').toList();
        final List<FamilySubject> followed = items.where((FamilySubject item) => item.id != uid && (!item.managed || item.role != 'owner')).toList();
        return RefreshIndicator(onRefresh: () async { _refresh(ref); await ref.read(mySubjectsProvider.future); }, child: ListView(padding: EdgeInsets.all(MediaQuery.sizeOf(context).width >= 1200 ? 32 : MediaQuery.sizeOf(context).width >= 600 ? 24 : 16), children: <Widget>[
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            FamilySectionHeader(title: AppLocalizations.of(context).familyManagedProfiles, subtitle: AppLocalizations.of(context).familyManagedCount(managed.length, limit ?? 0), action: M24Button(label: AppLocalizations.of(context).familyAddProfile, icon: M24Icons.plus, size: M24ButtonSize.small, onPressed: limit != null && managed.length >= limit ? null : () => _editMember(context, ref))),
            FamilySubjectList(subjects: managed, emptyText: AppLocalizations.of(context).familyManagedEmpty, onEdit: (FamilySubject item) => _editMember(context, ref, item), onRemove: (FamilySubject item) => _removeMember(context, ref, item), onInvite: (FamilySubject item) => _invite(context, ref, item.id)),
            const SizedBox(height: 24),
            FamilySectionHeader(title: AppLocalizations.of(context).familyWhoCanSee),
            delegates.when(loading: () => const LinearProgressIndicator(), error: (_, __) => Text(AppLocalizations.of(context).familyLoadError), data: (List<FamilyDelegate> rows) => FamilyDelegateList(delegates: rows.where((FamilyDelegate row) => row.subjectId == uid && row.role != 'owner' && row.status != 'revoked').toList(), emptyText: AppLocalizations.of(context).familyDelegatesEmpty, onRevoke: (FamilyDelegate row) => _revoke(context, ref, row.id))),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: M24Button(label: AppLocalizations.of(context).familyInviteByEmail, icon: M24Icons.plus, variant: M24ButtonVariant.outlinePrimary, size: M24ButtonSize.small, onPressed: uid == null ? null : () => _invite(context, ref, uid))),
            const SizedBox(height: 24),
            FamilySectionHeader(title: AppLocalizations.of(context).familyReceivedInvites),
            invitations.when(loading: () => const LinearProgressIndicator(), error: (_, __) => Text(AppLocalizations.of(context).familyLoadError), data: (List<FamilyInvitation> rows) => FamilyInvitationList(invitations: rows, onAccept: (FamilyInvitation item) => _accept(context, ref, item.id), onReject: (FamilyInvitation item) => _revoke(context, ref, item.id))),
            const SizedBox(height: 24),
            FamilySectionHeader(title: AppLocalizations.of(context).familyFollowing),
            FamilySubjectList(subjects: followed, emptyText: AppLocalizations.of(context).familyFollowingEmpty, onStopFollowing: (FamilySubject item) { final FamilyDelegate? row = delegates.value?.where((FamilyDelegate value) => value.subjectId == item.id && value.userId == uid && value.status == 'active').firstOrNull; if (row != null) _revoke(context, ref, row.id); }),
          ]))),
        ]));
      },
    ));
  }

  static void _refresh(WidgetRef ref) { ref.invalidate(mySubjectsProvider); ref.invalidate(pendingInvitationsProvider); ref.invalidate(familyDelegatesProvider); ref.invalidate(familyManagedLimitProvider); }
  static String _message(BuildContext context, Object error) { final String code = error is FamilyFailure ? error.code : 'server_error'; final AppLocalizations l = AppLocalizations.of(context); return <String, String>{'managed_limit': l.familyErrorManagedLimit, 'too_many_delegates': l.familyErrorTooManyDelegates, 'already_invited': l.familyErrorAlreadyInvited, 'not_invited': l.familyErrorNotInvited, 'declaration_required': l.familyErrorDeclarationRequired}[code] ?? l.familySaveError; }
  static Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async { try { await action(); _refresh(ref); } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(context, error)))); } }
  static Future<void> _editMember(BuildContext context, WidgetRef ref, [FamilySubject? member]) async { final ManagedMemberInput? input = await FamilyMemberFormSheet.show(context, initial: member); if (input == null || !context.mounted) return; await _run(context, ref, () async { if (member == null) { await ref.read(familyRepositoryProvider).createMember(input); } else { await ref.read(familyRepositoryProvider).updateMember(member.id, input); } }); }
  static Future<void> _removeMember(BuildContext context, WidgetRef ref, FamilySubject member) async { final bool? ok = await showDialog<bool>(context: context, builder: (BuildContext dialogContext) => AlertDialog(title: Text(AppLocalizations.of(context).familyRemoveTitle), content: Text(AppLocalizations.of(context).familyRemoveBody(member.fullName)), actions: <Widget>[TextButton(onPressed: () => dialogContext.pop(false), child: Text(AppLocalizations.of(context).commonCancel)), FilledButton(onPressed: () => dialogContext.pop(true), child: Text(AppLocalizations.of(context).familyRemove))])); if (ok == true && context.mounted) await _performRemove(context, ref, member); }
  static Future<void> _performRemove(BuildContext context, WidgetRef ref, FamilySubject member) async {
    try {
      await ref.read(familyRepositoryProvider).removeMember(member.id);
      final bool wasCurrent = ref.read(currentSubjectProvider).value?.id == member.id;
      _refresh(ref);
      if (wasCurrent) { ref.invalidate(mySubjectsProvider); await ref.read(currentSubjectProvider.notifier).selectSelf(); }
    } catch (error) {
      if (!context.mounted) return;
      if (error is FamilyFailure && error.status == 500 && error.code == 'storage_purge_failed') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).familyStoragePurgeFailed), duration: const Duration(seconds: 10), action: SnackBarAction(label: AppLocalizations.of(context).commonRetry, onPressed: () => _performRemove(context, ref, member))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(context, error))));
      }
    }
  }
  static Future<void> _invite(BuildContext context, WidgetRef ref, String subjectId) async { final CaregiverInviteInput? value = await showDialog<CaregiverInviteInput>(context: context, builder: (BuildContext dialogContext) => const FamilyCaregiverInviteDialog()); if (value != null && context.mounted) await _run(context, ref, () => ref.read(familyRepositoryProvider).invite(subjectId, value)); }
  static Future<void> _accept(BuildContext context, WidgetRef ref, String id) => _run(context, ref, () => ref.read(familyRepositoryProvider).accept(id));
  static Future<void> _revoke(BuildContext context, WidgetRef ref, String id) => _run(context, ref, () => ref.read(familyRepositoryProvider).revoke(id));
}

class FamilySectionHeader extends StatelessWidget {
  const FamilySectionHeader({super.key, required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: <Widget>[Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: context.m24.text.h2), if (subtitle != null) Text(subtitle!, style: context.m24.text.bodySmall)])), if (action != null) action!]));
}

class FamilySubjectList extends StatelessWidget {
  const FamilySubjectList({super.key, required this.subjects, required this.emptyText, this.onEdit, this.onRemove, this.onInvite, this.onStopFollowing});
  final List<FamilySubject> subjects;
  final String emptyText;
  final ValueChanged<FamilySubject>? onEdit, onRemove, onInvite, onStopFollowing;
  @override
  Widget build(BuildContext context) => subjects.isEmpty ? M24Card(child: Text(emptyText, style: context.m24.text.bodySmall)) : Column(children: <Widget>[for (final FamilySubject item in subjects) Padding(padding: const EdgeInsets.only(bottom: 8), child: M24Card(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: <Widget>[const M24IconTile(icon: M24Icons.users, small: true), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(item.fullName, style: context.m24.text.title), if (item.relationship != null) Text(FamilyRelationships.label(AppLocalizations.of(context), item.relationship!), style: context.m24.text.bodySmall)])), if (onInvite != null) IconButton(tooltip: AppLocalizations.of(context).familyInviteCaregiver, onPressed: () => onInvite!(item), icon: const Icon(M24Icons.plus)), if (onEdit != null) IconButton(tooltip: AppLocalizations.of(context).familyEditProfile, onPressed: () => onEdit!(item), icon: const Icon(M24Icons.settings)), if (onRemove != null) IconButton(tooltip: AppLocalizations.of(context).familyRemove, onPressed: () => onRemove!(item), icon: const Icon(M24Icons.delete)), if (onStopFollowing != null) TextButton(onPressed: () => onStopFollowing!(item), child: Text(AppLocalizations.of(context).familyStopFollowing))])))]);
}

class FamilyDelegateList extends StatelessWidget {
  const FamilyDelegateList({super.key, required this.delegates, required this.emptyText, required this.onRevoke});
  final List<FamilyDelegate> delegates;
  final String emptyText;
  final ValueChanged<FamilyDelegate> onRevoke;
  @override
  Widget build(BuildContext context) => delegates.isEmpty ? M24Card(child: Text(emptyText)) : Column(children: <Widget>[for (final FamilyDelegate item in delegates) ListTile(title: Text(item.email ?? AppLocalizations.of(context).familyCaregiver), subtitle: Text(<String>[item.status == 'active' ? AppLocalizations.of(context).familyStatusActive : AppLocalizations.of(context).familyStatusInvited, if (item.relationship != null) FamilyRelationships.label(AppLocalizations.of(context), item.relationship!)].join(' · ')), trailing: TextButton(onPressed: () => onRevoke(item), child: Text(AppLocalizations.of(context).familyRevoke))) ]);
}

class FamilyInvitationList extends StatelessWidget {
  const FamilyInvitationList({super.key, required this.invitations, required this.onAccept, required this.onReject});
  final List<FamilyInvitation> invitations;
  final ValueChanged<FamilyInvitation> onAccept, onReject;
  @override
  Widget build(BuildContext context) => invitations.isEmpty ? M24Card(child: Text(AppLocalizations.of(context).familyInvitesEmpty)) : Column(children: <Widget>[for (final FamilyInvitation item in invitations) ListTile(title: Text(item.subjectName), subtitle: Text(<String>[if (item.relationship != null) FamilyRelationships.label(AppLocalizations.of(context), item.relationship!), if (item.invitedBy != null) AppLocalizations.of(context).familyInvitedBy(item.invitedBy!)].join(' · ')), trailing: Wrap(children: <Widget>[TextButton(onPressed: () => onReject(item), child: Text(AppLocalizations.of(context).familyReject)), FilledButton(onPressed: () => onAccept(item), child: Text(AppLocalizations.of(context).familyAccept))]))]);
}

class FamilyCaregiverInviteDialog extends StatefulWidget {
  const FamilyCaregiverInviteDialog({super.key});
  @override
  State<FamilyCaregiverInviteDialog> createState() => _FamilyCaregiverInviteDialogState();
}

class _FamilyCaregiverInviteDialogState extends State<FamilyCaregiverInviteDialog> {
  final TextEditingController _email = TextEditingController();
  String? _relationship;
  bool _relationshipValid = true;

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(AppLocalizations.of(context).familyInviteByEmail), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
    TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: AppLocalizations.of(context).familyEmail), onChanged: (_) => setState(() {})),
    const SizedBox(height: 12),
    FamilyRelationshipField(onChanged: (String? value, bool valid) => setState(() { _relationship = value; _relationshipValid = valid; })),
  ])), actions: <Widget>[
    TextButton(onPressed: () => context.pop(), child: Text(AppLocalizations.of(context).commonCancel)),
    FilledButton(onPressed: _email.text.trim().isEmpty || !_relationshipValid ? null : () => context.pop(CaregiverInviteInput(email: _email.text.trim(), relationship: _relationship)), child: Text(AppLocalizations.of(context).familyInvite)),
  ]);
}