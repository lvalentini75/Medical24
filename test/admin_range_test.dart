import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/features/admin/providers/admin_providers.dart';

void main() {
  test('equal range filters have stable family keys', () {
    const a = AdminRangeFilter('2026-01-01T00:00:00Z', '2026-02-01T00:00:00Z');
    const b = AdminRangeFilter('2026-01-01T00:00:00Z', '2026-02-01T00:00:00Z');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}