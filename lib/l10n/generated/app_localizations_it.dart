// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get healthExportCsv => 'Esporta CSV';

  @override
  String get healthExportError => 'Impossibile esportare i valori.';

  @override
  String get appTitle => 'Medical 24';

  @override
  String get commonContinue => 'Continua';

  @override
  String get commonBack => 'Indietro';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonLoading => 'Caricamento…';

  @override
  String get commonErrorTitle => 'Qualcosa non ha funzionato';

  @override
  String get commonEmptyTitle => 'Non c\'è ancora niente qui';

  @override
  String get commonRequired => 'Campo obbligatorio';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonConfirm => 'Conferma';

  @override
  String get commonOptional => 'Facoltativo';

  @override
  String get commonAdd => 'Aggiungi';

  @override
  String get addUploadReport => 'Carica un referto';

  @override
  String get addManualValue => 'Inserisci un valore';

  @override
  String get breadcrumbLabel => 'Percorso';

  @override
  String get disclaimerClinical =>
      'I valori sono letti dal referto e confrontati con intervalli di riferimento: non sono una diagnosi, parlane con il tuo medico.';

  @override
  String get authWelcomeTitle => 'La tua salute, in ordine';

  @override
  String get authWelcomeSubtitle =>
      'Raccogli i documenti sanitari, capisci i tuoi valori e condividili con il tuo medico.';

  @override
  String get authWelcomeSignIn => 'Accedi';

  @override
  String get authWelcomeSignUp => 'Crea un account';

  @override
  String get authSignInTitle => 'Accedi';

  @override
  String get authSignUpTitle => 'Crea un account';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => 'Almeno 8 caratteri';

  @override
  String get authEmailInvalid => 'Inserisci un\'email valida';

  @override
  String get authPasswordShort => 'La password deve avere almeno 8 caratteri';

  @override
  String get authSignInAction => 'Accedi';

  @override
  String get authSignUpAction => 'Crea account';

  @override
  String get authForgotPassword => 'Password dimenticata?';

  @override
  String get authNoAccount => 'Non hai un account?';

  @override
  String get authHasAccount => 'Hai già un account?';

  @override
  String get authOrDivider => 'oppure';

  @override
  String get authAppleAction => 'Continua con Apple';

  @override
  String get authGoogleAction => 'Continua con Google';

  @override
  String get authOtpAction => 'Accedi con un codice via email';

  @override
  String get authOtpTitle => 'Inserisci il codice';

  @override
  String authOtpSubtitle(String email) {
    return 'Abbiamo inviato un codice a 6 cifre a $email. È valido 10 minuti.';
  }

  @override
  String get authOtpLabel => 'Codice a 6 cifre';

  @override
  String get authOtpVerify => 'Verifica';

  @override
  String get authOtpResend => 'Invia di nuovo';

  @override
  String get authOtpSent => 'Codice inviato';

  @override
  String get authResetTitle => 'Recupera la password';

  @override
  String get authResetSubtitle =>
      'Ti inviamo un codice via email per impostare una nuova password.';

  @override
  String get authResetAction => 'Invia il codice';

  @override
  String get authNewPasswordLabel => 'Nuova password';

  @override
  String get authResetDone => 'Password aggiornata';

  @override
  String get authSignOut => 'Esci';

  @override
  String get authPrivacyNote =>
      'I dati sanitari sono trattati come categoria particolare (art. 9 GDPR) e restano in Europa.';

  @override
  String get onboardingConsentTitle => 'I tuoi consensi';

  @override
  String get onboardingConsentSubtitle =>
      'Separati e revocabili in ogni momento dalle impostazioni.';

  @override
  String get onboardingConsentHealth => 'Trattamento dei dati sanitari';

  @override
  String get onboardingConsentHealthBody =>
      'Consenso esplicito (art. 9.2.a GDPR) al trattamento dei dati sanitari per erogare il servizio. Senza questo consenso l\'app non può funzionare.';

  @override
  String get onboardingConsentAi => 'Elaborazione IA dei documenti';

  @override
  String get onboardingConsentAiBody =>
      'I documenti vengono letti da un modello di IA per estrarre i valori. Senza questo consenso l\'archivio funziona, le analisi no.';

  @override
  String get onboardingConsentMarketing => 'Comunicazioni e marketing';

  @override
  String get onboardingConsentMarketingBody =>
      'Novità sul prodotto e contenuti di prevenzione. Facoltativo, mai in bundle.';

  @override
  String get onboardingConsentRequired => 'Obbligatorio';

  @override
  String get onboardingConsentMissing =>
      'Per continuare serve il consenso al trattamento dei dati sanitari.';

  @override
  String get onboardingBasicsTitle => 'Dati di base';

  @override
  String get onboardingBasicsSubtitle =>
      'Servono per usare gli intervalli corretti per età e genere.';

  @override
  String get onboardingNameLabel => 'Nome e cognome';

  @override
  String get onboardingBirthDateLabel => 'Data di nascita';

  @override
  String get onboardingBirthDatePick => 'Scegli la data';

  @override
  String get onboardingGenderLabel => 'Genere';

  @override
  String get onboardingGenderFemale => 'Femminile';

  @override
  String get onboardingGenderMale => 'Maschile';

  @override
  String get onboardingGenderOther => 'Altro';

  @override
  String get onboardingGenderUndisclosed => 'Preferisco non dirlo';

  @override
  String get onboardingLanguageLabel => 'Lingua';

  @override
  String get onboardingUnitsLabel => 'Unità di misura';

  @override
  String get onboardingCountryLabel => 'Paese';

  @override
  String get onboardingReadyTitle => 'Profilo pronto';

  @override
  String get onboardingReadySubtitle =>
      'Da qui puoi caricare il primo documento e vedere il tuo stato di salute.';

  @override
  String get onboardingReadyAction => 'Entra in Medical 24';

  @override
  String onboardingStepLabel(String current, String total) {
    return 'Passo $current di $total';
  }

  @override
  String get navHome => 'Home';

  @override
  String get navHealth => 'Salute';

  @override
  String get navArchive => 'Archivio';

  @override
  String get navTreatments => 'Cure';

  @override
  String get navDoctor => 'Medico';

  @override
  String get navMyDoctor => 'Il mio medico';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get navOverview => 'Panoramica';

  @override
  String get navMyHealth => 'La mia salute';

  @override
  String get navHealthSpace => 'Il mio spazio salute';

  @override
  String get navHelp => 'Aiuto';

  @override
  String get navProfile => 'Profilo';

  @override
  String get disclaimerPhone => 'Informazioni da discutere con il medico.';

  @override
  String get disclaimerDesktop =>
      'Le informazioni non sostituiscono il parere del medico.';

  @override
  String homeGreeting(String name) {
    return 'Ciao, $name';
  }

  @override
  String get homeGreetingNoName => 'Ciao';

  @override
  String get homeSubtitle => 'Ecco il punto sulla tua salute.';

  @override
  String get homeProfileCardTitle => 'Il tuo profilo';

  @override
  String homeProfileCompletion(String percent) {
    return 'Profilo completo al $percent%';
  }

  @override
  String get homeNextStepTitle => 'Prossimo passo';

  @override
  String get homeNextStepBody =>
      'L\'archivio dei documenti arriva con il prossimo rilascio.';

  @override
  String get healthTitle => 'Salute';

  @override
  String get healthEmptyBody =>
      'Stato di salute, parametri e storico dei valori arrivano con il modulo successivo.';

  @override
  String get healthValuesTitle => 'I miei valori';

  @override
  String get healthValuesSearch => 'Cerca un biomarcatore';

  @override
  String get healthValuesFavorites => 'Preferiti';

  @override
  String get healthValuesEssentials => 'Essenziali';

  @override
  String get healthValuesAll => 'Tutti';

  @override
  String get healthValuesOnlyWithValues => 'Solo con valori';

  @override
  String get healthValuesError => 'Non siamo riusciti a caricare i valori.';

  @override
  String get healthValuesEmptyTitle => 'Nessun valore da mostrare';

  @override
  String get healthValuesEmptyBody =>
      'I valori arrivano dai referti che carichi oppure puoi inserirli a mano.';

  @override
  String get healthValuesUploadReport => 'Carica un referto';

  @override
  String get healthValuesManual => 'Inserisci a mano';

  @override
  String get healthValuesNoValue => 'Nessun valore';

  @override
  String healthValuesCount(String count) {
    return '$count valori';
  }

  @override
  String get healthValuesTrack => '+ Traccia';

  @override
  String get healthValuesTracked => 'Tracciato';

  @override
  String get healthValuesFavorite => 'Aggiungi ai preferiti';

  @override
  String get healthValuesUnfavorite => 'Rimuovi dai preferiti';

  @override
  String get healthSelectValueTitle => 'Scegli un biomarcatore';

  @override
  String get healthSelectValueBody =>
      'Seleziona un valore dalla lista per vedere lo storico completo.';

  @override
  String get healthPeriodAll => 'Tutto';

  @override
  String get healthPeriodYear => '12 mesi';

  @override
  String get healthPeriod90 => '90 giorni';

  @override
  String get healthPeriod30 => '30 giorni';

  @override
  String get healthCompareWith => 'Confronta con…';

  @override
  String get healthCompareRemove => 'Rimuovi confronto';

  @override
  String get healthChartNormalized => 'Serie normalizzate 0–100';

  @override
  String get healthChartSemantics => 'Grafico dello storico dei valori';

  @override
  String get healthHistoryNoPoints => 'Nessun valore nel periodo selezionato.';

  @override
  String get healthStatsMinimum => 'Minimo';

  @override
  String get healthStatsMaximum => 'Massimo';

  @override
  String get healthStatsAverage => 'Media';

  @override
  String get healthStatsLatest => 'Ultimo';

  @override
  String get healthStatsChange => 'Variazione';

  @override
  String get healthStatsCount => 'Valori';

  @override
  String get healthEpisodesTitle => 'Episodi fuori soglia';

  @override
  String get healthEpisodesEmpty => 'Nessun episodio fuori soglia.';

  @override
  String get healthEpisodeOngoing => 'in corso';

  @override
  String healthEpisodeCount(String count) {
    return '$count valori';
  }

  @override
  String get healthTableTitle => 'Tutti i valori';

  @override
  String get healthTableDate => 'Data';

  @override
  String get healthTableValue => 'Valore e unità';

  @override
  String get healthTableStatus => 'Stato';

  @override
  String get healthTableOrigin => 'Origine';

  @override
  String get healthOrigin_document => 'Referto';

  @override
  String get healthOrigin_manual => 'Manuale';

  @override
  String get healthOrigin_device => 'Dispositivo';

  @override
  String get healthManualTitle => 'Inserisci un valore';

  @override
  String get healthManualParameter => 'Parametro';

  @override
  String get healthManualPressure => 'Pressione';

  @override
  String get healthManualValue => 'Valore';

  @override
  String get healthManualSystolic => 'Pressione sistolica';

  @override
  String get healthManualDiastolic => 'Pressione diastolica';

  @override
  String get healthManualUnit => 'Unità';

  @override
  String get healthManualNumberRequired => 'Inserisci un numero valido.';

  @override
  String healthManualPlausibleRange(String min, String max, String unit) {
    return 'Inserisci un valore plausibile tra $min e $max $unit.';
  }

  @override
  String get healthManualSaved => 'Valore salvato.';

  @override
  String get healthManualError_manual_value_not_plausible =>
      'Il valore è fuori dall\'intervallo plausibile.';

  @override
  String get healthManualError_manual_unit_not_supported =>
      'Questa unità non è supportata per il parametro.';

  @override
  String get healthManualError_manual_code_not_allowed =>
      'Questo parametro non può essere inserito manualmente.';

  @override
  String get healthManualError_not_allowed =>
      'Non hai il permesso di inserire questo valore.';

  @override
  String get healthManualError_unknown =>
      'Non siamo riusciti a salvare il valore. Riprova.';

  @override
  String get archiveTitle => 'Archivio';

  @override
  String get archiveEmptyBody =>
      'Qui vivranno i tuoi documenti sanitari, con categorie e ricerca.';

  @override
  String get treatmentsTitle => 'Cure';

  @override
  String get treatmentsEmptyBody =>
      'Il database delle cure arriva con il modulo dedicato.';

  @override
  String get doctorTitle => 'Medico';

  @override
  String get doctorEmptyBody =>
      'Dossier, domande al medico e condivisione sicura arrivano dopo.';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsProfileSection => 'Profilo';

  @override
  String get settingsPreferencesSection => 'Preferenze';

  @override
  String get settingsSecuritySection => 'Sicurezza';

  @override
  String get settingsPrivacySection => 'Privacy';

  @override
  String get settingsAboutSection => 'Informazioni';

  @override
  String get settingsEditProfile => 'Modifica profilo';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsUnits => 'Unità';

  @override
  String get settingsBiometricLock => 'Blocco biometrico';

  @override
  String get settingsBiometricLockBody =>
      'Chiedi Face ID, impronta o PIN all\'apertura dell\'app.';

  @override
  String get settingsBiometricUnavailable =>
      'Questo dispositivo non supporta il blocco biometrico.';

  @override
  String get settingsPinFallback => 'PIN di riserva';

  @override
  String get settingsPinSet => 'Imposta il PIN';

  @override
  String get settingsPinLabel => 'PIN di 6 cifre';

  @override
  String get settingsPinSaved => 'PIN salvato';

  @override
  String get settingsExportData => 'Esporta i miei dati';

  @override
  String get settingsExportBody =>
      'Ricevi profilo, consensi e registro degli accessi in formato leggibile.';

  @override
  String get settingsExportDone => 'Export pronto';

  @override
  String get settingsConsents => 'Registro dei consensi';

  @override
  String get settingsPrivacyPolicy => 'Informativa privacy';

  @override
  String get settingsDeleteAccount => 'Elimina account';

  @override
  String get settingsDeleteBody =>
      'Cancellazione immediata dell\'accesso e rimozione definitiva dei dati entro 30 giorni.';

  @override
  String get settingsDeleteConfirmTitle => 'Eliminare l\'account?';

  @override
  String get settingsDeleteConfirmBody =>
      'L\'accesso si chiude subito. I dati vengono rimossi definitivamente entro 30 giorni. L\'operazione non si annulla.';

  @override
  String get settingsDeleteConfirmAction => 'Elimina definitivamente';

  @override
  String get settingsAppVersion => 'Versione app';

  @override
  String get consentsLogTitle => 'Registro dei consensi';

  @override
  String get consentsLogEmpty => 'Nessun consenso registrato.';

  @override
  String get consentGranted => 'Concesso';

  @override
  String get consentRevoked => 'Revocato';

  @override
  String get lockTitle => 'Medical 24 è bloccata';

  @override
  String get lockSubtitle => 'Sblocca per vedere i tuoi dati.';

  @override
  String get lockUnlock => 'Sblocca';

  @override
  String get lockUsePin => 'Usa il PIN';

  @override
  String get lockPinWrong => 'PIN errato';

  @override
  String get archiveSearchHint => 'Cerca nei documenti';

  @override
  String get archiveClearSearch => 'Cancella ricerca';

  @override
  String get archiveSortLabel => 'Ordina per';

  @override
  String get archiveSort_dateDesc => 'Data, più recenti';

  @override
  String get archiveSort_dateAsc => 'Data, meno recenti';

  @override
  String get archiveSort_category => 'Categoria';

  @override
  String get archiveSort_doctor => 'Medico';

  @override
  String get archiveSort_facility => 'Struttura';

  @override
  String get archiveCategories => 'Categorie';

  @override
  String get archiveResetFilters => 'Azzera filtri';

  @override
  String get archiveCategory_exams => 'Esami';

  @override
  String get archiveCategory_reports => 'Referti';

  @override
  String get archiveCategory_prescriptions => 'Prescrizioni';

  @override
  String get archiveCategory_radiology => 'Radiologia';

  @override
  String get archiveCategory_vaccinations => 'Vaccinazioni';

  @override
  String get archiveCategory_invoices => 'Fatture';

  @override
  String get archiveCategory_consents => 'Consensi';

  @override
  String get archiveCategory_cards => 'Tessere';

  @override
  String get archiveCategory_other => 'Altro';

  @override
  String get archiveStatus_uploading => 'Caricato';

  @override
  String get archiveStatus_uploaded => 'Caricato';

  @override
  String get archiveStatus_processing => 'In analisi';

  @override
  String get archiveStatus_analyzed => 'Analizzato';

  @override
  String get archiveStatus_needs_review => 'Da verificare';

  @override
  String get archiveStatus_failed => 'Errore';

  @override
  String get archiveGroupYear => 'Anno';

  @override
  String get archiveGroupEpisode => 'Episodio';

  @override
  String get archiveGroupMonth => 'Mese';

  @override
  String get archiveDateUnknown => 'Data non disponibile';

  @override
  String get archiveNoEpisode => 'Senza episodio';

  @override
  String archiveOpenDocument(String title) {
    return 'Apri $title';
  }

  @override
  String get archiveAddAction => 'Aggiungi documento';

  @override
  String get archiveAddTitle => 'Aggiungi documento';

  @override
  String get archiveEmptySuggestion => 'Fotografa il tuo ultimo referto.';

  @override
  String get archiveNoResults => 'Nessun documento corrisponde ai filtri.';

  @override
  String get archiveSelectDocument =>
      'Seleziona un documento per vedere i dettagli.';

  @override
  String archiveDocumentCount(String count) {
    return '$count documenti';
  }

  @override
  String get archiveDocumentDetail => 'Documento';

  @override
  String get archiveDocumentMissing => 'Il documento non è più disponibile.';

  @override
  String get archiveEditMetadata => 'Modifica dati';

  @override
  String get archiveShareDocument => 'Condividi originale';

  @override
  String get archiveDownloadReady => 'Originale salvato in modo sicuro.';

  @override
  String get archiveDeleteTitle => 'Eliminare il documento?';

  @override
  String get archiveDeleteBody => 'Il documento verrà rimosso dall\'archivio.';

  @override
  String get archiveDeleteAction => 'Elimina';

  @override
  String get archiveDocumentDate => 'Data del documento';

  @override
  String get archiveDoctor => 'Medico';

  @override
  String get archiveFacility => 'Struttura';

  @override
  String get archiveEpisode => 'Episodio';

  @override
  String get archiveTags => 'Tag';

  @override
  String get archiveTagsHint => 'Tag, separati da virgole';

  @override
  String get archiveNotes => 'Note';

  @override
  String get archiveTitleField => 'Titolo';

  @override
  String get archiveCategoryField => 'Categoria';

  @override
  String archivePageLabel(String current, String total) {
    return 'Pagina $current di $total';
  }

  @override
  String get archiveSourceCamera => 'Fotocamera';

  @override
  String get archiveSourceGallery => 'Galleria';

  @override
  String get archiveSourceFile => 'File o PDF';

  @override
  String get archiveSourceShare => 'Condivisione';

  @override
  String get archiveChooseSource => 'Scegli da dove aggiungere il documento.';

  @override
  String get archivePagesPreview => 'Anteprima pagine';

  @override
  String get archiveRotatePage => 'Ruota pagina';

  @override
  String get archiveDeletePage => 'Elimina pagina';

  @override
  String get archiveUploadAction => 'Carica';

  @override
  String archiveUploadProgress(String current, String total) {
    return '$current di $total pagine completate';
  }

  @override
  String get archiveDuplicateTitle => 'Sembra già in archivio';

  @override
  String get archiveDuplicateBody =>
      'Puoi aprire l\'originale o conservare entrambi.';

  @override
  String get archiveOpenOriginal => 'Apri l\'originale';

  @override
  String get archiveKeepBoth => 'Conserva entrambi';

  @override
  String get archiveDefaultFileName => 'documento';

  @override
  String archiveUsageCounter(String used, String max) {
    return '$used di $max documenti';
  }

  @override
  String get archiveUsageLoading => 'Conteggio documenti in corso…';

  @override
  String get archiveLimitReachedTitle => 'Hai raggiunto il limite del piano';

  @override
  String archiveLimitReachedBody(String max) {
    return 'Il tuo piano include $max documenti. Elimina un documento oppure cambia piano dalle Impostazioni.';
  }

  @override
  String get archiveOpenSettings => 'Vai alle Impostazioni';

  @override
  String get archiveDuplicateBadge => 'Possibile duplicato';

  @override
  String get archiveDuplicateDismiss => 'Conserva entrambi';

  @override
  String get archiveCropPage => 'Ritaglia pagina';

  @override
  String get archiveCropConfirm => 'Applica ritaglio';

  @override
  String get archiveReorderHint =>
      'Trascina le pagine per cambiarne l\'ordine.';

  @override
  String get archiveMultiPageTitle => 'Pagine del documento';

  @override
  String archivePagesCount(String count) {
    return '$count pagine';
  }

  @override
  String get archiveDropHere => 'Trascina qui PDF o immagini';

  @override
  String get archiveDropActive => 'Rilascia per aggiungere';

  @override
  String get archiveShareReady => 'Originale pronto per la condivisione.';

  @override
  String get archiveSharePdfNote => 'Le foto diventano un unico PDF.';

  @override
  String get analysisTitle => 'Analisi del referto';

  @override
  String get analysisViewAction => 'Visualizza analisi';

  @override
  String get analysisStartAction => 'Analizza il documento';

  @override
  String get analysisUpdateAction => 'Aggiorna';

  @override
  String get analysisRetryAction => 'Riprova la lettura';

  @override
  String get analysisStatus_queued => 'In coda';

  @override
  String get analysisStatus_classifying => 'Riconoscimento del documento';

  @override
  String get analysisStatus_extracting => 'Lettura dei valori';

  @override
  String get analysisStatus_normalizing => 'Conversione delle unità';

  @override
  String get analysisStatus_done => 'Lettura completata';

  @override
  String get analysisStatus_needs_review => 'Valori da verificare';

  @override
  String get analysisStatus_failed => 'Lettura non riuscita';

  @override
  String get analysisStatusSkipped => 'Documento non elaborato';

  @override
  String get analysisStatusNoValues => 'Nessun valore riconosciuto';

  @override
  String get analysisSkippedNotLabBody =>
      'Non sembra un referto di laboratorio: nessun valore da estrarre';

  @override
  String get analysisReadAnywayAction => 'Leggi comunque';

  @override
  String get analysisNoValuesBody =>
      'Nessun valore riconosciuto in queste pagine';

  @override
  String get analysisNoValuesAdvice =>
      'Riprova con foto nitide, dritte e con tutto il testo visibile.';

  @override
  String get analysisEmptyTitle => 'Nessun valore letto';

  @override
  String get analysisEmptyBody =>
      'Questo documento non contiene valori di laboratorio riconoscibili.';

  @override
  String get analysisNotStartedTitle => 'Documento non ancora analizzato';

  @override
  String get analysisNotStartedBody =>
      'Avvia la lettura per trasformare il referto in valori.';

  @override
  String analysisValuesCount(String count) {
    return '$count valori';
  }

  @override
  String analysisValuesSaved(String saved) {
    return '$saved valori salvati';
  }

  @override
  String analysisToReviewCount(String count) {
    return '$count da verificare';
  }

  @override
  String get analysisReviewTitle => 'Valori da verificare';

  @override
  String get analysisReviewBody =>
      'Controlla questi valori: la lettura non era abbastanza sicura.';

  @override
  String get analysisConfirmAction => 'Confermo il valore';

  @override
  String get analysisCorrectAction => 'Correggi';

  @override
  String get analysisCorrectTitle => 'Correggi il valore';

  @override
  String get analysisValueField => 'Valore';

  @override
  String get analysisUnitField => 'Unità';

  @override
  String get analysisDateField => 'Data del prelievo';

  @override
  String analysisReadAs(String value) {
    return 'Letto come $value';
  }

  @override
  String analysisConfidence(String percent) {
    return 'Sicurezza della lettura $percent%';
  }

  @override
  String get analysisLabRange => 'Intervallo del laboratorio';

  @override
  String get analysisBoardRange => 'Riferimento istituzionale';

  @override
  String get analysisDoctorRange => 'Soglia del medico';

  @override
  String get analysisRangeMissing => 'Non disponibile';

  @override
  String get analysisFlag_below => 'Sotto l\'intervallo';

  @override
  String get analysisFlag_within => 'Nell\'intervallo';

  @override
  String get analysisFlag_above => 'Sopra l\'intervallo';

  @override
  String get analysisFlag_critical_low => 'Molto sotto l\'intervallo';

  @override
  String get analysisFlag_critical_high => 'Molto sopra l\'intervallo';

  @override
  String get analysisFlag_unknown => 'Da valutare';

  @override
  String get analysisCatalogDraftNotice =>
      'Intervalli di uso comune, non ancora validati dal board scientifico.';

  @override
  String get analysisLabName => 'Laboratorio';

  @override
  String analysisUsageCounter(String used, String max) {
    return '$used di $max letture questo mese';
  }

  @override
  String get analysisLimitReachedTitle =>
      'Hai raggiunto il limite di letture del mese';

  @override
  String analysisLimitReachedBody(String max) {
    return 'Il tuo piano include $max letture al mese. Riprova il mese prossimo oppure cambia piano dalle Impostazioni.';
  }

  @override
  String get analysisFailedTitle => 'Non siamo riusciti a leggere il documento';

  @override
  String get analysisFailedBody =>
      'Controlla che le pagine siano leggibili e riprova.';

  @override
  String get analysisFailureApi =>
      'Il servizio di lettura non è temporaneamente disponibile. Riprova tra poco.';

  @override
  String get analysisFailureStorage =>
      'Non siamo riusciti ad aprire il documento salvato. Controlla il file e riprova.';

  @override
  String get analysisFailurePdfParse =>
      'Non siamo riusciti a leggere questo PDF. Prova a caricarlo di nuovo o usa foto nitide delle pagine.';

  @override
  String get analysisFailureNetwork =>
      'La connessione al servizio di lettura si è interrotta. Riprova tra poco.';

  @override
  String get analysisFailureInvalidOutput =>
      'La lettura non ha prodotto valori utilizzabili. Riprova con pagine più nitide.';

  @override
  String get analysisFailureMissingApiKey =>
      'Il servizio di lettura non è configurato. Contatta l\'assistenza.';

  @override
  String get analysisHistoryTitle => 'Storico del valore';

  @override
  String get analysisHistoryEmpty =>
      'Non c\'è ancora uno storico per questo valore.';

  @override
  String get analysisCatalogTitle => 'Biomarcatori';

  @override
  String get analysisCatalogSearch => 'Cerca un biomarcatore';

  @override
  String get analysisCatalogEmpty =>
      'Nessun biomarcatore corrisponde alla ricerca.';

  @override
  String get archiveFilterNeedsReview => 'Da verificare';

  @override
  String analysisReviewBadge(String count) {
    return 'Da verificare: $count';
  }

  @override
  String get analysisReadingProgress => 'Avanzamento della lettura';

  @override
  String get analysisUsuallyUnderMinute => 'Di solito meno di un minuto.';

  @override
  String analysisCompletedAt(String date) {
    return 'Analizzato il $date';
  }

  @override
  String get analysisVerifyAction => 'Verifica';

  @override
  String get analysisUnknownTitle => 'Non ancora nel catalogo';

  @override
  String get analysisValueColumn => 'Valore';

  @override
  String analysisOriginalUnit(String unit) {
    return 'Nel referto: $unit';
  }

  @override
  String get analysisReviewComplete => 'Tutti i valori sono stati verificati.';

  @override
  String get analysisDiscardAction => 'Scarta';

  @override
  String get analysisDiscardUnavailable =>
      'Lo scarto non è ancora supportato dal repository.';

  @override
  String get analysisSourceUnavailable =>
      'Pagina e ritaglio non disponibili per questo valore.';

  @override
  String get analysisKeyboardHelp => 'Tastiera: Invio conferma, C corregge.';

  @override
  String get addSymptom => 'Registra un sintomo';

  @override
  String get symptomsTitle => 'Diario dei sintomi';

  @override
  String get symptomsSubtitle => 'Annota come ti senti nel tempo.';

  @override
  String get symptomsNew => 'Registra un sintomo';

  @override
  String get symptomsEdit => 'Dettaglio sintomo';

  @override
  String get symptomsEmptyTitle => 'Nessun sintomo registrato';

  @override
  String get symptomsEmptyBody =>
      'Puoi annotare un sintomo, la sua intensità e quando è comparso.';

  @override
  String get symptomsType => 'Sintomo';

  @override
  String get symptomsFreeText => 'Descrivi il sintomo';

  @override
  String get symptomsSeverity => 'Severità';

  @override
  String get symptomsNotes => 'Note';

  @override
  String get symptomsReadOnly =>
      'Dopo 24 ore la registrazione non può più essere modificata o eliminata.';

  @override
  String get symptomsDelete => 'Elimina';

  @override
  String get symptomsDeleteTitle => 'Eliminare questo sintomo?';

  @override
  String get symptomsDeleteBody => 'La registrazione verrà rimossa dal diario.';

  @override
  String get symptomsLoadError => 'Non siamo riusciti a caricare il sintomo.';

  @override
  String get symptomsSaveError => 'Non siamo riusciti a salvare il sintomo.';

  @override
  String get symptomsMissing => 'Questa registrazione non è più disponibile.';

  @override
  String get symptom_headache => 'Mal di testa';

  @override
  String get symptom_nausea => 'Nausea';

  @override
  String get symptom_fatigue => 'Stanchezza';

  @override
  String get symptom_dizziness => 'Capogiri';

  @override
  String get symptom_chest_pain => 'Dolore al petto';

  @override
  String get symptom_shortness_of_breath => 'Fiato corto';

  @override
  String get symptom_fever => 'Febbre';

  @override
  String get symptom_cough => 'Tosse';

  @override
  String get symptom_abdominal_pain => 'Dolore addominale';

  @override
  String get symptom_joint_pain => 'Dolore articolare';

  @override
  String get symptom_back_pain => 'Mal di schiena';

  @override
  String get symptom_insomnia => 'Insonnia';

  @override
  String get symptom_anxiety => 'Ansia';

  @override
  String get symptom_palpitations => 'Palpitazioni';

  @override
  String get symptom_rash => 'Eruzione cutanea';

  @override
  String get symptom_swelling => 'Gonfiore';

  @override
  String get symptom_diarrhea => 'Diarrea';

  @override
  String get symptom_constipation => 'Stitichezza';

  @override
  String get symptom_loss_of_appetite => 'Perdita di appetito';

  @override
  String get symptom_other => 'Altro';

  @override
  String get alertsTitle => 'Centro avvisi';

  @override
  String get alertsSubtitle =>
      'Avvisi generati dalle regole cliniche versionate.';

  @override
  String get alertsMarkAllRead => 'Segna tutti come letti';

  @override
  String get alertsEmptyTitle => 'Nessun avviso';

  @override
  String get alertsEmptyBody => 'Non ci sono avvisi da leggere.';

  @override
  String get alertsContactDoctor => 'Contatta il medico';

  @override
  String get alertsLevel_lab => 'Laboratorio';

  @override
  String get alertsLevel_institutional => 'Istituzionale';

  @override
  String get alertsLevel_doctor => 'Medico';

  @override
  String get alertBiomarkerCriticalLow =>
      'Il biomarcatore è molto sotto l\'intervallo di riferimento.';

  @override
  String get alertBiomarkerCriticalHigh =>
      'Il biomarcatore è molto sopra l\'intervallo di riferimento.';

  @override
  String get alertBiomarkerBelowInstitutional =>
      'Il biomarcatore è sotto il riferimento istituzionale.';

  @override
  String get alertBiomarkerAboveInstitutional =>
      'Il biomarcatore è sopra il riferimento istituzionale.';

  @override
  String get homeHealthStatusTitle => 'Stato di salute';

  @override
  String get homeHealthStatusPreparing =>
      'In preparazione: il punteggio arriva con le regole del board';

  @override
  String get homeLatestValues => 'Ultimi valori';

  @override
  String get homeNoValues => 'Nessun valore disponibile.';

  @override
  String get homeAlerts => 'Avvisi';

  @override
  String get homeToReview => 'Da verificare';

  @override
  String get homeNothingToReview => 'Nessun documento da verificare.';

  @override
  String get homeLatestDocument => 'Ultimo documento';

  @override
  String get homeNoDocuments => 'Nessun documento disponibile.';

  @override
  String get homeEmptyTitle => 'Inizia dal tuo primo referto';

  @override
  String get homeEmptyBody =>
      'Carica un referto per raccogliere i valori e costruire il tuo storico.';

  @override
  String get homeUploadFirstReport => 'Carica il primo referto';

  @override
  String get homeHealthSpace => 'Il tuo spazio salute';

  @override
  String get homeUpload => 'Carica';

  @override
  String get homeUploadReport => 'Carica referto';

  @override
  String homeGreetingMorning(String name) {
    return 'Buongiorno, $name.';
  }

  @override
  String homeGreetingAfternoon(String name) {
    return 'Buon pomeriggio, $name.';
  }

  @override
  String homeGreetingEvening(String name) {
    return 'Buonasera, $name.';
  }

  @override
  String get homeGreetingDesktopNoName => 'Buongiorno.';

  @override
  String homeUpdatedAt(String date) {
    return 'Aggiornato al $date';
  }

  @override
  String get homeYourHealth => 'La tua salute';

  @override
  String get homeYourDoctor => 'Il tuo medico';

  @override
  String get homeOpenOverview => 'Apri il quadro';

  @override
  String homeLatestReportDate(String date) {
    return 'Ultimo referto: $date';
  }

  @override
  String homeReviewValues(String count) {
    return '$count valori da verificare';
  }

  @override
  String homeFromReport(String date) {
    return 'Dal referto del $date';
  }

  @override
  String get homeHealthStatusPreparingShort => 'In preparazione';

  @override
  String get homeRecentDocuments => 'Documenti recenti';

  @override
  String get homeAllDocuments => 'Tutti i documenti';

  @override
  String homeAllDocumentsCount(String count) {
    return 'Tutti i $count documenti';
  }

  @override
  String get homeStatDocuments => 'Documenti';

  @override
  String get homeStatTracked => 'Valori seguiti';

  @override
  String get homeStatReview => 'Valori da verificare';

  @override
  String get homeStatAlerts => 'Avvisi non letti';

  @override
  String get homeValuesOverTime => 'Valori nel tempo';

  @override
  String get homeOpenHistory => 'Apri storico';

  @override
  String get homePrevious => 'Precedente';

  @override
  String get homeConfirmedValues => 'Ultimi valori confermati';

  @override
  String get homeConfirmed => 'Confermato';

  @override
  String get homeTasks => 'Da fare';

  @override
  String homeUnreadAlerts(String count) {
    return '$count avvisi non letti';
  }

  @override
  String get homeOpenAlertCenter => 'Apri il centro avvisi';

  @override
  String get homeTableDocument => 'Documento';

  @override
  String get homeTableDate => 'Data';

  @override
  String get homeTableStatus => 'Stato';

  @override
  String get homeTableParameter => 'Parametro';

  @override
  String get homeTableVerification => 'Verifica';

  @override
  String get healthPeriod6Months => '6 mesi';

  @override
  String archiveDesktopSubtitle(String count) {
    return '$count documenti · Elenco, originale e analisi';
  }

  @override
  String get archiveUploadDocument => 'Carica documento';

  @override
  String get archiveUploadShort => 'Carica';

  @override
  String get archiveAll => 'Tutti';

  @override
  String get archiveYear => 'Anno';

  @override
  String get archiveAllYears => 'Tutti gli anni';

  @override
  String get archiveFilters => 'Filtri';

  @override
  String get archiveAllCategories => 'Tutte le categorie';

  @override
  String get archiveExtractedData => 'Dati estratti';

  @override
  String get archiveOriginal => 'Originale';

  @override
  String get archivePreviousPage => 'Pagina precedente';

  @override
  String get archiveNextPage => 'Pagina successiva';

  @override
  String get archiveOpenFullscreen => 'Apri a tutto schermo';

  @override
  String get healthConfirmed => 'Confermato';

  @override
  String get healthSourceReferences => 'Fonte e riferimenti';

  @override
  String get healthUpdatedUnavailable => 'Nessun aggiornamento disponibile';

  @override
  String healthUpdatedAt(String date) {
    return 'Quadro aggiornato al $date';
  }

  @override
  String get healthTabAllValues => 'Tutti i valori';

  @override
  String get healthTabHistory => 'Storico';

  @override
  String get healthSegmentValues => 'Valori';

  @override
  String get healthSegmentSymptoms => 'Sintomi';

  @override
  String get healthSegmentAlerts => 'Avvisi';

  @override
  String get healthMeasurementHistory => 'Storico delle rilevazioni';

  @override
  String get healthTableDocument => 'Documento';

  @override
  String get healthOpenReport => 'Apri il referto';

  @override
  String get healthSelectedValue => 'Il valore selezionato';

  @override
  String get healthExtractionConfirmed => 'Estrazione confermata';

  @override
  String get healthSource => 'Fonte';

  @override
  String get healthNotSet => 'Non impostata';

  @override
  String get healthOtherConfirmed => 'Altri valori confermati';

  @override
  String get healthValuesTrackTooltip => 'Traccia questo valore';

  @override
  String get healthManualSubtitle =>
      'Aggiungi una rilevazione effettuata da te.';

  @override
  String get healthManualFormTitle => 'Dati della rilevazione';

  @override
  String get symptomsEditable => 'Modificabile';

  @override
  String get symptomsRecorded => 'Registrato';

  @override
  String get alertsUnread => 'Da leggere';

  @override
  String get alertsRead => 'Letto';

  @override
  String get bodyTitle => 'Corpo e organi';

  @override
  String get bodySegment => 'Corpo';

  @override
  String get bodyDesktopSubtitle => 'Quadro delle aree del corpo';

  @override
  String get bodySilhouetteSemantics => 'Mappa delle aree del corpo';

  @override
  String get bodyState_ok => 'Nella norma';

  @override
  String get bodyState_monitor => 'Da monitorare';

  @override
  String get bodyState_attention => 'Attenzione';

  @override
  String get bodyState_missing => 'Dato mancante';

  @override
  String get bodyConfidenceComplete => 'Quadro completo';

  @override
  String get bodyConfidencePartial => 'Quadro parziale';

  @override
  String get bodyConfidenceIncomplete => 'Dati da completare';

  @override
  String get bodyConfidenceMissing => 'Dati mancanti';

  @override
  String get bodyAllAreas => 'Tutte le aree';

  @override
  String get bodyEmptyMessage =>
      'Carica un referto o inserisci un valore per vedere il quadro.';

  @override
  String bodyUpdatedOn(Object date) {
    return 'Aggiornato il $date';
  }

  @override
  String get bodyRefresh => 'Aggiorna';

  @override
  String bodyRuleNote(Object version) {
    return 'Il colore indica quanto i valori dell\'area si discostano dai riferimenti; non è una diagnosi. Regola v$version.';
  }

  @override
  String get bodyNotAvailable => 'n.d.';

  @override
  String get bodyLoadError =>
      'Non siamo riusciti a caricare il quadro delle aree.';

  @override
  String get bodyValuesError =>
      'Non siamo riusciti a caricare i valori di quest\'area.';

  @override
  String get bodyAreaMissing => 'Quest\'area non è disponibile.';

  @override
  String bodyCalculatedOn(Object date) {
    return 'Calcolato il $date';
  }

  @override
  String get bodyHistory => 'Storico';

  @override
  String get bodyAreaValues => 'Valori di quest\'area';

  @override
  String get bodyEssential => 'Essenziale';

  @override
  String get bodyNoMappedValues => 'Nessun valore associato';

  @override
  String get bodyNoPresentValues =>
      'Nessun valore disponibile per quest\'area.';

  @override
  String get bodyFullHistory => 'Storico completo';

  @override
  String get bodyHowToRead => 'Come leggere il quadro';

  @override
  String get bodyToday => 'Oggi';

  @override
  String get bodySixMonthsAgo => '6 mesi fa';

  @override
  String get bodyTwelveMonthsAgo => '12 mesi fa';

  @override
  String get bodyTrendImproved => 'Miglioramento';

  @override
  String get bodyTrendWorsened => 'Peggioramento';

  @override
  String get bodyTrendStable => 'Stabile';

  @override
  String get bodyComparison => 'Confronto nel tempo';

  @override
  String get bodyAttentionEpisodes => 'Episodi di attenzione';

  @override
  String get bodyNoEpisodes => 'Nessun episodio di attenzione.';

  @override
  String bodyDurationDays(Object count) {
    return '$count giorni';
  }

  @override
  String get bodyStateTimeline => 'Linea del tempo degli stati';

  @override
  String bodyValuesCount(Object count) {
    return '$count valori';
  }

  @override
  String get bodyBiomarkerCharts => 'Grafico dei biomarcatori';

  @override
  String get bodyHistoryEmpty => 'Non ci sono ancora calcoli nello storico.';

  @override
  String get bodyHistoryError =>
      'Non siamo riusciti a caricare lo storico dell\'area.';

  @override
  String get bodyDeviationLabel => 'Scostamento dai riferimenti';

  @override
  String get bodyLegendNormal => 'Nella norma';

  @override
  String get bodyLegendAttention => 'Attenzione';

  @override
  String get bodyExplodedView => 'Vista esplosa';

  @override
  String get bodyGenderNotice =>
      'Indica il genere nel profilo per un quadro completo';

  @override
  String get bodyOpenProfile => 'Apri profilo';

  @override
  String homeBodySummary(
      Object attention, Object missing, Object monitor, Object ok) {
    return '$ok aree nella norma · $monitor da monitorare · $attention in attenzione · $missing senza dati';
  }

  @override
  String get commonYes => 'Sì';

  @override
  String get commonNo => 'No';

  @override
  String get preventionNav => 'Prevenzione';

  @override
  String get preventionTitle => 'Prevenzione';

  @override
  String get preventionSubtitle => 'Controlli, scadenze e storico';

  @override
  String get preventionAddReminder => 'Aggiungi promemoria';

  @override
  String get preventionComingSoon => 'In arrivo';

  @override
  String get preventionTabControls => 'I miei controlli';

  @override
  String get preventionTabRisks => 'Rischi e questionari';

  @override
  String get preventionTabHistory => 'Storico';

  @override
  String get preventionNextSteps => 'Prossimi passi';

  @override
  String get preventionRegistered => 'Controlli registrati';

  @override
  String get preventionNoRegistered => 'Nessun controllo registrato.';

  @override
  String get preventionNoUpcoming => 'Nessun controllo da programmare.';

  @override
  String get preventionStatusScheduled => 'Programmata';

  @override
  String get preventionStatusPlan => 'Da programmare';

  @override
  String get preventionStatusAgree => 'Da concordare';

  @override
  String get preventionStatusComplete => 'Da completare';

  @override
  String get preventionPlanShort => 'PROGRAMMA';

  @override
  String get preventionAgreeShort => 'CONCORDA';

  @override
  String get preventionExamDone => 'Ho fatto l\'esame';

  @override
  String get preventionIgnore => 'Ignora';

  @override
  String get preventionIgnoreTitle => 'Ignorare questa raccomandazione?';

  @override
  String get preventionIgnoreReason => 'Motivo (facoltativo)';

  @override
  String get preventionUploadDocument => 'Carica e collega il documento';

  @override
  String get preventionDoneWithoutDocument =>
      'Segna come fatto senza documento';

  @override
  String get preventionInitialQuestionnaires => 'Questionari iniziali';

  @override
  String get preventionLinkExam => 'Collega un nuovo esame';

  @override
  String get preventionDropZone =>
      'Carica il documento dell\'esame per conservarlo nell\'Archivio e collegarlo al controllo.';

  @override
  String get preventionProfileTitle => 'Il profilo di prevenzione';

  @override
  String get preventionAgeMissing => 'Età da completare nel profilo';

  @override
  String preventionAgeValue(int age) {
    return '$age anni';
  }

  @override
  String get preventionLifestyleComplete =>
      'Stili di vita e familiarità completati';

  @override
  String get preventionLifestyleMissing =>
      'Stili di vita e familiarità da completare';

  @override
  String get preventionCompleteQuestionnaire => 'Completa il questionario';

  @override
  String get preventionRisksQuestionnaires => 'Rischi e questionari';

  @override
  String get preventionFamilyCardio => 'Cuore e circolazione';

  @override
  String get preventionFamilyDiabetes => 'Diabete di tipo 2';

  @override
  String get preventionFamilyKidney => 'Reni';

  @override
  String get preventionFamilyFracture => 'Ossa';

  @override
  String get preventionFractureRule => 'Fattori di frattura';

  @override
  String get preventionRiskLow => 'Basso';

  @override
  String get preventionRiskMedium => 'Medio';

  @override
  String get preventionRiskHigh => 'Alto';

  @override
  String get preventionDataIncomplete => 'Dati da completare';

  @override
  String get preventionMissingCardio =>
      'Servono pressione, colesterolo totale, HDL, risposta sul fumo ed età tra 40 e 69 anni.';

  @override
  String get preventionMissingQuestionnaire =>
      'Completa il questionario iniziale.';

  @override
  String get preventionMissingKidney =>
      'Serve un valore recente della creatinina.';

  @override
  String get preventionCompleteData => 'Completa i dati';

  @override
  String preventionCalculatedOn(Object date) {
    return 'Calcolato il $date';
  }

  @override
  String preventionProjection(Object score) {
    return 'Se nulla cambia: $score';
  }

  @override
  String get preventionRuleDraft => 'Regola in validazione';

  @override
  String get preventionWhy => 'Perché';

  @override
  String get preventionOpenHistory => 'Apri lo storico';

  @override
  String preventionScorePercent(Object score) {
    return '$score% a 10 anni';
  }

  @override
  String preventionScorePoints(Object score) {
    return '$score punti';
  }

  @override
  String preventionScoreEgfr(Object score) {
    return '$score mL/min/1,73 m²';
  }

  @override
  String preventionScoreFactors(Object score) {
    return '$score fattori';
  }

  @override
  String get preventionFactorAge => 'Età';

  @override
  String get preventionFactorSex => 'Sesso';

  @override
  String get preventionNotAvailable => 'Non disponibile';

  @override
  String get preventionFraxLink =>
      'Calcola FRAX sul sito ufficiale: https://frax.shef.ac.uk/FRAX/';

  @override
  String get preventionFraxPrivacy =>
      'Nessun dato viene inviato da Medical 24.';

  @override
  String get preventionRiskDisclaimer =>
      'Stime statistiche da algoritmi pubblici, non diagnosi: discutile con il medico.';

  @override
  String get preventionHistoryTitle => 'Storico del rischio';

  @override
  String get preventionHistoryRecommendations =>
      'Controlli conclusi e ignorati';

  @override
  String get preventionRiskTimeline => 'Linea del tempo dei punteggi';

  @override
  String get preventionNoHistory => 'Non c\'è ancora uno storico.';

  @override
  String get preventionReopen => 'Ripristina';

  @override
  String get preventionLoadError =>
      'Non siamo riusciti a caricare la prevenzione.';

  @override
  String get preventionSaveError => 'Non siamo riusciti a salvare le risposte.';

  @override
  String get preventionRecommendationFallback => 'Controllo di prevenzione';

  @override
  String get preventionQuestionnaireTitle => 'Questionario di prevenzione';

  @override
  String get preventionQuestionnaireIntro =>
      'Le risposte servono ai calcoli di prevenzione e si possono cambiare in ogni momento.';

  @override
  String questionnaireStep(int step, String title) {
    return 'Passo $step di 4 · $title';
  }

  @override
  String get questionnaireNext => 'Avanti';

  @override
  String get questionnaireSave => 'Salva le risposte';

  @override
  String questionnaireMissing(String fields) {
    return 'Manca: $fields';
  }

  @override
  String get questionnaireSaved => 'Risposte salvate';

  @override
  String get questionnaireSavedWeightWarning =>
      'Risposte salvate. Non siamo riusciti ad aggiungere il peso allo storico.';

  @override
  String questionnaireLastCompleted(String date) {
    return 'Ultima compilazione: $date';
  }

  @override
  String get questionnaireUpdate => 'Aggiorna';

  @override
  String get questionnaireSummary => 'Riepilogo delle risposte';

  @override
  String questionnaireSummaryMeasures(
      String height, String weight, String waist, String bmi) {
    return 'Altezza $height cm · Peso $weight kg · Vita $waist cm · BMI $bmi';
  }

  @override
  String get questionGroupLifestyle => 'Stile di vita';

  @override
  String get questionGroupFamily => 'Familiarità e salute';

  @override
  String get questionGroupMeasures => 'Misure';

  @override
  String get questionGroupBones => 'Ossa';

  @override
  String get questionSmoker => 'Fumi?';

  @override
  String get questionPhysicalActivity =>
      'Fai almeno 30 minuti di attività fisica al giorno?';

  @override
  String get questionFruitVegetables => 'Mangi frutta o verdura ogni giorno?';

  @override
  String get questionAlcohol => 'Bevi almeno 3 unità di alcol al giorno?';

  @override
  String get questionAntihypertensive => 'Assumi farmaci per la pressione?';

  @override
  String get questionHighGlucose => 'Hai avuto valori alti di glicemia?';

  @override
  String get questionFamilyDiabetes => 'Familiarità per diabete';

  @override
  String get questionFamilyNone => 'Nessuna';

  @override
  String get questionFamilySecond => 'Parenti di secondo grado';

  @override
  String get questionFamilyFirst => 'Parenti di primo grado';

  @override
  String get questionWaist => 'Circonferenza vita';

  @override
  String get questionHeight => 'Altezza';

  @override
  String get questionWeight => 'Peso';

  @override
  String questionWeightRecorded(String date) {
    return 'Ultimo peso registrato il $date; puoi modificarlo.';
  }

  @override
  String get questionBmi => 'Indice di massa corporea';

  @override
  String get questionBmiUnavailable =>
      'BMI non disponibile: servono altezza e un peso recente.';

  @override
  String questionBmiValue(Object value) {
    return 'BMI $value';
  }

  @override
  String get questionPreviousFracture =>
      'Hai avuto una frattura in precedenza?';

  @override
  String get questionParentHipFracture =>
      'Un genitore ha avuto una frattura dell\'anca?';

  @override
  String get questionGlucocorticoids => 'Assumi glucocorticoidi?';

  @override
  String get questionRheumatoid => 'Hai indicato artrite reumatoide?';

  @override
  String get questionSecondaryOsteoporosis =>
      'Hai indicato osteoporosi secondaria?';

  @override
  String get questionBmd => 'Densità ossea';

  @override
  String get homeNextControl => 'Prossimo controllo';

  @override
  String get homeCompleteQuestionnaires => 'Completa i questionari';

  @override
  String get recommendationScreeningMammografia => 'Mammografia';

  @override
  String get recommendationScreeningCervicePap => 'Pap test';

  @override
  String get recommendationScreeningCerviceHpv => 'Test HPV';

  @override
  String get recommendationScreeningColon =>
      'Ricerca del sangue occulto nelle feci';

  @override
  String get recommendationPressione => 'Misurazione della pressione arteriosa';

  @override
  String get recommendationLipidi => 'Profilo lipidico';

  @override
  String get recommendationGlicemia => 'Glicemia a digiuno';

  @override
  String get recommendationPesoBmi => 'Peso e indice di massa corporea';

  @override
  String get recommendationVista => 'Visita oculistica';

  @override
  String get recommendationUdito => 'Controllo dell\'udito';

  @override
  String get recommendationDentista => 'Visita odontoiatrica';

  @override
  String get recommendationDermatologo => 'Controllo dei nei';

  @override
  String get recommendationVaccinoInfluenza => 'Vaccino antinfluenzale';

  @override
  String get recommendationVaccinoPneumococco => 'Vaccino antipneumococcico';

  @override
  String get recommendationVaccinoZoster => 'Vaccino contro l\'herpes zoster';

  @override
  String get recommendationVaccinoTetano =>
      'Richiamo difterite-tetano-pertosse';

  @override
  String get recommendationPsa =>
      'Valutazione del rischio prostatico con il medico';

  @override
  String get recommendationDensitometria => 'Densitometria ossea (MOC)';

  @override
  String get recommendationAaa => 'Ecografia dell\'aorta addominale';

  @override
  String get recommendationGlicemiaFindrisc => 'Glicemia a digiuno';

  @override
  String get recommendationLipidiScore2 => 'Controllo dei lipidi';

  @override
  String get recommendationVisitaCardiologicaScore2 => 'Visita cardiologica';

  @override
  String get recommendationVisitaNefrologicaEgfr => 'Visita nefrologica';

  @override
  String get recommendationCreatininaEgfr => 'Controllo della creatinina';

  @override
  String get recommendationDensitometriaFrattura =>
      'Densitometria per rischio frattura';

  @override
  String get recommendationLevelImproved => 'Livello di rischio migliorato';

  @override
  String get recommendationScreeningMammografiaReason =>
      'Programma di screening organizzato del SSN; alcune Regioni includono 45–74 anni.';

  @override
  String get recommendationScreeningCervicePapReason =>
      'Programma di screening organizzato del SSN.';

  @override
  String get recommendationScreeningCerviceHpvReason =>
      'Programma di screening organizzato del SSN.';

  @override
  String get recommendationScreeningColonReason =>
      'Programma di screening organizzato del SSN; alcune Regioni includono fino a 74 anni.';

  @override
  String get recommendationPressioneReason =>
      'Dai 40 anni il controllo può essere annuale; con valori elevati segue le indicazioni del medico.';

  @override
  String get recommendationLipidiReason =>
      'Può essere più frequente con fattori di rischio o terapia, secondo il medico.';

  @override
  String get recommendationGlicemiaReason =>
      'Può essere anticipata o più frequente con fattori di rischio.';

  @override
  String get recommendationPesoBmiReason =>
      'Controllo periodico di peso e indice di massa corporea.';

  @override
  String get recommendationVistaReason =>
      'Dai 65 anni il controllo può essere annuale.';

  @override
  String get recommendationUditoReason =>
      'Controllo periodico dell\'udito dai 65 anni.';

  @override
  String get recommendationDentistaReason =>
      'Controllo odontoiatrico periodico.';

  @override
  String get recommendationDermatologoReason =>
      'Può essere più frequente con familiarità o molti nei.';

  @override
  String get recommendationVaccinoInfluenzaReason =>
      'Ogni autunno dai 60 anni e per le categorie a rischio.';

  @override
  String get recommendationVaccinoPneumococcoReason =>
      'Una volta, con schema secondo il calendario vaccinale nazionale.';

  @override
  String get recommendationVaccinoZosterReason =>
      'Secondo il calendario vaccinale nazionale.';

  @override
  String get recommendationVaccinoTetanoReason => 'Richiamo ogni 10 anni.';

  @override
  String get recommendationPsaReason =>
      'Decisione condivisa con il medico; non è uno screening di popolazione.';

  @override
  String get recommendationDensitometriaReason =>
      'Prima in presenza di fattori di rischio; uomini dai 70 anni.';

  @override
  String get recommendationAaaReason =>
      'Una volta tra 65 e 75 anni se fumatore o ex fumatore.';

  @override
  String get recommendationGlicemiaFindriscReason =>
      'Consigliata perché il punteggio FINDRISC è medio o alto';

  @override
  String get recommendationLipidiScore2Reason =>
      'Consigliata perché il punteggio SCORE2 è medio o alto';

  @override
  String get recommendationVisitaCardiologicaScore2Reason =>
      'Consigliata perché il punteggio SCORE2 indica un rischio aumentato';

  @override
  String get recommendationVisitaNefrologicaEgfrReason =>
      'Consigliata perché il valore eGFR è ridotto';

  @override
  String get recommendationCreatininaEgfrReason =>
      'Consigliata perché la creatinina richiede un controllo';

  @override
  String get recommendationDensitometriaFratturaReason =>
      'Consigliata perché il rischio di frattura è medio o alto';
}
