import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_logger.dart';
import '../../../supabase/supabase_config.dart';

/// All authentication goes through Supabase Auth with the anon key only.
class AuthRepository {
  const AuthRepository();

  GoTrueClient get _auth => SupabaseConfig.auth;

  Session? get currentSession => _auth.currentSession;
  User? get currentUser => _auth.currentUser;
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<bool> devShortcutsEnabled() async {
    try {
      final dynamic value = await SupabaseConfig.client.rpc(
        'platform_setting',
        params: <String, dynamic>{'p_key': 'features.dev_shortcuts'},
      );
      return value == true || value == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signUp(email: email.trim(), password: password);
      AppLogger.event('auth_sign_up');
    } catch (e) {
      throw AppFailure.from(e, where: 'auth.signUpWithEmail');
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
      AppLogger.event('auth_sign_in_password');
    } catch (e) {
      throw AppFailure.from(e, where: 'auth.signInWithEmail');
    }
  }

  /// Sends a 6-digit OTP to the email address (also creates the user).
  Future<void> sendEmailOtp(String email, {bool shouldCreateUser = true}) async {
    try {
      await _auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: shouldCreateUser,
      );
      AppLogger.event('auth_otp_sent');
    } catch (e) {
      throw AppFailure.from(e, where: 'auth.sendEmailOtp');
    }
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
    OtpType type = OtpType.email,
  }) async {
    try {
      await _auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: type,
      );
      AppLogger.event('auth_otp_verified');
    } catch (e) {
      throw AppFailure.from(e, where: 'auth.verifyEmailOtp');
    }
  }

  Future<void> sendPasswordRecoveryOtp(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
      AppLogger.event('auth_recovery_sent');
    } catch (e) {
      throw AppFailure.from(e, where: 'auth.sendPasswordRecoveryOtp');
    }
  }

  Future<void> updatePassword(String password) async {
    try {
      await _auth.updateUser(UserAttributes(password: password));
      AppLogger.event('auth_password_updated');
    } catch (e) {
      throw AppFailure.from(e, where: 'auth.updatePassword');
    }
  }

  /// Native Sign in with Apple on iOS/macOS, OAuth elsewhere.
  Future<void> signInWithApple() async {
    try {
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.iOS &&
              defaultTargetPlatform != TargetPlatform.macOS)) {
        await _auth.signInWithOAuth(OAuthProvider.apple);
        return;
      }
      final AuthorizationCredentialAppleID credential =
          await SignInWithApple.getAppleIDCredential(
        scopes: <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final String? idToken = credential.identityToken;
      if (idToken == null) throw AppFailure.generic;
      await _auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );
      AppLogger.event('auth_sign_in_apple');
    } catch (e) {
      throw AppFailure.from(e, where: 'auth.signInWithApple');
    }
  }

  /// Google Sign-In through the Supabase OAuth flow, identical on
  /// iOS, Android and web (no provider secret in the client).
  Future<void> signInWithGoogle() async {
    try {
      await _auth.signInWithOAuth(OAuthProvider.google);
      AppLogger.event('auth_sign_in_google');
    } catch (e) {
      throw AppFailure.from(e, where: 'auth.signInWithGoogle');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      AppLogger.event('auth_sign_out');
    } catch (e) {
      throw AppFailure.from(e, where: 'auth.signOut');
    }
  }
}
