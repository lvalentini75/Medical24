import 'package:flutter/material.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/features/admin/data/admin_models.dart';
import 'package:medical24/features/admin/widgets/admin_editor_fields.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Structured editor for a professional or facility RPC payload.
class AdminProviderForm extends StatefulWidget {
  const AdminProviderForm({super.key, required this.type, this.data, this.facilities = const <AdminFacility>[], required this.onSave});
  final String type;
  final Map<String, dynamic>? data;
  final List<AdminFacility> facilities;
  final Future<void> Function(Map<String, dynamic>) onSave;
  @override State<AdminProviderForm> createState() => _AdminProviderFormState();
}

class _AdminProviderFormState extends State<AdminProviderForm> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, dynamic> data = widget.data ?? <String, dynamic>{};
  late final Map<String, TextEditingController> fields = <String, TextEditingController>{for (final key in <String>['display_name','registry_body','registry_number','bio','photo_url','name','address','city','region','country','lat','lng','phone','email','website','photo']) key: TextEditingController(text: _initial(key))};
  late String role = '${data['role'] ?? 'medico'}', kind = '${data['kind'] ?? 'altro'}';
  late String? facilityId = data['facility_id']?.toString();
  late bool verified = data['verified'] == true, ssn = data['ssn_accredited'] == true;
  late List<String> specialties = _strings(data['specialties']), languages = _strings(data['languages']), services = _strings(data['services']);
  late List<MapEntry<String, String>> hours = (data['opening_hours'] is Map ? Map<String, dynamic>.from(data['opening_hours'] as Map) : <String, dynamic>{}).entries.map((entry) => MapEntry(entry.key, '${entry.value}')).toList();
  bool get doctor => widget.type == 'doctor';
  String _initial(String key) { if (key == 'photo') return _strings(data['photos']).firstOrNull ?? ''; return '${data[key] ?? (key == 'country' ? 'IT' : '')}'; }
  @override void dispose() { for (final controller in fields.values) controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Form(key: formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Text(doctor ? context.l10n.adminProfessional : context.l10n.adminFacility, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 16),
    if (doctor) ..._doctorFields(context) else ..._facilityFields(context),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.adminVerified), value: verified, onChanged: (value) => setState(() => verified = value)),
    M24Button(label: context.l10n.commonSave, onPressed: _save)
  ]));
  List<Widget> _doctorFields(BuildContext context) => <Widget>[
    _text('display_name', context.l10n.adminDisplayName, required: true),
    DropdownButtonFormField<String>(value: role, decoration: InputDecoration(labelText: context.l10n.adminRole), items: const <String>['medico','medico_dietologo','dietista','biologo_nutrizionista','fisioterapista','altro'].map((value) => DropdownMenuItem<String>(value: value, child: Text(context.l10n.adminValueLabel(value)))).toList(), onChanged: (value) => setState(() => role = value!)),
    AdminChipInput(label: context.l10n.adminSpecialties, values: specialties, onChanged: (value) => setState(() => specialties = value)),
    AdminChipInput(label: context.l10n.adminLanguages, values: languages, onChanged: (value) => setState(() => languages = value)),
    _text('registry_body', context.l10n.adminRegistryBody), _text('registry_number', context.l10n.adminRegistryNumber), _text('bio', context.l10n.adminBio, lines: 4), _text('photo_url', context.l10n.adminPhotoUrl, url: true),
    DropdownMenu<String>(expandedInsets: EdgeInsets.zero, enableFilter: true, enableSearch: true, initialSelection: facilityId, label: Text(context.l10n.adminFacility), dropdownMenuEntries: widget.facilities.map((facility) => DropdownMenuEntry<String>(value: facility.id!, label: facility.name)).toList(), onSelected: (value) => facilityId = value)
  ];
  List<Widget> _facilityFields(BuildContext context) => <Widget>[
    _text('name', context.l10n.adminName, required: true),
    DropdownButtonFormField<String>(value: kind, decoration: InputDecoration(labelText: context.l10n.adminType), items: const <String>['ospedale','clinica','poliambulatorio','studio','centro_riabilitazione','farmacia','altro'].map((value) => DropdownMenuItem<String>(value: value, child: Text(context.l10n.adminValueLabel(value)))).toList(), onChanged: (value) => setState(() => kind = value!)),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.adminSsnAccredited), value: ssn, onChanged: (value) => setState(() => ssn = value)),
    _text('address', context.l10n.adminAddress), _text('city', context.l10n.adminCity), _text('region', context.l10n.adminRegion), _text('country', context.l10n.adminCountry),
    Row(children: <Widget>[Expanded(child: _text('lat', context.l10n.adminLatitude, number: true)), const SizedBox(width: 10), Expanded(child: _text('lng', context.l10n.adminLongitude, number: true))]),
    _text('phone', context.l10n.adminPhone), _text('email', context.l10n.adminEmail), _text('website', context.l10n.adminWebsite, url: true),
    AdminChipInput(label: context.l10n.adminServices, values: services, onChanged: (value) => setState(() => services = value)),
    AdminOpeningHoursEditor(rows: hours, onChanged: (value) => setState(() => hours = value)), _text('photo', context.l10n.adminPhotoUrl, url: true)
  ];
  Widget _text(String key, String label, {bool required = false, bool number = false, bool url = false, int lines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: fields[key], minLines: lines, maxLines: lines == 1 ? 1 : 8, keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null, decoration: InputDecoration(labelText: label), validator: (value) { if (required && (value ?? '').trim().isEmpty) return context.l10n.commonRequired; if (number && (value ?? '').trim().isNotEmpty && double.tryParse(value!) == null) return context.l10n.adminInvalidNumber; if (url && (value ?? '').trim().isNotEmpty) { final uri = Uri.tryParse(value!.trim()); if (uri == null || !<String>['http','https'].contains(uri.scheme) || uri.host.isEmpty) return context.l10n.adminInvalidUrl; } return null; }));
  Future<void> _save() async { if (!formKey.currentState!.validate()) return; final payload = doctor ? <String,dynamic>{'display_name':_value('display_name'),'role':role,'specialties':specialties,'languages':languages,'registry_body':_value('registry_body'),'registry_number':_value('registry_number'),'verified':verified,'bio':_value('bio'),'photo_url':_value('photo_url'),'facility_id':facilityId} : <String,dynamic>{'name':_value('name'),'kind':kind,'ssn_accredited':ssn,'address':_value('address'),'city':_value('city'),'region':_value('region'),'country':_value('country'),'lat':_number('lat'),'lng':_number('lng'),'phone':_value('phone'),'email':_value('email'),'website':_value('website'),'services':services,'opening_hours':<String,String>{for (final row in hours) if (row.key.trim().isNotEmpty) row.key.trim():row.value.trim()},'photos':_value('photo') == null ? <String>[] : <String>[_value('photo')!],'verified':verified}; if (data['id'] != null) payload['id'] = data['id']; if (data['is_demo'] != null) payload['is_demo'] = data['is_demo']; await widget.onSave(payload); }
  String? _value(String key) => fields[key]!.text.trim().isEmpty ? null : fields[key]!.text.trim();
  double? _number(String key) => double.tryParse(fields[key]!.text.trim());
  static List<String> _strings(dynamic value) => (value as List? ?? const <dynamic>[]).map((item) => '$item').toList();
}

