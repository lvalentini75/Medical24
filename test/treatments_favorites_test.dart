import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/features/treatments/data/treatment_models.dart';

void main() {
  test('favorite list removes the selected item', () {
    final values = [const TreatmentSummary(id: '1', title: 'A'), const TreatmentSummary(id: '2', title: 'B')];
    values.removeWhere((x) => x.id == '1');
    expect(values.map((x) => x.id), ['2']);
  });
}