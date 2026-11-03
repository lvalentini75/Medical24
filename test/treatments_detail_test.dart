import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/features/treatments/data/treatment_models.dart';

void main() {
  test('detail exposes evidence, contraindications and review-exists payload', () {
    final d = TreatmentDetail({'id': '1', 'evidence_and_limits': 'Limitations', 'contraindications': [{'text': 'Allergy', 'severity': 'high'}], 'review_exists': true});
    expect(d.text('evidence_and_limits'), 'Limitations');
    expect(d.list('contraindications').single['severity'], 'high');
    expect(d.flag('review_exists'), isTrue);
  });
}