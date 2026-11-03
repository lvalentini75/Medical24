import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/models/user_profile.dart';
import 'package:medical24/core/providers/app_providers.dart';
import 'package:medical24/core/router/app_router.dart';
import 'package:medical24/features/admin/providers/admin_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('admin child routes are not redirected to overview', () {
    final ProviderContainer container = ProviderContainer(overrides: <Override>[
      sessionProvider.overrideWithValue(Session.fromJson(<String, dynamic>{
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'expires_in': 3600,
        'expires_at': 4102444800,
        'token_type': 'bearer',
        'user': <String, dynamic>{
          'id': '00000000-0000-0000-0000-000000000001',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'test@example.com',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        },
      })),
      myProfileProvider.overrideWith(_TestProfileNotifier.new),
      isAdminProvider.overrideWithValue(const AsyncValue<bool>.data(true)),
    ]);
    addTearDown(container.dispose);

    final GoRouter router = container.read(appRouterProvider);
    router.go('/admin');
    expect(router.routeInformationProvider.value.uri.path, '/admin/overview');
    router.go('/admin/ai');
    expect(router.routeInformationProvider.value.uri.path, '/admin/ai');
    router.go('/admin/treatments/new');
    expect(router.routeInformationProvider.value.uri.path, '/admin/treatments/new');
    router.go('/admin/reviews');
    expect(router.routeInformationProvider.value.uri.path, '/admin/reviews');
  });
}

class _TestProfileNotifier extends MyProfileNotifier {
  @override
  Future<UserProfile?> build() async =>
      UserProfile(id: '00000000-0000-0000-0000-000000000001', onboardedAt: DateTime(2026));
}