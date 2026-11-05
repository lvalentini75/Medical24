import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:medical24/core/providers/app_providers.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/features/family/data/family_repository.dart';
import 'package:medical24/features/family/providers/family_providers.dart';
import 'package:medical24/features/family/widgets/family_relationship_field.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Compact entry point for choosing whose health space is visible.
class SubjectSelectorChip extends ConsumerWidget {
  const SubjectSelectorChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FamilySubject? subject = ref.watch(currentSubjectProvider).value;
    if (subject == null) return const SizedBox.shrink();
    final String suffix = subject.relationship == null ? (subject.managed ? AppLocalizations.of(context).subjectManaged : '') : FamilyRelationships.label(AppLocalizations.of(context), subject.relationship!);
    return ActionChip(avatar: const Icon(M24Icons.users, size: 18), label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(suffix.isEmpty ? subject.fullName : '${subject.fullName} · $suffix', overflow: TextOverflow.ellipsis)), onPressed: () => SubjectSelectorSheet.show(context));
  }
}

/// Subject list shared by the desktop top bar and phone Home header.
class SubjectSelectorSheet extends ConsumerWidget {
  const SubjectSelectorSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (BuildContext context) => const SubjectSelectorSheet());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FamilySubject>> subjects = ref.watch(mySubjectsProvider);
    final String? selected = ref.watch(currentSubjectProvider).value?.id;
    return SafeArea(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560), child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(AppLocalizations.of(context).subjectChoose, style: context.m24.text.h2),
      const SizedBox(height: 12),
      Flexible(child: subjects.when(loading: () => const Center(child: CircularProgressIndicator()), error: (_, __) => Center(child: Text(AppLocalizations.of(context).familyLoadError)), data: (List<FamilySubject> items) => ListView(shrinkWrap: true, children: <Widget>[
        for (final FamilySubject item in items) ListTile(leading: Icon(item.managed ? M24Icons.users : M24Icons.profile), title: Text(item.fullName), subtitle: item.relationship != null ? Text(FamilyRelationships.label(AppLocalizations.of(context), item.relationship!)) : item.managed ? Text(AppLocalizations.of(context).subjectManaged) : null, trailing: item.id == selected ? const Icon(M24Icons.confirm) : null, onTap: () async { await ref.read(currentSubjectProvider.notifier).select(item); if (context.mounted) context.pop(); }),
      ]))),
      const Divider(),
      ListTile(leading: const Icon(M24Icons.settings), title: Text(AppLocalizations.of(context).subjectManageFamily), trailing: const Icon(M24Icons.chevronRight), onTap: () { context.pop(); context.push(AppRoutes.settingsFamily); }),
    ]))));
  }
}

/// Persistent notice shown while browsing another subject.
class SubjectContextBanner extends ConsumerWidget {
  const SubjectContextBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FamilySubject? subject = ref.watch(currentSubjectProvider).value;
    final String? uid = ref.watch(sessionProvider)?.user.id;
    if (subject == null || subject.id == uid) return const SizedBox.shrink();
    return Container(width: double.infinity, color: context.m24.colors.primarySoft, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
      Flexible(child: Text(AppLocalizations.of(context).subjectViewing(subject.fullName), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.m24.text.caption.copyWith(color: context.m24.colors.primaryInk))),
      const SizedBox(width: 12),
      TextButton(onPressed: () => ref.read(currentSubjectProvider.notifier).selectSelf(), child: Text(AppLocalizations.of(context).subjectBackToYou)),
    ]));
  }
}