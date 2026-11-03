import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/features/treatments/data/treatment_models.dart';
import 'package:medical24/features/treatments/providers/treatments_providers.dart';

void main() {
  test('comparison accepts four columns and rejects a fifth', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(treatmentCompareSelectionProvider.notifier);
    for (var i = 0; i < 4; i++) expect(n.toggle(TreatmentSummary(id: '$i', title: '$i')), isTrue);
    expect(n.toggle(const TreatmentSummary(id: '5', title: '5')), isFalse);
    expect(c.read(treatmentCompareSelectionProvider), hasLength(4));
  });
}