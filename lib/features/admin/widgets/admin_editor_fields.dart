import 'package:flutter/material.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/features/admin/data/admin_models.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Edits a list of free-form values as removable chips.
class AdminChipInput extends StatefulWidget {
  const AdminChipInput({super.key, required this.label, required this.values, required this.onChanged});
  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  @override State<AdminChipInput> createState() => _AdminChipInputState();
}

class _AdminChipInputState extends State<AdminChipInput> {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  @override void dispose() { controller.dispose(); focusNode.dispose(); super.dispose(); }
  void add() { final value = controller.text.trim(); if (value.isEmpty || widget.values.contains(value)) return; widget.onChanged(<String>[...widget.values, value]); controller.clear(); }
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    TextField(controller: controller, focusNode: focusNode, decoration: InputDecoration(labelText: widget.label, suffixIcon: IconButton(icon: const Icon(M24Icons.plus), tooltip: context.l10n.commonAdd, onPressed: add)), onSubmitted: (_) => add()),
    if (widget.values.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 8, runSpacing: 8, children: widget.values.map((value) => InputChip(label: Text(value), onDeleted: () => widget.onChanged(widget.values.where((item) => item != value).toList()))).toList()))
  ]);
}

/// Structured contraindication rows serialized by the parent as JSON objects.
class AdminContraindicationsEditor extends StatelessWidget {
  const AdminContraindicationsEditor({super.key, required this.rows, required this.onChanged});
  final List<Map<String, dynamic>> rows;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    for (int index = 0; index < rows.length; index++) Padding(key: ValueKey<String>('contraindication-$index'), padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Expanded(child: TextFormField(initialValue: '${rows[index]['text'] ?? ''}', decoration: InputDecoration(labelText: context.l10n.adminContraindicationText), validator: (value) => (value ?? '').trim().isEmpty ? context.l10n.commonRequired : null, onChanged: (value) => _update(index, 'text', value))),
      const SizedBox(width: 10), SizedBox(width: 170, child: DropdownButtonFormField<String>(value: '${rows[index]['severity'] ?? 'bassa'}', decoration: InputDecoration(labelText: context.l10n.adminSeverity), items: const <String>['bassa','media','alta'].map((value) => DropdownMenuItem<String>(value: value, child: Text(context.l10n.adminValueLabel(value)))).toList(), onChanged: (value) => _update(index, 'severity', value))),
      IconButton(key: ValueKey<String>('remove-contraindication-$index'), tooltip: context.l10n.adminRemoveRow, icon: const Icon(M24Icons.delete), onPressed: () => onChanged(<Map<String, dynamic>>[...rows]..removeAt(index)))
    ])),
    Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('add-contraindication'), onPressed: () => onChanged(<Map<String, dynamic>>[...rows, <String, dynamic>{'text':'','severity':'bassa'}]), icon: const Icon(M24Icons.plus), label: Text(context.l10n.commonAdd)))
  ]);
  void _update(int index, String key, dynamic value) { final next = rows.map((row) => Map<String, dynamic>.from(row)).toList(); next[index][key] = value; onChanged(next); }
}

/// Structured treatment media rows with URL validation and image preview.
class AdminMediaEditor extends StatelessWidget {
  const AdminMediaEditor({super.key, required this.rows, required this.onChanged});
  final List<Map<String, dynamic>> rows;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    for (int index = 0; index < rows.length; index++) Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      SizedBox(width: 130, child: DropdownButtonFormField<String>(value: '${rows[index]['type'] ?? 'image'}', decoration: InputDecoration(labelText: context.l10n.adminMediaType), items: <String>['image','video'].map((value) => DropdownMenuItem<String>(value: value, child: Text(context.l10n.adminValueLabel(value)))).toList(), onChanged: (value) => _update(index, 'type', value))), const SizedBox(width: 10),
      Expanded(flex: 3, child: TextFormField(initialValue: '${rows[index]['url'] ?? ''}', decoration: InputDecoration(labelText: context.l10n.adminUrl), validator: _urlValidator(context), onChanged: (value) => _update(index, 'url', value))), const SizedBox(width: 10),
      Expanded(flex: 2, child: TextFormField(initialValue: '${rows[index]['caption'] ?? ''}', decoration: InputDecoration(labelText: context.l10n.adminCaption), onChanged: (value) => _update(index, 'caption', value))),
      if (rows[index]['type'] == 'image' && _validUrl('${rows[index]['url'] ?? ''}')) Padding(padding: const EdgeInsets.only(left: 10), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('${rows[index]['url']}', width: 72, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 72, height: 56, child: Icon(M24Icons.treatments))))),
      IconButton(tooltip: context.l10n.adminRemoveRow, icon: const Icon(M24Icons.delete), onPressed: () => onChanged(<Map<String, dynamic>>[...rows]..removeAt(index)))
    ])),
    Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => onChanged(<Map<String, dynamic>>[...rows, <String, dynamic>{'type':'image','url':'','caption':''}]), icon: const Icon(M24Icons.plus), label: Text(context.l10n.commonAdd)))
  ]);
  FormFieldValidator<String> _urlValidator(BuildContext context) => (value) => _validUrl(value ?? '') ? null : context.l10n.adminInvalidUrl;
  static bool _validUrl(String value) { final uri = Uri.tryParse(value); return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty; }
  void _update(int index, String key, dynamic value) { final next = rows.map((row) => Map<String, dynamic>.from(row)).toList(); next[index][key] = value; onChanged(next); }
}

/// Searchable multi-select grouped by treatment tag kind.
class AdminTagSelector extends StatefulWidget {
  const AdminTagSelector({super.key, required this.tags, required this.selected, required this.onChanged});
  final List<AdminTreatmentTag> tags;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  @override State<AdminTagSelector> createState() => _AdminTagSelectorState();
}

class _AdminTagSelectorState extends State<AdminTagSelector> {
  String query = '';
  @override Widget build(BuildContext context) {
    final groups = <String, List<AdminTreatmentTag>>{};
    final english = Localizations.localeOf(context).languageCode == 'en';
    for (final tag in widget.tags.where((tag) => tag.label(english).toLowerCase().contains(query.toLowerCase()))) (groups[tag.type] ??= <AdminTreatmentTag>[]).add(tag);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      TextField(key: const Key('admin-tag-search'), decoration: InputDecoration(labelText: context.l10n.adminSearchTags, prefixIcon: const Icon(M24Icons.search)), onChanged: (value) => setState(() => query = value)),
      for (final group in groups.entries) Padding(padding: const EdgeInsets.only(top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(context.l10n.adminValueLabel(group.key), style: context.m24.text.label), const SizedBox(height: 6), Wrap(spacing: 8, runSpacing: 8, children: group.value.map((tag) => FilterChip(key: ValueKey<String>('tag-${tag.id}'), label: Text(tag.label(english)), selected: widget.selected.contains(tag.id), onSelected: (selected) { final next = Set<String>.from(widget.selected); selected ? next.add(tag.id) : next.remove(tag.id); widget.onChanged(next); })).toList())]))
    ]);
  }
}