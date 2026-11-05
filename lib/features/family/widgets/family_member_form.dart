import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:medical24/features/family/data/family_repository.dart';
import 'package:medical24/features/family/widgets/family_relationship_field.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Validated form used to create and edit a managed profile.
class FamilyMemberFormSheet extends StatefulWidget {
  const FamilyMemberFormSheet({super.key, this.initial});
  final FamilySubject? initial;

  static Future<ManagedMemberInput?> show(BuildContext context, {FamilySubject? initial}) => showModalBottomSheet<ManagedMemberInput>(context: context, isScrollControlled: true, showDragHandle: true, builder: (BuildContext context) => FamilyMemberFormSheet(initial: initial));

  @override
  State<FamilyMemberFormSheet> createState() => _FamilyMemberFormSheetState();
}

class _FamilyMemberFormSheetState extends State<FamilyMemberFormSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initial?.fullName);
  String? _relationship;
  late bool _relationshipValid = widget.initial?.relationship?.trim().isNotEmpty != false;
  DateTime? _birthDate;
  String? _gender;
  bool _declarationAccepted = false;

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom), child: SingleChildScrollView(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(widget.initial == null ? l10n.familyAddProfile : l10n.familyEditProfile, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      TextField(controller: _name, maxLength: 120, decoration: InputDecoration(labelText: l10n.familyFullName), onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      OutlinedButton.icon(icon: const Icon(M24Icons.calendar), label: Text(_birthDate == null ? l10n.familyBirthDate : MaterialLocalizations.of(context).formatMediumDate(_birthDate!)), onPressed: () async { final DateTime? value = await showDatePicker(context: context, firstDate: DateTime(1900), lastDate: DateTime.now(), initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 30))); if (value != null) setState(() => _birthDate = value); }),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: _gender, decoration: InputDecoration(labelText: l10n.familyGender), items: <DropdownMenuItem<String>>[DropdownMenuItem(value: 'female', child: Text(l10n.familyGenderFemale)), DropdownMenuItem(value: 'male', child: Text(l10n.familyGenderMale)), DropdownMenuItem(value: 'other', child: Text(l10n.familyGenderOther)), DropdownMenuItem(value: 'undisclosed', child: Text(l10n.familyGenderUndisclosed))], onChanged: (String? value) => setState(() => _gender = value)),
      const SizedBox(height: 12),
      FamilyRelationshipField(initialValue: widget.initial?.relationship, onChanged: (String? value, bool valid) => setState(() { _relationship = value; _relationshipValid = valid; })),
      if (widget.initial == null) ...<Widget>[
        CheckboxListTile(value: _declarationAccepted, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: Text(l10n.familyDeclarationText), onChanged: (bool? value) => setState(() => _declarationAccepted = value ?? false)),
        Padding(padding: const EdgeInsets.only(left: 16), child: Text(l10n.familyDeclarationVersion, style: Theme.of(context).textTheme.bodySmall)),
      ],
      const SizedBox(height: 16),
      FilledButton(onPressed: _name.text.trim().isEmpty || !_relationshipValid || widget.initial == null && !_declarationAccepted ? null : () { final String name = _name.text.trim(); context.pop(ManagedMemberInput(fullName: name, birthDate: _birthDate, gender: _gender, relationship: _relationship ?? widget.initial?.relationship)); }, child: Text(l10n.commonSave)),
    ])))));
  }
}