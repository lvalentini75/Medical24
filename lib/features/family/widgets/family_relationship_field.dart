import 'package:flutter/material.dart';

import 'package:medical24/l10n/generated/localization_lookup.dart';

extension FamilyRelationshipLocalizations on AppLocalizations {
  String _relation(String it, String en) => localeName.startsWith('en') ? en : it;
  String get familyRelationChild => _relation('Figlio/figlia', 'Child');
  String get familyRelationParent => _relation('Genitore', 'Parent');
  String get familyRelationPartner => _relation('Coniuge o partner', 'Spouse or partner');
  String get familyRelationSibling => _relation('Fratello/sorella', 'Sibling');
  String get familyRelationGrandparent => _relation('Nonno/nonna', 'Grandparent');
  String get familyRelationGrandchild => _relation('Nipote', 'Grandchild');
  String get familyRelationWard => _relation('Persona assistita', 'Person in your care');
  String get familyRelationOther => _relation('Altro', 'Other');
  String get familyRelationOtherText => _relation('Specifica la relazione', 'Specify the relationship');
}

/// Stable relationship values shared by managed profiles and caregiver invites.
abstract final class FamilyRelationships {
  static const String other = 'other';
  static const List<String> known = <String>['child', 'parent', 'partner', 'sibling', 'grandparent', 'grandchild', 'ward'];

  static bool isKnown(String? value) => value != null && known.contains(value);

  static String label(AppLocalizations l10n, String value) => switch (value) {
    'child' => l10n.familyRelationChild,
    'parent' => l10n.familyRelationParent,
    'partner' => l10n.familyRelationPartner,
    'sibling' => l10n.familyRelationSibling,
    'grandparent' => l10n.familyRelationGrandparent,
    'grandchild' => l10n.familyRelationGrandchild,
    'ward' => l10n.familyRelationWard,
    _ => value,
  };
}

/// Relationship selector with a required free-text field when "Other" is used.
class FamilyRelationshipField extends StatefulWidget {
  const FamilyRelationshipField({super.key, this.initialValue, required this.onChanged});
  final String? initialValue;
  final void Function(String? value, bool valid) onChanged;

  @override
  State<FamilyRelationshipField> createState() => _FamilyRelationshipFieldState();
}

class _FamilyRelationshipFieldState extends State<FamilyRelationshipField> {
  late String? _selection = FamilyRelationships.isKnown(widget.initialValue) ? widget.initialValue : widget.initialValue?.trim().isNotEmpty == true ? FamilyRelationships.other : null;
  late final TextEditingController _custom = TextEditingController(text: _selection == FamilyRelationships.other ? widget.initialValue : null);

  @override
  void dispose() { _custom.dispose(); super.dispose(); }

  void _notify() {
    final String custom = _custom.text.trim();
    widget.onChanged(_selection == FamilyRelationships.other ? (custom.isEmpty ? null : custom) : _selection, _selection != FamilyRelationships.other || custom.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      DropdownButtonFormField<String>(initialValue: _selection, decoration: InputDecoration(labelText: l10n.familyRelationship), items: <DropdownMenuItem<String>>[
        for (final String value in FamilyRelationships.known) DropdownMenuItem<String>(value: value, child: Text(FamilyRelationships.label(l10n, value))),
        DropdownMenuItem<String>(value: FamilyRelationships.other, child: Text(l10n.familyRelationOther)),
      ], onChanged: (String? value) { setState(() => _selection = value); _notify(); }),
      if (_selection == FamilyRelationships.other) ...<Widget>[
        const SizedBox(height: 12),
        TextFormField(controller: _custom, maxLength: 60, autofocus: widget.initialValue == null, decoration: InputDecoration(labelText: l10n.familyRelationOtherText, errorText: _custom.text.trim().isEmpty ? l10n.commonRequired : null), onChanged: (_) { setState(() {}); _notify(); }),
      ],
    ]);
  }
}