import 'package:medical24/l10n/generated/app_localizations.dart';

/// Typed settings strings mirrored in the ARB sources.
extension SettingsPrivacyLocalizations on AppLocalizations {
  String _s(String it, String en) => localeName.startsWith('en') ? en : it;

  String get settingsExportTitle => _s('Esporta i miei dati', 'Export my data');
  String get settingsExportExplanation => _s('Il pacchetto include profilo, consensi, documenti, valori, sintomi, dati di prevenzione, condivisioni e file originali disponibili. Resta disponibile per 7 giorni e puoi richiederne uno ogni 24 ore.', 'The package includes your profile, consents, documents, observations, symptoms, prevention data, shares, and available original files. It remains available for 7 days and you can request one every 24 hours.');
  String get settingsExportRequest => _s("Richiedi l'export", 'Request export');
  String get settingsExportRefresh => _s('Aggiorna', 'Refresh');
  String get settingsExportDownload => _s('Scarica', 'Download');
  String get settingsExportWait => _s('Stiamo preparando il pacchetto. Può richiedere qualche decina di secondi.', 'We are preparing the package. This may take a few tens of seconds.');
  String get settingsExportNoneTitle => _s('Nessun export richiesto', 'No export requested');
  String get settingsExportNoneBody => _s('Richiedi un pacchetto per scaricare una copia dei tuoi dati.', 'Request a package to download a copy of your data.');
  String get settingsExportPendingTitle => _s('Export in corso', 'Export in progress');
  String get settingsExportPendingBody => _s('Il pacchetto è in preparazione. Aggiorna tra poco per controllare lo stato.', 'The package is being prepared. Refresh shortly to check its status.');
  String get settingsExportReadyTitle => _s('Export pronto', 'Export ready');
  String settingsExportReadyDetails(String date, String bytes, int count) => _s('Scade il $date · $bytes · $count file', 'Expires $date · $bytes · $count files');
  String get settingsExportFailedTitle => _s('Export non riuscito', 'Export failed');
  String get settingsExportExpiredTitle => _s('Export scaduto', 'Export expired');
  String get settingsExportExpiredBody => _s('Il pacchetto non è più disponibile. Puoi richiederne uno nuovo.', 'The package is no longer available. You can request a new one.');
  String get settingsExportDateUnavailable => _s('data non disponibile', 'date unavailable');
  String get settingsExportIncompleteTitle => _s('Il pacchetto non è completo', 'The package is incomplete');
  String get settingsExportIncompleteBody => _s('Alcuni file non sono inclusi perché il pacchetto ha raggiunto il limite di dimensione.', 'Some files are not included because the package reached its size limit.');
  String get settingsExportFailureBuild => _s('Non siamo riusciti a preparare il pacchetto. Riprova.', 'We could not prepare the package. Try again.');
  String get settingsExportFailureUpload => _s('Non siamo riusciti a salvare il pacchetto. Riprova.', 'We could not save the package. Try again.');
  String get settingsExportFailureFinalize => _s('Il pacchetto non è stato finalizzato. Riprova.', 'The package was not finalized. Try again.');
  String get settingsExportFailureUnknown => _s("L'export non è riuscito. Riprova.", 'The export failed. Try again.');
  String settingsExportErrorDaily(int hours) => _s('Puoi chiedere un nuovo export tra circa $hours ore.', 'You can request a new export in about $hours hours.');
  String get settingsExportErrorDailyGeneric => _s('Puoi richiedere un solo export ogni 24 ore.', 'You can request only one export every 24 hours.');
  String get settingsExportErrorForbidden => _s('Non hai il permesso di esportare questi dati.', 'You do not have permission to export this data.');
  String get settingsExportErrorServer => _s('Non siamo riusciti a completare la richiesta. Riprova.', 'We could not complete the request. Try again.');
  String get settingsExportDownloadError => _s('Non siamo riusciti ad aprire il download. Aggiorna e riprova.', 'We could not open the download. Refresh and try again.');
  String get settingsDeleteErrorConfirmation => _s('La conferma non è valida. Scrivi ELIMINA e riprova.', 'The confirmation is not valid. Type DELETE and try again.');
  String get settingsDeleteErrorUnauthorized => _s('La sessione è scaduta. Accedi di nuovo e riprova.', 'Your session has expired. Sign in again and retry.');
  String get settingsDeleteErrorServer => _s("Non siamo riusciti a eliminare l'account. Riprova.", 'We could not delete the account. Try again.');
  String settingsDeleteSuccess(String date) => _s('Account eliminato: i dati residui saranno rimossi il $date.', 'Account deleted: remaining data will be removed on $date.');
}