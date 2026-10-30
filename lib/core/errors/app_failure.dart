import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

/// Human-readable failure, free of clinical or personal content.
class AppFailure implements Exception {
  const AppFailure(this.messageIt, this.messageEn, {this.code});

  final String messageIt;
  final String messageEn;
  final String? code;

  String localized(String languageCode) =>
      languageCode == 'en' ? messageEn : messageIt;

  @override
  String toString() => 'AppFailure(${code ?? 'generic'})';

  static const AppFailure network = AppFailure(
    'Connessione assente o instabile. Riprova.',
    'No or unstable connection. Please try again.',
    code: 'network',
  );

  static const AppFailure unauthorized = AppFailure(
    'Non hai i permessi per questa operazione.',
    'You do not have permission for this operation.',
    code: 'unauthorized',
  );

  static const AppFailure invalidCredentials = AppFailure(
    'Email o password non corretti.',
    'Wrong email or password.',
    code: 'invalid_credentials',
  );

  static const AppFailure invalidOtp = AppFailure(
    'Codice non valido o scaduto.',
    'The code is invalid or expired.',
    code: 'invalid_otp',
  );

  static const AppFailure generic = AppFailure(
    'Qualcosa non ha funzionato. Riprova.',
    'Something went wrong. Please try again.',
    code: 'generic',
  );

  /// Maps any thrown object to a neutral failure, logging only the code.
  static AppFailure from(Object error, {String where = 'unknown'}) {
    if (error is AppFailure) return error;

    if (error is AuthException) {
      AppLogger.error(where, 'AuthException ${error.statusCode ?? ''}');
      final String message = error.message.toLowerCase();
      if (message.contains('invalid login') ||
          message.contains('invalid credentials')) {
        return invalidCredentials;
      }
      if (message.contains('otp') || message.contains('token')) {
        return invalidOtp;
      }
      return AppFailure(error.message, error.message, code: 'auth');
    }

    if (error is PostgrestException) {
      AppLogger.error(where, 'PostgrestException ${error.code ?? ''}');
      if (error.code == '42501' ||
          error.message.toLowerCase().contains('permission denied') ||
          error.message.toLowerCase().contains('row-level security')) {
        return unauthorized;
      }
      return AppFailure(generic.messageIt, generic.messageEn, code: error.code);
    }

    if (error is StorageException) {
      AppLogger.error(where, 'StorageException ${error.statusCode ?? ''}');
      return generic;
    }

    AppLogger.error(where, error);
    return generic;
  }
}