/// Day-to-time-range rows serialized as the facility opening_hours object.
class AdminOpeningHoursEditor extends StatelessWidget {
  const AdminOpeningHoursEditor({super.key, required this.rows, required this.onChanged});
  final List<MapEntry<String, String>> rows;
  final ValueChanged<List<MapEntry<String, String>>> onChanged;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Text(context.l10n.adminOpeningHours),
    for (int index = 0; index < rows.length; index++) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: <Widget>[Expanded(child: TextFormField(initialValue: rows[index].key, decoration: InputDecoration(labelText: context.l10n.adminDay), onChanged: (value) => _update(index, key: value))), const SizedBox(width: 8), Expanded(child: TextFormField(initialValue: rows[index].value, decoration: InputDecoration(labelText: context.l10n.adminTimeRange), onChanged: (value) => _update(index, value: value))), IconButton(icon: const Icon(Icons.delete_outline), tooltip: context.l10n.adminRemoveRow, onPressed: () => onChanged(<MapEntry<String,String>>[...rows]..removeAt(index)))])),
    Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => onChanged(<MapEntry<String,String>>[...rows, const MapEntry<String,String>('','')]), icon: const Icon(Icons.add), label: Text(context.l10n.commonAdd)))
  ]));
  void _update(int index, {String? key, String? value}) { final next = <MapEntry<String,String>>[...rows]; next[index] = MapEntry(key ?? rows[index].key, value ?? rows[index].value); onChanged(next); }
}