import 'package:intl/intl.dart';

/// Converts catalog UCUM units to the notation normally printed on reports.
String formatUnit(String unit) => switch (unit.trim()) {
  '10*3/uL' || '10^3/uL' => '×10³/µL',
  '10*6/uL' || '10^6/uL' => '×10⁶/µL',
  '10*9/L' || '10^9/L' || 'x109/L' => '×10⁹/L',
  '10*12/L' || '10^12/L' => '×10¹²/L',
  'uL' => 'µL',
  'umol/L' => 'µmol/L',
  'ug/L' => 'µg/L',
  'ug/dL' => 'µg/dL',
  'mm[Hg]' => 'mmHg',
  'Cel' => '°C',
  '/min' => 'bpm',
  _ => unit,
};

/// Formats a measurement using the report value when available and at most two decimals.
String formatValue(num value, {num? rawValue, required String locale, bool signed = false}) {
  final num displayed = rawValue ?? value;
  final String plain = displayed.toString();
  final int decimalIndex = plain.indexOf('.');
  final int decimals = decimalIndex < 0 ? 0 : (plain.length - decimalIndex - 1).clamp(0, 2);
  final NumberFormat formatter = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: decimals);
  return '${signed && displayed >= 0 ? '+' : ''}${formatter.format(displayed)}';
}

String formatMeasurement(num value, String unit, {num? rawValue, required String locale, bool signed = false}) {
  final String formattedUnit = formatUnit(unit);
  return '${formatValue(value, rawValue: rawValue, locale: locale, signed: signed)}${formattedUnit.isEmpty ? '' : ' $formattedUnit'}';
}

String formatRange(num? low, num? high, String unit, {required String locale}) {
  final String left = low == null ? '–' : formatValue(low, rawValue: low, locale: locale);
  final String right = high == null ? '–' : formatValue(high, rawValue: high, locale: locale);
  final String formattedUnit = formatUnit(unit);
  return '$left – $right${formattedUnit.isEmpty ? '' : ' $formattedUnit'}';
}