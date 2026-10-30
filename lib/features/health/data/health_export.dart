import 'package:intl/intl.dart';
import 'package:medical24/core/ui/formatters.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/data/health_repository.dart';
import 'package:medical24/features/health/data/health_export_platform.dart';

const List<String> _columns = <String>['code', 'biomarker', 'effective_at', 'value', 'unit', 'lab_low', 'lab_high', 'institutional_low', 'institutional_high', 'doctor_low', 'doctor_high', 'flag', 'origin', 'document_id', 'lab_name'];

Future<void> exportHealthCsv(HealthRepository repository, List<BiomarkerSummary> catalog, {required String locale}) async {
  final List<Map<String, dynamic>> rows = await repository.exportRows();
  final Map<String, BiomarkerSummary> byCode = <String, BiomarkerSummary>{for (final BiomarkerSummary item in catalog) item.code: item};
  final StringBuffer csv = StringBuffer()..writeln(_columns.map(_csv).join(';'));
  for (final Map<String, dynamic> row in rows) {
    final BiomarkerSummary? biomarker = byCode[row['code']?.toString()];
    final String unit = row['unit']?.toString() ?? biomarker?.unit ?? '';
    final Object? rawValue = row['value'];
    final num? value = rawValue is num ? rawValue : num.tryParse(rawValue?.toString() ?? '');
    final List<String> values = <String>[
      row['code']?.toString() ?? '', biomarker?.name(locale) ?? row['code']?.toString() ?? '', row['effective_at']?.toString() ?? '',
      value == null ? '' : formatValue(value, locale: locale), formatUnit(unit), ...<String>[_number(row['lab_low'], locale), _number(row['lab_high'], locale), _number(row['institutional_low'], locale), _number(row['institutional_high'], locale), _number(row['doctor_low'], locale), _number(row['doctor_high'], locale)],
      row['flag']?.toString() ?? '', row['origin']?.toString() ?? '', row['document_id']?.toString() ?? '', row['lab_name']?.toString() ?? '',
    ];
    csv.writeln(values.map(_csv).join(';'));
  }
  final String date = DateFormat('yyyyMMdd').format(DateTime.now());
  await saveHealthCsv(csv.toString(), 'medical24_valori_$date.csv');
}

String _number(Object? value, String locale) { final num? parsed = value is num ? value : num.tryParse(value?.toString() ?? ''); return parsed == null ? '' : formatValue(parsed, locale: locale); }
String _csv(String value) => '"${value.replaceAll('"', '""')}"';