import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../models/user_profile.dart';
import '../security/app_lock_controller.dart';

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => const AuthRepository());

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) => const ProfileRepository());

/// Single source of truth for the auth session.
final StreamProvider<AuthState> authStateProvider =
    StreamProvider<AuthState>((Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Current session, derived from the stream so the router rebuilds on change.
final Provider<Session?> sessionProvider = Provider<Session?>((Ref ref) {
  final AsyncValue<AuthState> state = ref.watch(authStateProvider);
  return state.maybeWhen(
    data: (AuthState s) => s.session,
    orElse: () => ref.read(authRepositoryProvider).currentSession,
  );
});

/// Profile of the signed-in user, read from Supabase (never mocked).
class MyProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    ref.watch(sessionProvider);
    if (ref.read(authRepositoryProvider).currentUser == null) return null;
    return ref.read(profileRepositoryProvider).fetchMyProfile();
  }

  Future<void> refreshProfile() async {
    state = const AsyncValue<UserProfile?>.loading();
    state = await AsyncValue.guard<UserProfile?>(
      () => ref.read(profileRepositoryProvider).fetchMyProfile(),
    );
  }

  Future<void> save(Map<String, dynamic> values) async {
    final UserProfile updated =
        await ref.read(profileRepositoryProvider).upsertMyProfile(values);
    state = AsyncValue<UserProfile?>.data(updated);
  }

  Future<void> completeOnboarding(Map<String, dynamic> values) async {
    final UserProfile updated =
        await ref.read(profileRepositoryProvider).completeOnboarding(values);
    state = AsyncValue<UserProfile?>.data(updated);
  }
}

final AsyncNotifierProvider<MyProfileNotifier, UserProfile?> myProfileProvider =
    AsyncNotifierProvider<MyProfileNotifier, UserProfile?>(
        MyProfileNotifier.new);

/// App language. Follows the profile once it is loaded.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final AsyncValue<UserProfile?> profile = ref.watch(myProfileProvider);
    final String? code =
        profile.hasValue ? profile.requireValue?.language : null;
    return Locale(code ?? 'it');
  }

  void setLocale(String languageCode) => state = Locale(languageCode);
}

final NotifierProvider<LocaleNotifier, Locale> localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

final NotifierProvider<AppLockController, AppLockState> appLockProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
