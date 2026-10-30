import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../utils/app_logger.dart';

/// State of the local app lock (biometrics + fallback PIN).
@immutable
class AppLockState {
  const AppLockState({
    this.enabled = false,
    this.unlocked = true,
    this.hasPin = false,
    this.biometricsAvailable = false,
    this.initialized = false,
  });

  final bool enabled;
  final bool unlocked;
  final bool hasPin;
  final bool biometricsAvailable;
  final bool initialized;

  bool get shouldBlock => initialized && enabled && !unlocked;

  AppLockState copyWith({
    bool? enabled,
    bool? unlocked,
    bool? hasPin,
    bool? biometricsAvailable,
    bool? initialized,
  }) =>
      AppLockState(
        enabled: enabled ?? this.enabled,
        unlocked: unlocked ?? this.unlocked,
        hasPin: hasPin ?? this.hasPin,
        biometricsAvailable: biometricsAvailable ?? this.biometricsAvailable,
        initialized: initialized ?? this.initialized,
      );
}

/// Biometric lock with a 6-digit fallback PIN.
/// Secrets live in flutter_secure_storage, never in plain preferences.
class AppLockController extends Notifier<AppLockState> {
  static const String _kEnabled = 'm24_lock_enabled';
  static const String _kPin = 'm24_lock_pin';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  AppLockState build() {
    Future<void>.microtask(_load);
    return const AppLockState();
  }

  Future<void> _load() async {
    bool enabled = false;
    bool hasPin = false;
    bool biometrics = false;
    try {
      enabled = (await _storage.read(key: _kEnabled)) == 'true';
      hasPin = (await _storage.read(key: _kPin)) != null;
    } catch (e) {
      AppLogger.error('appLock.loadStorage', e);
    }
    try {
      biometrics = !kIsWeb &&
          await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } catch (e) {
      AppLogger.error('appLock.canCheckBiometrics', e);
    }
    state = AppLockState(
      enabled: enabled,
      unlocked: !enabled,
      hasPin: hasPin,
      biometricsAvailable: biometrics,
      initialized: true,
    );
  }

  Future<void> setEnabled(bool value) async {
    try {
      await _storage.write(key: _kEnabled, value: value.toString());
    } catch (e) {
      AppLogger.error('appLock.setEnabled', e);
    }
    state = state.copyWith(enabled: value, unlocked: true);
  }

  Future<void> setPin(String pin) async {
    try {
      await _storage.write(key: _kPin, value: pin);
      state = state.copyWith(hasPin: true);
    } catch (e) {
      AppLogger.error('appLock.setPin', e);
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final String? stored = await _storage.read(key: _kPin);
      final bool ok = stored != null && stored == pin;
      if (ok) state = state.copyWith(unlocked: true);
      return ok;
    } catch (e) {
      AppLogger.error('appLock.verifyPin', e);
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    if (!state.biometricsAvailable) return false;
    try {
      final bool ok = await _localAuth.authenticate(localizedReason: reason);
      if (ok) state = state.copyWith(unlocked: true);
      return ok;
    } catch (e) {
      AppLogger.error('appLock.authenticate', e);
      return false;
    }
  }

  void lock() {
    if (state.enabled) state = state.copyWith(unlocked: false);
  }
}

class AuthenticationOptions {
  const AuthenticationOptions();
}
