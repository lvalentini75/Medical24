import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/core/ui/formatters.dart';

void main() {
  test('formatUnit renders report notation in ten representative cases', () {
    const Map<String, String> cases = <String, String>{
      '10*3/uL': '×10³/µL',
      '10*6/uL': '×10⁶/µL',
      '10*9/L': '×10⁹/L',
      'x109/L': '×10⁹/L',
      '10*12/L': '×10¹²/L',
      'uL': 'µL',
      'umol/L': 'µmol/L',
      'ug/dL': 'µg/dL',
      'mm[Hg]': 'mmHg',
      'Cel': '°C',
    };
    for (final MapEntry<String, String> entry in cases.entries) expect(formatUnit(entry.key), entry.value);
  });

  test('formatValue preserves meaningful decimals in ten locale cases', () {
    expect(formatValue(0.5, locale: 'it'), '0,5');
    expect(formatValue(0.04, locale: 'it'), '0,04');
    expect(formatValue(1.236, locale: 'it'), '1,24');
    expect(formatValue(1000, locale: 'it'), '1.000');
    expect(formatValue(-0.5, locale: 'it'), '-0,5');
    expect(formatValue(12, rawValue: 12.0, locale: 'it'), '12,0');
    expect(formatValue(0.5, locale: 'en'), '0.5');
    expect(formatValue(1234.5, locale: 'en'), '1,234.5');
    expect(formatValue(2, locale: 'en', signed: true), '+2');
    expect(formatRange(0, 0.2, '10*9/L', locale: 'it'), '0 – 0,2 ×10⁹/L');
  });
}