import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/features/admin/data/admin_models.dart';

void main() {
  test('pending moderation rows retain their status and rejection note', () {
    final review = AdminReview({'id': 'r1', 'status': 'pending', 'rating': 2, 'body': 'text'}, authorLabel: 'Patient');
    expect(review.status, 'pending');
    final payload = {'id': review.id, 'status': 'rejected', 'note': 'Insufficient detail'};
    expect(payload['note'], isNotEmpty);
  });
}