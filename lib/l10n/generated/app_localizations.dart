import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it')
  ];

  /// No description provided for @healthExportCsv.
  ///
  /// In it, this message translates to:
  /// **'Esporta CSV'**
  String get healthExportCsv;

  /// No description provided for @healthExportError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile esportare i valori.'**
  String get healthExportError;

  /// No description provided for @appTitle.
  ///
  /// In it, this message translates to:
  /// **'Medical 24'**
  String get appTitle;

  /// No description provided for @commonContinue.
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get commonContinue;

  /// No description provided for @commonBack.
  ///
  /// In it, this message translates to:
  /// **'Indietro'**
  String get commonBack;

  /// No description provided for @commonCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get commonSave;

  /// No description provided for @commonRetry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In it, this message translates to:
  /// **'Caricamento…'**
  String get commonLoading;

  /// No description provided for @commonErrorTitle.
  ///
  /// In it, this message translates to:
  /// **'Qualcosa non ha funzionato'**
  String get commonErrorTitle;

  /// No description provided for @commonEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Non c\'è ancora niente qui'**
  String get commonEmptyTitle;

  /// No description provided for @commonRequired.
  ///
  /// In it, this message translates to:
  /// **'Campo obbligatorio'**
  String get commonRequired;

  /// No description provided for @commonClose.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In it, this message translates to:
  /// **'Conferma'**
  String get commonConfirm;

  /// No description provided for @commonOptional.
  ///
  /// In it, this message translates to:
  /// **'Facoltativo'**
  String get commonOptional;

  /// No description provided for @commonAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get commonAdd;

  /// No description provided for @addUploadReport.
  ///
  /// In it, this message translates to:
  /// **'Carica un referto'**
  String get addUploadReport;

  /// No description provided for @addManualValue.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un valore'**
  String get addManualValue;

  /// No description provided for @breadcrumbLabel.
  ///
  /// In it, this message translates to:
  /// **'Percorso'**
  String get breadcrumbLabel;

  /// No description provided for @disclaimerClinical.
  ///
  /// In it, this message translates to:
  /// **'I valori sono letti dal referto e confrontati con intervalli di riferimento: non sono una diagnosi, parlane con il tuo medico.'**
  String get disclaimerClinical;

  /// No description provided for @authWelcomeTitle.
  ///
  /// In it, this message translates to:
  /// **'La tua salute, in ordine'**
  String get authWelcomeTitle;

  /// No description provided for @authWelcomeSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Raccogli i documenti sanitari, capisci i tuoi valori e condividili con il tuo medico.'**
  String get authWelcomeSubtitle;

  /// No description provided for @authWelcomeSignIn.
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get authWelcomeSignIn;

  /// No description provided for @authWelcomeSignUp.
  ///
  /// In it, this message translates to:
  /// **'Crea un account'**
  String get authWelcomeSignUp;

  /// No description provided for @authSignInTitle.
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get authSignInTitle;

  /// No description provided for @authSignUpTitle.
  ///
  /// In it, this message translates to:
  /// **'Crea un account'**
  String get authSignUpTitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In it, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In it, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordHint.
  ///
  /// In it, this message translates to:
  /// **'Almeno 8 caratteri'**
  String get authPasswordHint;

  /// No description provided for @authEmailInvalid.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un\'email valida'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordShort.
  ///
  /// In it, this message translates to:
  /// **'La password deve avere almeno 8 caratteri'**
  String get authPasswordShort;

  /// No description provided for @authSignInAction.
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get authSignInAction;

  /// No description provided for @authSignUpAction.
  ///
  /// In it, this message translates to:
  /// **'Crea account'**
  String get authSignUpAction;

  /// No description provided for @authForgotPassword.
  ///
  /// In it, this message translates to:
  /// **'Password dimenticata?'**
  String get authForgotPassword;

  /// No description provided for @authNoAccount.
  ///
  /// In it, this message translates to:
  /// **'Non hai un account?'**
  String get authNoAccount;

  /// No description provided for @authHasAccount.
  ///
  /// In it, this message translates to:
  /// **'Hai già un account?'**
  String get authHasAccount;

  /// No description provided for @authOrDivider.
  ///
  /// In it, this message translates to:
  /// **'oppure'**
  String get authOrDivider;

  /// No description provided for @authAppleAction.
  ///
  /// In it, this message translates to:
  /// **'Continua con Apple'**
  String get authAppleAction;

  /// No description provided for @authGoogleAction.
  ///
  /// In it, this message translates to:
  /// **'Continua con Google'**
  String get authGoogleAction;

  /// No description provided for @authOtpAction.
  ///
  /// In it, this message translates to:
  /// **'Accedi con un codice via email'**
  String get authOtpAction;

  /// No description provided for @authOtpTitle.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il codice'**
  String get authOtpTitle;

  /// No description provided for @authOtpSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Abbiamo inviato un codice a 6 cifre a {email}. È valido 10 minuti.'**
  String authOtpSubtitle(String email);

  /// No description provided for @authOtpLabel.
  ///
  /// In it, this message translates to:
  /// **'Codice a 6 cifre'**
  String get authOtpLabel;

  /// No description provided for @authOtpVerify.
  ///
  /// In it, this message translates to:
  /// **'Verifica'**
  String get authOtpVerify;

  /// No description provided for @authOtpResend.
  ///
  /// In it, this message translates to:
  /// **'Invia di nuovo'**
  String get authOtpResend;

  /// No description provided for @authOtpSent.
  ///
  /// In it, this message translates to:
  /// **'Codice inviato'**
  String get authOtpSent;

  /// No description provided for @authResetTitle.
  ///
  /// In it, this message translates to:
  /// **'Recupera la password'**
  String get authResetTitle;

  /// No description provided for @authResetSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Ti inviamo un codice via email per impostare una nuova password.'**
  String get authResetSubtitle;

  /// No description provided for @authResetAction.
  ///
  /// In it, this message translates to:
  /// **'Invia il codice'**
  String get authResetAction;

  /// No description provided for @authNewPasswordLabel.
  ///
  /// In it, this message translates to:
  /// **'Nuova password'**
  String get authNewPasswordLabel;

  /// No description provided for @authResetDone.
  ///
  /// In it, this message translates to:
  /// **'Password aggiornata'**
  String get authResetDone;

  /// No description provided for @authSignOut.
  ///
  /// In it, this message translates to:
  /// **'Esci'**
  String get authSignOut;

  /// No description provided for @authPrivacyNote.
  ///
  /// In it, this message translates to:
  /// **'I dati sanitari sono trattati come categoria particolare (art. 9 GDPR) e restano in Europa.'**
  String get authPrivacyNote;

  /// No description provided for @authDevShortcutsTitle.
  ///
  /// In it, this message translates to:
  /// **'Accesso rapido (sviluppo)'**
  String get authDevShortcutsTitle;

  /// No description provided for @authDevShortcutAdmin.
  ///
  /// In it, this message translates to:
  /// **'Amministratore'**
  String get authDevShortcutAdmin;

  /// No description provided for @authDevShortcutAlice.
  ///
  /// In it, this message translates to:
  /// **'Alice'**
  String get authDevShortcutAlice;

  /// No description provided for @authDevShortcutBob.
  ///
  /// In it, this message translates to:
  /// **'Bob'**
  String get authDevShortcutBob;

  /// No description provided for @onboardingConsentTitle.
  ///
  /// In it, this message translates to:
  /// **'I tuoi consensi'**
  String get onboardingConsentTitle;

  /// No description provided for @onboardingConsentSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Separati e revocabili in ogni momento dalle impostazioni.'**
  String get onboardingConsentSubtitle;

  /// No description provided for @onboardingConsentHealth.
  ///
  /// In it, this message translates to:
  /// **'Trattamento dei dati sanitari'**
  String get onboardingConsentHealth;

  /// No description provided for @onboardingConsentHealthBody.
  ///
  /// In it, this message translates to:
  /// **'Consenso esplicito (art. 9.2.a GDPR) al trattamento dei dati sanitari per erogare il servizio. Senza questo consenso l\'app non può funzionare.'**
  String get onboardingConsentHealthBody;

  /// No description provided for @onboardingConsentAi.
  ///
  /// In it, this message translates to:
  /// **'Elaborazione IA dei documenti'**
  String get onboardingConsentAi;

  /// No description provided for @onboardingConsentAiBody.
  ///
  /// In it, this message translates to:
  /// **'I documenti vengono letti da un modello di IA per estrarre i valori. Senza questo consenso l\'archivio funziona, le analisi no.'**
  String get onboardingConsentAiBody;

  /// No description provided for @onboardingConsentMarketing.
  ///
  /// In it, this message translates to:
  /// **'Comunicazioni e marketing'**
  String get onboardingConsentMarketing;

  /// No description provided for @onboardingConsentMarketingBody.
  ///
  /// In it, this message translates to:
  /// **'Novità sul prodotto e contenuti di prevenzione. Facoltativo, mai in bundle.'**
  String get onboardingConsentMarketingBody;

  /// No description provided for @onboardingConsentRequired.
  ///
  /// In it, this message translates to:
  /// **'Obbligatorio'**
  String get onboardingConsentRequired;

  /// No description provided for @onboardingConsentMissing.
  ///
  /// In it, this message translates to:
  /// **'Per continuare serve il consenso al trattamento dei dati sanitari.'**
  String get onboardingConsentMissing;

  /// No description provided for @onboardingBasicsTitle.
  ///
  /// In it, this message translates to:
  /// **'Dati di base'**
  String get onboardingBasicsTitle;

  /// No description provided for @onboardingBasicsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Servono per usare gli intervalli corretti per età e genere.'**
  String get onboardingBasicsSubtitle;

  /// No description provided for @onboardingNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome e cognome'**
  String get onboardingNameLabel;

  /// No description provided for @onboardingBirthDateLabel.
  ///
  /// In it, this message translates to:
  /// **'Data di nascita'**
  String get onboardingBirthDateLabel;

  /// No description provided for @onboardingBirthDatePick.
  ///
  /// In it, this message translates to:
  /// **'Scegli la data'**
  String get onboardingBirthDatePick;

  /// No description provided for @onboardingGenderLabel.
  ///
  /// In it, this message translates to:
  /// **'Genere'**
  String get onboardingGenderLabel;

  /// No description provided for @onboardingGenderFemale.
  ///
  /// In it, this message translates to:
  /// **'Femminile'**
  String get onboardingGenderFemale;

  /// No description provided for @onboardingGenderMale.
  ///
  /// In it, this message translates to:
  /// **'Maschile'**
  String get onboardingGenderMale;

  /// No description provided for @onboardingGenderOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get onboardingGenderOther;

  /// No description provided for @onboardingGenderUndisclosed.
  ///
  /// In it, this message translates to:
  /// **'Preferisco non dirlo'**
  String get onboardingGenderUndisclosed;

  /// No description provided for @onboardingLanguageLabel.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get onboardingLanguageLabel;

  /// No description provided for @onboardingUnitsLabel.
  ///
  /// In it, this message translates to:
  /// **'Unità di misura'**
  String get onboardingUnitsLabel;

  /// No description provided for @onboardingCountryLabel.
  ///
  /// In it, this message translates to:
  /// **'Paese'**
  String get onboardingCountryLabel;

  /// No description provided for @onboardingReadyTitle.
  ///
  /// In it, this message translates to:
  /// **'Profilo pronto'**
  String get onboardingReadyTitle;

  /// No description provided for @onboardingReadySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Da qui puoi caricare il primo documento e vedere il tuo stato di salute.'**
  String get onboardingReadySubtitle;

  /// No description provided for @onboardingReadyAction.
  ///
  /// In it, this message translates to:
  /// **'Entra in Medical 24'**
  String get onboardingReadyAction;

  /// No description provided for @onboardingStepLabel.
  ///
  /// In it, this message translates to:
  /// **'Passo {current} di {total}'**
  String onboardingStepLabel(String current, String total);

  /// No description provided for @navHome.
  ///
  /// In it, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navHealth.
  ///
  /// In it, this message translates to:
  /// **'Salute'**
  String get navHealth;

  /// No description provided for @navArchive.
  ///
  /// In it, this message translates to:
  /// **'Archivio'**
  String get navArchive;

  /// No description provided for @navTreatments.
  ///
  /// In it, this message translates to:
  /// **'Cure'**
  String get navTreatments;

  /// No description provided for @navDoctor.
  ///
  /// In it, this message translates to:
  /// **'Medico'**
  String get navDoctor;

  /// No description provided for @navMyDoctor.
  ///
  /// In it, this message translates to:
  /// **'Il mio medico'**
  String get navMyDoctor;

  /// No description provided for @navSettings.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get navSettings;

  /// No description provided for @navOverview.
  ///
  /// In it, this message translates to:
  /// **'Panoramica'**
  String get navOverview;

  /// No description provided for @navMyHealth.
  ///
  /// In it, this message translates to:
  /// **'La mia salute'**
  String get navMyHealth;

  /// No description provided for @navHealthSpace.
  ///
  /// In it, this message translates to:
  /// **'Il mio spazio salute'**
  String get navHealthSpace;

  /// No description provided for @navHelp.
  ///
  /// In it, this message translates to:
  /// **'Aiuto'**
  String get navHelp;

  /// No description provided for @navProfile.
  ///
  /// In it, this message translates to:
  /// **'Profilo'**
  String get navProfile;

  /// No description provided for @disclaimerPhone.
  ///
  /// In it, this message translates to:
  /// **'Informazioni da discutere con il medico.'**
  String get disclaimerPhone;

  /// No description provided for @disclaimerDesktop.
  ///
  /// In it, this message translates to:
  /// **'Le informazioni non sostituiscono il parere del medico.'**
  String get disclaimerDesktop;

  /// No description provided for @homeGreeting.
  ///
  /// In it, this message translates to:
  /// **'Ciao, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeGreetingNoName.
  ///
  /// In it, this message translates to:
  /// **'Ciao'**
  String get homeGreetingNoName;

  /// No description provided for @homeSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Ecco il punto sulla tua salute.'**
  String get homeSubtitle;

  /// No description provided for @homeProfileCardTitle.
  ///
  /// In it, this message translates to:
  /// **'Il tuo profilo'**
  String get homeProfileCardTitle;

  /// No description provided for @homeProfileCompletion.
  ///
  /// In it, this message translates to:
  /// **'Profilo completo al {percent}%'**
  String homeProfileCompletion(String percent);

  /// No description provided for @homeNextStepTitle.
  ///
  /// In it, this message translates to:
  /// **'Prossimo passo'**
  String get homeNextStepTitle;

  /// No description provided for @homeNextStepBody.
  ///
  /// In it, this message translates to:
  /// **'L\'archivio dei documenti arriva con il prossimo rilascio.'**
  String get homeNextStepBody;

  /// No description provided for @healthTitle.
  ///
  /// In it, this message translates to:
  /// **'Salute'**
  String get healthTitle;

  /// No description provided for @healthEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Stato di salute, parametri e storico dei valori arrivano con il modulo successivo.'**
  String get healthEmptyBody;

  /// No description provided for @healthValuesTitle.
  ///
  /// In it, this message translates to:
  /// **'I miei valori'**
  String get healthValuesTitle;

  /// No description provided for @healthValuesSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca un biomarcatore'**
  String get healthValuesSearch;

  /// No description provided for @healthValuesFavorites.
  ///
  /// In it, this message translates to:
  /// **'Preferiti'**
  String get healthValuesFavorites;

  /// No description provided for @healthValuesEssentials.
  ///
  /// In it, this message translates to:
  /// **'Essenziali'**
  String get healthValuesEssentials;

  /// No description provided for @healthValuesAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get healthValuesAll;

  /// No description provided for @healthValuesOnlyWithValues.
  ///
  /// In it, this message translates to:
  /// **'Solo con valori'**
  String get healthValuesOnlyWithValues;

  /// No description provided for @healthValuesError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a caricare i valori.'**
  String get healthValuesError;

  /// No description provided for @healthValuesEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun valore da mostrare'**
  String get healthValuesEmptyTitle;

  /// No description provided for @healthValuesEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'I valori arrivano dai referti che carichi oppure puoi inserirli a mano.'**
  String get healthValuesEmptyBody;

  /// No description provided for @healthValuesUploadReport.
  ///
  /// In it, this message translates to:
  /// **'Carica un referto'**
  String get healthValuesUploadReport;

  /// No description provided for @healthValuesManual.
  ///
  /// In it, this message translates to:
  /// **'Inserisci a mano'**
  String get healthValuesManual;

  /// No description provided for @healthValuesNoValue.
  ///
  /// In it, this message translates to:
  /// **'Nessun valore'**
  String get healthValuesNoValue;

  /// No description provided for @healthValuesCount.
  ///
  /// In it, this message translates to:
  /// **'{count} valori'**
  String healthValuesCount(String count);

  /// No description provided for @healthValuesTrack.
  ///
  /// In it, this message translates to:
  /// **'+ Traccia'**
  String get healthValuesTrack;

  /// No description provided for @healthValuesTracked.
  ///
  /// In it, this message translates to:
  /// **'Tracciato'**
  String get healthValuesTracked;

  /// No description provided for @healthValuesFavorite.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi ai preferiti'**
  String get healthValuesFavorite;

  /// No description provided for @healthValuesUnfavorite.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dai preferiti'**
  String get healthValuesUnfavorite;

  /// No description provided for @healthSelectValueTitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli un biomarcatore'**
  String get healthSelectValueTitle;

  /// No description provided for @healthSelectValueBody.
  ///
  /// In it, this message translates to:
  /// **'Seleziona un valore dalla lista per vedere lo storico completo.'**
  String get healthSelectValueBody;

  /// No description provided for @healthPeriodAll.
  ///
  /// In it, this message translates to:
  /// **'Tutto'**
  String get healthPeriodAll;

  /// No description provided for @healthPeriodYear.
  ///
  /// In it, this message translates to:
  /// **'12 mesi'**
  String get healthPeriodYear;

  /// No description provided for @healthPeriod90.
  ///
  /// In it, this message translates to:
  /// **'90 giorni'**
  String get healthPeriod90;

  /// No description provided for @healthPeriod30.
  ///
  /// In it, this message translates to:
  /// **'30 giorni'**
  String get healthPeriod30;

  /// No description provided for @healthCompareWith.
  ///
  /// In it, this message translates to:
  /// **'Confronta con…'**
  String get healthCompareWith;

  /// No description provided for @healthCompareRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi confronto'**
  String get healthCompareRemove;

  /// No description provided for @healthChartNormalized.
  ///
  /// In it, this message translates to:
  /// **'Serie normalizzate 0–100'**
  String get healthChartNormalized;

  /// No description provided for @healthChartSemantics.
  ///
  /// In it, this message translates to:
  /// **'Grafico dello storico dei valori'**
  String get healthChartSemantics;

  /// No description provided for @healthHistoryNoPoints.
  ///
  /// In it, this message translates to:
  /// **'Nessun valore nel periodo selezionato.'**
  String get healthHistoryNoPoints;

  /// No description provided for @healthStatsMinimum.
  ///
  /// In it, this message translates to:
  /// **'Minimo'**
  String get healthStatsMinimum;

  /// No description provided for @healthStatsMaximum.
  ///
  /// In it, this message translates to:
  /// **'Massimo'**
  String get healthStatsMaximum;

  /// No description provided for @healthStatsAverage.
  ///
  /// In it, this message translates to:
  /// **'Media'**
  String get healthStatsAverage;

  /// No description provided for @healthStatsLatest.
  ///
  /// In it, this message translates to:
  /// **'Ultimo'**
  String get healthStatsLatest;

  /// No description provided for @healthStatsChange.
  ///
  /// In it, this message translates to:
  /// **'Variazione'**
  String get healthStatsChange;

  /// No description provided for @healthStatsCount.
  ///
  /// In it, this message translates to:
  /// **'Valori'**
  String get healthStatsCount;

  /// No description provided for @healthEpisodesTitle.
  ///
  /// In it, this message translates to:
  /// **'Episodi fuori soglia'**
  String get healthEpisodesTitle;

  /// No description provided for @healthEpisodesEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun episodio fuori soglia.'**
  String get healthEpisodesEmpty;

  /// No description provided for @healthEpisodeOngoing.
  ///
  /// In it, this message translates to:
  /// **'in corso'**
  String get healthEpisodeOngoing;

  /// No description provided for @healthEpisodeCount.
  ///
  /// In it, this message translates to:
  /// **'{count} valori'**
  String healthEpisodeCount(String count);

  /// No description provided for @healthTableTitle.
  ///
  /// In it, this message translates to:
  /// **'Tutti i valori'**
  String get healthTableTitle;

  /// No description provided for @healthTableDate.
  ///
  /// In it, this message translates to:
  /// **'Data'**
  String get healthTableDate;

  /// No description provided for @healthTableValue.
  ///
  /// In it, this message translates to:
  /// **'Valore e unità'**
  String get healthTableValue;

  /// No description provided for @healthTableStatus.
  ///
  /// In it, this message translates to:
  /// **'Stato'**
  String get healthTableStatus;

  /// No description provided for @healthTableOrigin.
  ///
  /// In it, this message translates to:
  /// **'Origine'**
  String get healthTableOrigin;

  /// No description provided for @healthOrigin_document.
  ///
  /// In it, this message translates to:
  /// **'Referto'**
  String get healthOrigin_document;

  /// No description provided for @healthOrigin_manual.
  ///
  /// In it, this message translates to:
  /// **'Manuale'**
  String get healthOrigin_manual;

  /// No description provided for @healthOrigin_device.
  ///
  /// In it, this message translates to:
  /// **'Dispositivo'**
  String get healthOrigin_device;

  /// No description provided for @healthManualTitle.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un valore'**
  String get healthManualTitle;

  /// No description provided for @healthManualParameter.
  ///
  /// In it, this message translates to:
  /// **'Parametro'**
  String get healthManualParameter;

  /// No description provided for @healthManualPressure.
  ///
  /// In it, this message translates to:
  /// **'Pressione'**
  String get healthManualPressure;

  /// No description provided for @healthManualValue.
  ///
  /// In it, this message translates to:
  /// **'Valore'**
  String get healthManualValue;

  /// No description provided for @healthManualSystolic.
  ///
  /// In it, this message translates to:
  /// **'Pressione sistolica'**
  String get healthManualSystolic;

  /// No description provided for @healthManualDiastolic.
  ///
  /// In it, this message translates to:
  /// **'Pressione diastolica'**
  String get healthManualDiastolic;

  /// No description provided for @healthManualUnit.
  ///
  /// In it, this message translates to:
  /// **'Unità'**
  String get healthManualUnit;

  /// No description provided for @healthManualNumberRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un numero valido.'**
  String get healthManualNumberRequired;

  /// No description provided for @healthManualPlausibleRange.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un valore plausibile tra {min} e {max} {unit}.'**
  String healthManualPlausibleRange(String min, String max, String unit);

  /// No description provided for @healthManualSaved.
  ///
  /// In it, this message translates to:
  /// **'Valore salvato.'**
  String get healthManualSaved;

  /// No description provided for @healthManualError_manual_value_not_plausible.
  ///
  /// In it, this message translates to:
  /// **'Il valore è fuori dall\'intervallo plausibile.'**
  String get healthManualError_manual_value_not_plausible;

  /// No description provided for @healthManualError_manual_unit_not_supported.
  ///
  /// In it, this message translates to:
  /// **'Questa unità non è supportata per il parametro.'**
  String get healthManualError_manual_unit_not_supported;

  /// No description provided for @healthManualError_manual_code_not_allowed.
  ///
  /// In it, this message translates to:
  /// **'Questo parametro non può essere inserito manualmente.'**
  String get healthManualError_manual_code_not_allowed;

  /// No description provided for @healthManualError_not_allowed.
  ///
  /// In it, this message translates to:
  /// **'Non hai il permesso di inserire questo valore.'**
  String get healthManualError_not_allowed;

  /// No description provided for @healthManualError_unknown.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a salvare il valore. Riprova.'**
  String get healthManualError_unknown;

  /// No description provided for @archiveTitle.
  ///
  /// In it, this message translates to:
  /// **'Archivio'**
  String get archiveTitle;

  /// No description provided for @archiveEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Qui vivranno i tuoi documenti sanitari, con categorie e ricerca.'**
  String get archiveEmptyBody;

  /// No description provided for @treatmentsTitle.
  ///
  /// In it, this message translates to:
  /// **'Cure'**
  String get treatmentsTitle;

  /// No description provided for @treatmentsEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Il database delle cure arriva con il modulo dedicato.'**
  String get treatmentsEmptyBody;

  /// No description provided for @doctorTitle.
  ///
  /// In it, this message translates to:
  /// **'Medico'**
  String get doctorTitle;

  /// No description provided for @doctorEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Dossier, domande al medico e condivisione sicura arrivano dopo.'**
  String get doctorEmptyBody;

  /// No description provided for @settingsTitle.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settingsTitle;

  /// No description provided for @settingsProfileSection.
  ///
  /// In it, this message translates to:
  /// **'Profilo'**
  String get settingsProfileSection;

  /// No description provided for @settingsPreferencesSection.
  ///
  /// In it, this message translates to:
  /// **'Preferenze'**
  String get settingsPreferencesSection;

  /// No description provided for @settingsSecuritySection.
  ///
  /// In it, this message translates to:
  /// **'Sicurezza'**
  String get settingsSecuritySection;

  /// No description provided for @settingsPrivacySection.
  ///
  /// In it, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacySection;

  /// No description provided for @settingsAboutSection.
  ///
  /// In it, this message translates to:
  /// **'Informazioni'**
  String get settingsAboutSection;

  /// No description provided for @settingsEditProfile.
  ///
  /// In it, this message translates to:
  /// **'Modifica profilo'**
  String get settingsEditProfile;

  /// No description provided for @settingsLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get settingsLanguage;

  /// No description provided for @settingsUnits.
  ///
  /// In it, this message translates to:
  /// **'Unità'**
  String get settingsUnits;

  /// No description provided for @settingsBiometricLock.
  ///
  /// In it, this message translates to:
  /// **'Blocco biometrico'**
  String get settingsBiometricLock;

  /// No description provided for @settingsBiometricLockBody.
  ///
  /// In it, this message translates to:
  /// **'Chiedi Face ID, impronta o PIN all\'apertura dell\'app.'**
  String get settingsBiometricLockBody;

  /// No description provided for @settingsBiometricUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Questo dispositivo non supporta il blocco biometrico.'**
  String get settingsBiometricUnavailable;

  /// No description provided for @settingsPinFallback.
  ///
  /// In it, this message translates to:
  /// **'PIN di riserva'**
  String get settingsPinFallback;

  /// No description provided for @settingsPinSet.
  ///
  /// In it, this message translates to:
  /// **'Imposta il PIN'**
  String get settingsPinSet;

  /// No description provided for @settingsPinLabel.
  ///
  /// In it, this message translates to:
  /// **'PIN di 6 cifre'**
  String get settingsPinLabel;

  /// No description provided for @settingsPinSaved.
  ///
  /// In it, this message translates to:
  /// **'PIN salvato'**
  String get settingsPinSaved;

  /// No description provided for @settingsExportData.
  ///
  /// In it, this message translates to:
  /// **'Esporta i miei dati'**
  String get settingsExportData;

  /// No description provided for @settingsExportBody.
  ///
  /// In it, this message translates to:
  /// **'Ricevi profilo, consensi e registro degli accessi in formato leggibile.'**
  String get settingsExportBody;

  /// No description provided for @settingsExportDone.
  ///
  /// In it, this message translates to:
  /// **'Export pronto'**
  String get settingsExportDone;

  /// No description provided for @settingsConsents.
  ///
  /// In it, this message translates to:
  /// **'Registro dei consensi'**
  String get settingsConsents;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In it, this message translates to:
  /// **'Informativa privacy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In it, this message translates to:
  /// **'Elimina account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'Cancellazione immediata dell\'accesso e rimozione definitiva dei dati entro 30 giorni.'**
  String get settingsDeleteBody;

  /// No description provided for @settingsDeleteConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare l\'account?'**
  String get settingsDeleteConfirmTitle;

  /// No description provided for @settingsDeleteConfirmBody.
  ///
  /// In it, this message translates to:
  /// **'L\'accesso si chiude subito. I dati vengono rimossi definitivamente entro 30 giorni. L\'operazione non si annulla.'**
  String get settingsDeleteConfirmBody;

  /// No description provided for @settingsDeleteConfirmAction.
  ///
  /// In it, this message translates to:
  /// **'Elimina definitivamente'**
  String get settingsDeleteConfirmAction;

  /// No description provided for @settingsAppVersion.
  ///
  /// In it, this message translates to:
  /// **'Versione app'**
  String get settingsAppVersion;

  /// No description provided for @consentsLogTitle.
  ///
  /// In it, this message translates to:
  /// **'Registro dei consensi'**
  String get consentsLogTitle;

  /// No description provided for @consentsLogEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun consenso registrato.'**
  String get consentsLogEmpty;

  /// No description provided for @consentGranted.
  ///
  /// In it, this message translates to:
  /// **'Concesso'**
  String get consentGranted;

  /// No description provided for @consentRevoked.
  ///
  /// In it, this message translates to:
  /// **'Revocato'**
  String get consentRevoked;

  /// No description provided for @lockTitle.
  ///
  /// In it, this message translates to:
  /// **'Medical 24 è bloccata'**
  String get lockTitle;

  /// No description provided for @lockSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Sblocca per vedere i tuoi dati.'**
  String get lockSubtitle;

  /// No description provided for @lockUnlock.
  ///
  /// In it, this message translates to:
  /// **'Sblocca'**
  String get lockUnlock;

  /// No description provided for @lockUsePin.
  ///
  /// In it, this message translates to:
  /// **'Usa il PIN'**
  String get lockUsePin;

  /// No description provided for @lockPinWrong.
  ///
  /// In it, this message translates to:
  /// **'PIN errato'**
  String get lockPinWrong;

  /// No description provided for @archiveSearchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca nei documenti'**
  String get archiveSearchHint;

  /// No description provided for @archiveClearSearch.
  ///
  /// In it, this message translates to:
  /// **'Cancella ricerca'**
  String get archiveClearSearch;

  /// No description provided for @archiveSortLabel.
  ///
  /// In it, this message translates to:
  /// **'Ordina per'**
  String get archiveSortLabel;

  /// No description provided for @archiveSort_dateDesc.
  ///
  /// In it, this message translates to:
  /// **'Data, più recenti'**
  String get archiveSort_dateDesc;

  /// No description provided for @archiveSort_dateAsc.
  ///
  /// In it, this message translates to:
  /// **'Data, meno recenti'**
  String get archiveSort_dateAsc;

  /// No description provided for @archiveSort_category.
  ///
  /// In it, this message translates to:
  /// **'Categoria'**
  String get archiveSort_category;

  /// No description provided for @archiveSort_doctor.
  ///
  /// In it, this message translates to:
  /// **'Medico'**
  String get archiveSort_doctor;

  /// No description provided for @archiveSort_facility.
  ///
  /// In it, this message translates to:
  /// **'Struttura'**
  String get archiveSort_facility;

  /// No description provided for @archiveCategories.
  ///
  /// In it, this message translates to:
  /// **'Categorie'**
  String get archiveCategories;

  /// No description provided for @archiveResetFilters.
  ///
  /// In it, this message translates to:
  /// **'Azzera filtri'**
  String get archiveResetFilters;

  /// No description provided for @archiveCategory_exams.
  ///
  /// In it, this message translates to:
  /// **'Esami'**
  String get archiveCategory_exams;

  /// No description provided for @archiveCategory_reports.
  ///
  /// In it, this message translates to:
  /// **'Referti'**
  String get archiveCategory_reports;

  /// No description provided for @archiveCategory_prescriptions.
  ///
  /// In it, this message translates to:
  /// **'Prescrizioni'**
  String get archiveCategory_prescriptions;

  /// No description provided for @archiveCategory_radiology.
  ///
  /// In it, this message translates to:
  /// **'Radiologia'**
  String get archiveCategory_radiology;

  /// No description provided for @archiveCategory_vaccinations.
  ///
  /// In it, this message translates to:
  /// **'Vaccinazioni'**
  String get archiveCategory_vaccinations;

  /// No description provided for @archiveCategory_invoices.
  ///
  /// In it, this message translates to:
  /// **'Fatture'**
  String get archiveCategory_invoices;

  /// No description provided for @archiveCategory_consents.
  ///
  /// In it, this message translates to:
  /// **'Consensi'**
  String get archiveCategory_consents;

  /// No description provided for @archiveCategory_cards.
  ///
  /// In it, this message translates to:
  /// **'Tessere'**
  String get archiveCategory_cards;

  /// No description provided for @archiveCategory_other.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get archiveCategory_other;

  /// No description provided for @archiveStatus_uploading.
  ///
  /// In it, this message translates to:
  /// **'Caricato'**
  String get archiveStatus_uploading;

  /// No description provided for @archiveStatus_uploaded.
  ///
  /// In it, this message translates to:
  /// **'Caricato'**
  String get archiveStatus_uploaded;

  /// No description provided for @archiveStatus_processing.
  ///
  /// In it, this message translates to:
  /// **'In analisi'**
  String get archiveStatus_processing;

  /// No description provided for @archiveStatus_analyzed.
  ///
  /// In it, this message translates to:
  /// **'Analizzato'**
  String get archiveStatus_analyzed;

  /// No description provided for @archiveStatus_needs_review.
  ///
  /// In it, this message translates to:
  /// **'Da verificare'**
  String get archiveStatus_needs_review;

  /// No description provided for @archiveStatus_failed.
  ///
  /// In it, this message translates to:
  /// **'Errore'**
  String get archiveStatus_failed;

  /// No description provided for @archiveGroupYear.
  ///
  /// In it, this message translates to:
  /// **'Anno'**
  String get archiveGroupYear;

  /// No description provided for @archiveGroupEpisode.
  ///
  /// In it, this message translates to:
  /// **'Episodio'**
  String get archiveGroupEpisode;

  /// No description provided for @archiveGroupMonth.
  ///
  /// In it, this message translates to:
  /// **'Mese'**
  String get archiveGroupMonth;

  /// No description provided for @archiveDateUnknown.
  ///
  /// In it, this message translates to:
  /// **'Data non disponibile'**
  String get archiveDateUnknown;

  /// No description provided for @archiveNoEpisode.
  ///
  /// In it, this message translates to:
  /// **'Senza episodio'**
  String get archiveNoEpisode;

  /// No description provided for @archiveOpenDocument.
  ///
  /// In it, this message translates to:
  /// **'Apri {title}'**
  String archiveOpenDocument(String title);

  /// No description provided for @archiveAddAction.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi documento'**
  String get archiveAddAction;

  /// No description provided for @archiveAddTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi documento'**
  String get archiveAddTitle;

  /// No description provided for @archiveEmptySuggestion.
  ///
  /// In it, this message translates to:
  /// **'Fotografa il tuo ultimo referto.'**
  String get archiveEmptySuggestion;

  /// No description provided for @archiveNoResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento corrisponde ai filtri.'**
  String get archiveNoResults;

  /// No description provided for @archiveSelectDocument.
  ///
  /// In it, this message translates to:
  /// **'Seleziona un documento per vedere i dettagli.'**
  String get archiveSelectDocument;

  /// No description provided for @archiveDocumentCount.
  ///
  /// In it, this message translates to:
  /// **'{count} documenti'**
  String archiveDocumentCount(String count);

  /// No description provided for @archiveDocumentDetail.
  ///
  /// In it, this message translates to:
  /// **'Documento'**
  String get archiveDocumentDetail;

  /// No description provided for @archiveDocumentMissing.
  ///
  /// In it, this message translates to:
  /// **'Il documento non è più disponibile.'**
  String get archiveDocumentMissing;

  /// No description provided for @archiveEditMetadata.
  ///
  /// In it, this message translates to:
  /// **'Modifica dati'**
  String get archiveEditMetadata;

  /// No description provided for @archiveShareDocument.
  ///
  /// In it, this message translates to:
  /// **'Condividi originale'**
  String get archiveShareDocument;

  /// No description provided for @archiveDownloadReady.
  ///
  /// In it, this message translates to:
  /// **'Originale salvato in modo sicuro.'**
  String get archiveDownloadReady;

  /// No description provided for @archiveDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare il documento?'**
  String get archiveDeleteTitle;

  /// No description provided for @archiveDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'Il documento verrà rimosso dall\'archivio.'**
  String get archiveDeleteBody;

  /// No description provided for @archiveDeleteAction.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get archiveDeleteAction;

  /// No description provided for @archiveDocumentDate.
  ///
  /// In it, this message translates to:
  /// **'Data del documento'**
  String get archiveDocumentDate;

  /// No description provided for @archiveDoctor.
  ///
  /// In it, this message translates to:
  /// **'Medico'**
  String get archiveDoctor;

  /// No description provided for @archiveFacility.
  ///
  /// In it, this message translates to:
  /// **'Struttura'**
  String get archiveFacility;

  /// No description provided for @archiveEpisode.
  ///
  /// In it, this message translates to:
  /// **'Episodio'**
  String get archiveEpisode;

  /// No description provided for @archiveTags.
  ///
  /// In it, this message translates to:
  /// **'Tag'**
  String get archiveTags;

  /// No description provided for @archiveTagsHint.
  ///
  /// In it, this message translates to:
  /// **'Tag, separati da virgole'**
  String get archiveTagsHint;

  /// No description provided for @archiveNotes.
  ///
  /// In it, this message translates to:
  /// **'Note'**
  String get archiveNotes;

  /// No description provided for @archiveTitleField.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get archiveTitleField;

  /// No description provided for @archiveCategoryField.
  ///
  /// In it, this message translates to:
  /// **'Categoria'**
  String get archiveCategoryField;

  /// No description provided for @archivePageLabel.
  ///
  /// In it, this message translates to:
  /// **'Pagina {current} di {total}'**
  String archivePageLabel(String current, String total);

  /// No description provided for @archiveSourceCamera.
  ///
  /// In it, this message translates to:
  /// **'Fotocamera'**
  String get archiveSourceCamera;

  /// No description provided for @archiveSourceGallery.
  ///
  /// In it, this message translates to:
  /// **'Galleria'**
  String get archiveSourceGallery;

  /// No description provided for @archiveSourceFile.
  ///
  /// In it, this message translates to:
  /// **'File o PDF'**
  String get archiveSourceFile;

  /// No description provided for @archiveSourceShare.
  ///
  /// In it, this message translates to:
  /// **'Condivisione'**
  String get archiveSourceShare;

  /// No description provided for @archiveChooseSource.
  ///
  /// In it, this message translates to:
  /// **'Scegli da dove aggiungere il documento.'**
  String get archiveChooseSource;

  /// No description provided for @archivePagesPreview.
  ///
  /// In it, this message translates to:
  /// **'Anteprima pagine'**
  String get archivePagesPreview;

  /// No description provided for @archiveRotatePage.
  ///
  /// In it, this message translates to:
  /// **'Ruota pagina'**
  String get archiveRotatePage;

  /// No description provided for @archiveDeletePage.
  ///
  /// In it, this message translates to:
  /// **'Elimina pagina'**
  String get archiveDeletePage;

  /// No description provided for @archiveUploadAction.
  ///
  /// In it, this message translates to:
  /// **'Carica'**
  String get archiveUploadAction;

  /// No description provided for @archiveUploadProgress.
  ///
  /// In it, this message translates to:
  /// **'{current} di {total} pagine completate'**
  String archiveUploadProgress(String current, String total);

  /// No description provided for @archiveDuplicateTitle.
  ///
  /// In it, this message translates to:
  /// **'Sembra già in archivio'**
  String get archiveDuplicateTitle;

  /// No description provided for @archiveDuplicateBody.
  ///
  /// In it, this message translates to:
  /// **'Puoi aprire l\'originale o conservare entrambi.'**
  String get archiveDuplicateBody;

  /// No description provided for @archiveOpenOriginal.
  ///
  /// In it, this message translates to:
  /// **'Apri l\'originale'**
  String get archiveOpenOriginal;

  /// No description provided for @archiveKeepBoth.
  ///
  /// In it, this message translates to:
  /// **'Conserva entrambi'**
  String get archiveKeepBoth;

  /// No description provided for @archiveDefaultFileName.
  ///
  /// In it, this message translates to:
  /// **'documento'**
  String get archiveDefaultFileName;

  /// No description provided for @archiveUsageCounter.
  ///
  /// In it, this message translates to:
  /// **'{used} di {max} documenti'**
  String archiveUsageCounter(String used, String max);

  /// No description provided for @archiveUsageLoading.
  ///
  /// In it, this message translates to:
  /// **'Conteggio documenti in corso…'**
  String get archiveUsageLoading;

  /// No description provided for @archiveLimitReachedTitle.
  ///
  /// In it, this message translates to:
  /// **'Hai raggiunto il limite del piano'**
  String get archiveLimitReachedTitle;

  /// No description provided for @archiveLimitReachedBody.
  ///
  /// In it, this message translates to:
  /// **'Il tuo piano include {max} documenti. Elimina un documento oppure cambia piano dalle Impostazioni.'**
  String archiveLimitReachedBody(String max);

  /// No description provided for @archiveOpenSettings.
  ///
  /// In it, this message translates to:
  /// **'Vai alle Impostazioni'**
  String get archiveOpenSettings;

  /// No description provided for @archiveDuplicateBadge.
  ///
  /// In it, this message translates to:
  /// **'Possibile duplicato'**
  String get archiveDuplicateBadge;

  /// No description provided for @archiveDuplicateDismiss.
  ///
  /// In it, this message translates to:
  /// **'Conserva entrambi'**
  String get archiveDuplicateDismiss;

  /// No description provided for @archiveCropPage.
  ///
  /// In it, this message translates to:
  /// **'Ritaglia pagina'**
  String get archiveCropPage;

  /// No description provided for @archiveCropConfirm.
  ///
  /// In it, this message translates to:
  /// **'Applica ritaglio'**
  String get archiveCropConfirm;

  /// No description provided for @archiveReorderHint.
  ///
  /// In it, this message translates to:
  /// **'Trascina le pagine per cambiarne l\'ordine.'**
  String get archiveReorderHint;

  /// No description provided for @archiveMultiPageTitle.
  ///
  /// In it, this message translates to:
  /// **'Pagine del documento'**
  String get archiveMultiPageTitle;

  /// No description provided for @archivePagesCount.
  ///
  /// In it, this message translates to:
  /// **'{count} pagine'**
  String archivePagesCount(String count);

  /// No description provided for @archiveDropHere.
  ///
  /// In it, this message translates to:
  /// **'Trascina qui PDF o immagini'**
  String get archiveDropHere;

  /// No description provided for @archiveDropActive.
  ///
  /// In it, this message translates to:
  /// **'Rilascia per aggiungere'**
  String get archiveDropActive;

  /// No description provided for @archiveShareReady.
  ///
  /// In it, this message translates to:
  /// **'Originale pronto per la condivisione.'**
  String get archiveShareReady;

  /// No description provided for @archiveSharePdfNote.
  ///
  /// In it, this message translates to:
  /// **'Le foto diventano un unico PDF.'**
  String get archiveSharePdfNote;

  /// No description provided for @analysisTitle.
  ///
  /// In it, this message translates to:
  /// **'Analisi del referto'**
  String get analysisTitle;

  /// No description provided for @analysisViewAction.
  ///
  /// In it, this message translates to:
  /// **'Visualizza analisi'**
  String get analysisViewAction;

  /// No description provided for @analysisStartAction.
  ///
  /// In it, this message translates to:
  /// **'Analizza il documento'**
  String get analysisStartAction;

  /// No description provided for @analysisUpdateAction.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get analysisUpdateAction;

  /// No description provided for @analysisRetryAction.
  ///
  /// In it, this message translates to:
  /// **'Riprova la lettura'**
  String get analysisRetryAction;

  /// No description provided for @analysisStatus_queued.
  ///
  /// In it, this message translates to:
  /// **'In coda'**
  String get analysisStatus_queued;

  /// No description provided for @analysisStatus_classifying.
  ///
  /// In it, this message translates to:
  /// **'Riconoscimento del documento'**
  String get analysisStatus_classifying;

  /// No description provided for @analysisStatus_extracting.
  ///
  /// In it, this message translates to:
  /// **'Lettura dei valori'**
  String get analysisStatus_extracting;

  /// No description provided for @analysisStatus_normalizing.
  ///
  /// In it, this message translates to:
  /// **'Conversione delle unità'**
  String get analysisStatus_normalizing;

  /// No description provided for @analysisStatus_done.
  ///
  /// In it, this message translates to:
  /// **'Lettura completata'**
  String get analysisStatus_done;

  /// No description provided for @analysisStatus_needs_review.
  ///
  /// In it, this message translates to:
  /// **'Valori da verificare'**
  String get analysisStatus_needs_review;

  /// No description provided for @analysisStatus_failed.
  ///
  /// In it, this message translates to:
  /// **'Lettura non riuscita'**
  String get analysisStatus_failed;

  /// No description provided for @analysisStatusSkipped.
  ///
  /// In it, this message translates to:
  /// **'Documento non elaborato'**
  String get analysisStatusSkipped;

  /// No description provided for @analysisStatusNoValues.
  ///
  /// In it, this message translates to:
  /// **'Nessun valore riconosciuto'**
  String get analysisStatusNoValues;

  /// No description provided for @analysisSkippedNotLabBody.
  ///
  /// In it, this message translates to:
  /// **'Non sembra un referto di laboratorio: nessun valore da estrarre'**
  String get analysisSkippedNotLabBody;

  /// No description provided for @analysisReadAnywayAction.
  ///
  /// In it, this message translates to:
  /// **'Leggi comunque'**
  String get analysisReadAnywayAction;

  /// No description provided for @analysisNoValuesBody.
  ///
  /// In it, this message translates to:
  /// **'Nessun valore riconosciuto in queste pagine'**
  String get analysisNoValuesBody;

  /// No description provided for @analysisNoValuesAdvice.
  ///
  /// In it, this message translates to:
  /// **'Riprova con foto nitide, dritte e con tutto il testo visibile.'**
  String get analysisNoValuesAdvice;

  /// No description provided for @analysisEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun valore letto'**
  String get analysisEmptyTitle;

  /// No description provided for @analysisEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Questo documento non contiene valori di laboratorio riconoscibili.'**
  String get analysisEmptyBody;

  /// No description provided for @analysisNotStartedTitle.
  ///
  /// In it, this message translates to:
  /// **'Documento non ancora analizzato'**
  String get analysisNotStartedTitle;

  /// No description provided for @analysisNotStartedBody.
  ///
  /// In it, this message translates to:
  /// **'Avvia la lettura per trasformare il referto in valori.'**
  String get analysisNotStartedBody;

  /// No description provided for @analysisValuesCount.
  ///
  /// In it, this message translates to:
  /// **'{count} valori'**
  String analysisValuesCount(String count);

  /// No description provided for @analysisValuesSaved.
  ///
  /// In it, this message translates to:
  /// **'{saved} valori salvati'**
  String analysisValuesSaved(String saved);

  /// No description provided for @analysisToReviewCount.
  ///
  /// In it, this message translates to:
  /// **'{count} da verificare'**
  String analysisToReviewCount(String count);

  /// No description provided for @analysisReviewTitle.
  ///
  /// In it, this message translates to:
  /// **'Valori da verificare'**
  String get analysisReviewTitle;

  /// No description provided for @analysisReviewBody.
  ///
  /// In it, this message translates to:
  /// **'Controlla questi valori: la lettura non era abbastanza sicura.'**
  String get analysisReviewBody;

  /// No description provided for @analysisConfirmAction.
  ///
  /// In it, this message translates to:
  /// **'Confermo il valore'**
  String get analysisConfirmAction;

  /// No description provided for @analysisCorrectAction.
  ///
  /// In it, this message translates to:
  /// **'Correggi'**
  String get analysisCorrectAction;

  /// No description provided for @analysisCorrectTitle.
  ///
  /// In it, this message translates to:
  /// **'Correggi il valore'**
  String get analysisCorrectTitle;

  /// No description provided for @analysisValueField.
  ///
  /// In it, this message translates to:
  /// **'Valore'**
  String get analysisValueField;

  /// No description provided for @analysisUnitField.
  ///
  /// In it, this message translates to:
  /// **'Unità'**
  String get analysisUnitField;

  /// No description provided for @analysisDateField.
  ///
  /// In it, this message translates to:
  /// **'Data del prelievo'**
  String get analysisDateField;

  /// No description provided for @analysisReadAs.
  ///
  /// In it, this message translates to:
  /// **'Letto come {value}'**
  String analysisReadAs(String value);

  /// No description provided for @analysisConfidence.
  ///
  /// In it, this message translates to:
  /// **'Sicurezza della lettura {percent}%'**
  String analysisConfidence(String percent);

  /// No description provided for @analysisLabRange.
  ///
  /// In it, this message translates to:
  /// **'Intervallo del laboratorio'**
  String get analysisLabRange;

  /// No description provided for @analysisBoardRange.
  ///
  /// In it, this message translates to:
  /// **'Riferimento istituzionale'**
  String get analysisBoardRange;

  /// No description provided for @analysisDoctorRange.
  ///
  /// In it, this message translates to:
  /// **'Soglia del medico'**
  String get analysisDoctorRange;

  /// No description provided for @analysisRangeMissing.
  ///
  /// In it, this message translates to:
  /// **'Non disponibile'**
  String get analysisRangeMissing;

  /// No description provided for @analysisFlag_below.
  ///
  /// In it, this message translates to:
  /// **'Sotto l\'intervallo'**
  String get analysisFlag_below;

  /// No description provided for @analysisFlag_within.
  ///
  /// In it, this message translates to:
  /// **'Nell\'intervallo'**
  String get analysisFlag_within;

  /// No description provided for @analysisFlag_above.
  ///
  /// In it, this message translates to:
  /// **'Sopra l\'intervallo'**
  String get analysisFlag_above;

  /// No description provided for @analysisFlag_critical_low.
  ///
  /// In it, this message translates to:
  /// **'Molto sotto l\'intervallo'**
  String get analysisFlag_critical_low;

  /// No description provided for @analysisFlag_critical_high.
  ///
  /// In it, this message translates to:
  /// **'Molto sopra l\'intervallo'**
  String get analysisFlag_critical_high;

  /// No description provided for @analysisFlag_unknown.
  ///
  /// In it, this message translates to:
  /// **'Da valutare'**
  String get analysisFlag_unknown;

  /// No description provided for @analysisCatalogDraftNotice.
  ///
  /// In it, this message translates to:
  /// **'Intervalli di uso comune, non ancora validati dal board scientifico.'**
  String get analysisCatalogDraftNotice;

  /// No description provided for @analysisLabName.
  ///
  /// In it, this message translates to:
  /// **'Laboratorio'**
  String get analysisLabName;

  /// No description provided for @analysisUsageCounter.
  ///
  /// In it, this message translates to:
  /// **'{used} di {max} letture questo mese'**
  String analysisUsageCounter(String used, String max);

  /// No description provided for @analysisLimitReachedTitle.
  ///
  /// In it, this message translates to:
  /// **'Hai raggiunto il limite di letture del mese'**
  String get analysisLimitReachedTitle;

  /// No description provided for @analysisLimitReachedBody.
  ///
  /// In it, this message translates to:
  /// **'Il tuo piano include {max} letture al mese. Riprova il mese prossimo oppure cambia piano dalle Impostazioni.'**
  String analysisLimitReachedBody(String max);

  /// No description provided for @analysisFailedTitle.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a leggere il documento'**
  String get analysisFailedTitle;

  /// No description provided for @analysisFailedBody.
  ///
  /// In it, this message translates to:
  /// **'Controlla che le pagine siano leggibili e riprova.'**
  String get analysisFailedBody;

  /// No description provided for @analysisFailureApi.
  ///
  /// In it, this message translates to:
  /// **'Il servizio di lettura non è temporaneamente disponibile. Riprova tra poco.'**
  String get analysisFailureApi;

  /// No description provided for @analysisFailureStorage.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti ad aprire il documento salvato. Controlla il file e riprova.'**
  String get analysisFailureStorage;

  /// No description provided for @analysisFailurePdfParse.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a leggere questo PDF. Prova a caricarlo di nuovo o usa foto nitide delle pagine.'**
  String get analysisFailurePdfParse;

  /// No description provided for @analysisFailureNetwork.
  ///
  /// In it, this message translates to:
  /// **'La connessione al servizio di lettura si è interrotta. Riprova tra poco.'**
  String get analysisFailureNetwork;

  /// No description provided for @analysisFailureInvalidOutput.
  ///
  /// In it, this message translates to:
  /// **'La lettura non ha prodotto valori utilizzabili. Riprova con pagine più nitide.'**
  String get analysisFailureInvalidOutput;

  /// No description provided for @analysisFailureMissingApiKey.
  ///
  /// In it, this message translates to:
  /// **'Il servizio di lettura non è configurato. Contatta l\'assistenza.'**
  String get analysisFailureMissingApiKey;

  /// No description provided for @analysisHistoryTitle.
  ///
  /// In it, this message translates to:
  /// **'Storico del valore'**
  String get analysisHistoryTitle;

  /// No description provided for @analysisHistoryEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non c\'è ancora uno storico per questo valore.'**
  String get analysisHistoryEmpty;

  /// No description provided for @analysisCatalogTitle.
  ///
  /// In it, this message translates to:
  /// **'Biomarcatori'**
  String get analysisCatalogTitle;

  /// No description provided for @analysisCatalogSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca un biomarcatore'**
  String get analysisCatalogSearch;

  /// No description provided for @analysisCatalogEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun biomarcatore corrisponde alla ricerca.'**
  String get analysisCatalogEmpty;

  /// No description provided for @archiveFilterNeedsReview.
  ///
  /// In it, this message translates to:
  /// **'Da verificare'**
  String get archiveFilterNeedsReview;

  /// No description provided for @analysisReviewBadge.
  ///
  /// In it, this message translates to:
  /// **'Da verificare: {count}'**
  String analysisReviewBadge(String count);

  /// No description provided for @analysisReadingProgress.
  ///
  /// In it, this message translates to:
  /// **'Avanzamento della lettura'**
  String get analysisReadingProgress;

  /// No description provided for @analysisUsuallyUnderMinute.
  ///
  /// In it, this message translates to:
  /// **'Di solito meno di un minuto.'**
  String get analysisUsuallyUnderMinute;

  /// No description provided for @analysisCompletedAt.
  ///
  /// In it, this message translates to:
  /// **'Analizzato il {date}'**
  String analysisCompletedAt(String date);

  /// No description provided for @analysisVerifyAction.
  ///
  /// In it, this message translates to:
  /// **'Verifica'**
  String get analysisVerifyAction;

  /// No description provided for @analysisUnknownTitle.
  ///
  /// In it, this message translates to:
  /// **'Non ancora nel catalogo'**
  String get analysisUnknownTitle;

  /// No description provided for @analysisValueColumn.
  ///
  /// In it, this message translates to:
  /// **'Valore'**
  String get analysisValueColumn;

  /// No description provided for @analysisOriginalUnit.
  ///
  /// In it, this message translates to:
  /// **'Nel referto: {unit}'**
  String analysisOriginalUnit(String unit);

  /// No description provided for @analysisReviewComplete.
  ///
  /// In it, this message translates to:
  /// **'Tutti i valori sono stati verificati.'**
  String get analysisReviewComplete;

  /// No description provided for @analysisOutcomeColumn.
  ///
  /// In it, this message translates to:
  /// **'Esito'**
  String get analysisOutcomeColumn;

  /// No description provided for @analysisActionsColumn.
  ///
  /// In it, this message translates to:
  /// **'Azioni'**
  String get analysisActionsColumn;

  /// No description provided for @analysisApproveAction.
  ///
  /// In it, this message translates to:
  /// **'Approva'**
  String get analysisApproveAction;

  /// No description provided for @analysisReviewConfirmed.
  ///
  /// In it, this message translates to:
  /// **'Confermato'**
  String get analysisReviewConfirmed;

  /// No description provided for @analysisReviewNeeded.
  ///
  /// In it, this message translates to:
  /// **'Da verificare'**
  String get analysisReviewNeeded;

  /// No description provided for @analysisReviewPending.
  ///
  /// In it, this message translates to:
  /// **'In attesa'**
  String get analysisReviewPending;

  /// No description provided for @analysisReviewDiscarded.
  ///
  /// In it, this message translates to:
  /// **'Scartato'**
  String get analysisReviewDiscarded;

  /// No description provided for @analysisConfirmedByEngine.
  ///
  /// In it, this message translates to:
  /// **'dal motore'**
  String get analysisConfirmedByEngine;

  /// No description provided for @analysisConfirmedByYou.
  ///
  /// In it, this message translates to:
  /// **'da te'**
  String get analysisConfirmedByYou;

  /// No description provided for @analysisShowDiscarded.
  ///
  /// In it, this message translates to:
  /// **'Mostra scartati'**
  String get analysisShowDiscarded;

  /// No description provided for @analysisDiscardConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Scartare questo valore?'**
  String get analysisDiscardConfirmTitle;

  /// No description provided for @analysisDiscardConfirmBody.
  ///
  /// In it, this message translates to:
  /// **'Non verrà usato per organi, rischi e spiegazioni.'**
  String get analysisDiscardConfirmBody;

  /// No description provided for @analysisConfirmAll.
  ///
  /// In it, this message translates to:
  /// **'Conferma tutti i valori in attesa ({count})'**
  String analysisConfirmAll(String count);

  /// No description provided for @analysisConfirmAllProgress.
  ///
  /// In it, this message translates to:
  /// **'{current} di {total} valori elaborati'**
  String analysisConfirmAllProgress(String current, String total);

  /// No description provided for @analysisConfirmAllResult.
  ///
  /// In it, this message translates to:
  /// **'{confirmed} confermati, {errors} errori'**
  String analysisConfirmAllResult(String confirmed, String errors);

  /// No description provided for @analysisReviewSummary.
  ///
  /// In it, this message translates to:
  /// **'{confirmed} valori confermati · {pending} da verificare'**
  String analysisReviewSummary(String confirmed, String pending);

  /// No description provided for @analysisVerifyValuesAction.
  ///
  /// In it, this message translates to:
  /// **'Verifica i valori ({count})'**
  String analysisVerifyValuesAction(String count);

  /// No description provided for @analysisFlagShort_below.
  ///
  /// In it, this message translates to:
  /// **'Sotto'**
  String get analysisFlagShort_below;

  /// No description provided for @analysisFlagShort_within.
  ///
  /// In it, this message translates to:
  /// **'Nell\'intervallo'**
  String get analysisFlagShort_within;

  /// No description provided for @analysisFlagShort_above.
  ///
  /// In it, this message translates to:
  /// **'Sopra'**
  String get analysisFlagShort_above;

  /// No description provided for @analysisFlagShort_critical_low.
  ///
  /// In it, this message translates to:
  /// **'Molto sotto'**
  String get analysisFlagShort_critical_low;

  /// No description provided for @analysisFlagShort_critical_high.
  ///
  /// In it, this message translates to:
  /// **'Molto sopra'**
  String get analysisFlagShort_critical_high;

  /// No description provided for @analysisFlagShort_unknown.
  ///
  /// In it, this message translates to:
  /// **'Da valutare'**
  String get analysisFlagShort_unknown;

  /// No description provided for @analysisDiscardAction.
  ///
  /// In it, this message translates to:
  /// **'Scarta'**
  String get analysisDiscardAction;

  /// No description provided for @analysisDiscardUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Lo scarto non è ancora supportato dal repository.'**
  String get analysisDiscardUnavailable;

  /// No description provided for @analysisSourceUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Pagina e ritaglio non disponibili per questo valore.'**
  String get analysisSourceUnavailable;

  /// No description provided for @analysisKeyboardHelp.
  ///
  /// In it, this message translates to:
  /// **'Tastiera: Invio conferma, C corregge.'**
  String get analysisKeyboardHelp;

  /// No description provided for @addSymptom.
  ///
  /// In it, this message translates to:
  /// **'Registra un sintomo'**
  String get addSymptom;

  /// No description provided for @symptomsTitle.
  ///
  /// In it, this message translates to:
  /// **'Diario dei sintomi'**
  String get symptomsTitle;

  /// No description provided for @symptomsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Annota come ti senti nel tempo.'**
  String get symptomsSubtitle;

  /// No description provided for @symptomsNew.
  ///
  /// In it, this message translates to:
  /// **'Registra un sintomo'**
  String get symptomsNew;

  /// No description provided for @symptomsEdit.
  ///
  /// In it, this message translates to:
  /// **'Dettaglio sintomo'**
  String get symptomsEdit;

  /// No description provided for @symptomsEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun sintomo registrato'**
  String get symptomsEmptyTitle;

  /// No description provided for @symptomsEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Puoi annotare un sintomo, la sua intensità e quando è comparso.'**
  String get symptomsEmptyBody;

  /// No description provided for @symptomsType.
  ///
  /// In it, this message translates to:
  /// **'Sintomo'**
  String get symptomsType;

  /// No description provided for @symptomsFreeText.
  ///
  /// In it, this message translates to:
  /// **'Descrivi il sintomo'**
  String get symptomsFreeText;

  /// No description provided for @symptomsSeverity.
  ///
  /// In it, this message translates to:
  /// **'Severità'**
  String get symptomsSeverity;

  /// No description provided for @symptomsNotes.
  ///
  /// In it, this message translates to:
  /// **'Note'**
  String get symptomsNotes;

  /// No description provided for @symptomsReadOnly.
  ///
  /// In it, this message translates to:
  /// **'Dopo 24 ore la registrazione non può più essere modificata o eliminata.'**
  String get symptomsReadOnly;

  /// No description provided for @symptomsDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get symptomsDelete;

  /// No description provided for @symptomsDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questo sintomo?'**
  String get symptomsDeleteTitle;

  /// No description provided for @symptomsDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'La registrazione verrà rimossa dal diario.'**
  String get symptomsDeleteBody;

  /// No description provided for @symptomsLoadError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a caricare il sintomo.'**
  String get symptomsLoadError;

  /// No description provided for @symptomsSaveError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a salvare il sintomo.'**
  String get symptomsSaveError;

  /// No description provided for @symptomsMissing.
  ///
  /// In it, this message translates to:
  /// **'Questa registrazione non è più disponibile.'**
  String get symptomsMissing;

  /// No description provided for @symptom_headache.
  ///
  /// In it, this message translates to:
  /// **'Mal di testa'**
  String get symptom_headache;

  /// No description provided for @symptom_nausea.
  ///
  /// In it, this message translates to:
  /// **'Nausea'**
  String get symptom_nausea;

  /// No description provided for @symptom_fatigue.
  ///
  /// In it, this message translates to:
  /// **'Stanchezza'**
  String get symptom_fatigue;

  /// No description provided for @symptom_dizziness.
  ///
  /// In it, this message translates to:
  /// **'Capogiri'**
  String get symptom_dizziness;

  /// No description provided for @symptom_chest_pain.
  ///
  /// In it, this message translates to:
  /// **'Dolore al petto'**
  String get symptom_chest_pain;

  /// No description provided for @symptom_shortness_of_breath.
  ///
  /// In it, this message translates to:
  /// **'Fiato corto'**
  String get symptom_shortness_of_breath;

  /// No description provided for @symptom_fever.
  ///
  /// In it, this message translates to:
  /// **'Febbre'**
  String get symptom_fever;

  /// No description provided for @symptom_cough.
  ///
  /// In it, this message translates to:
  /// **'Tosse'**
  String get symptom_cough;

  /// No description provided for @symptom_abdominal_pain.
  ///
  /// In it, this message translates to:
  /// **'Dolore addominale'**
  String get symptom_abdominal_pain;

  /// No description provided for @symptom_joint_pain.
  ///
  /// In it, this message translates to:
  /// **'Dolore articolare'**
  String get symptom_joint_pain;

  /// No description provided for @symptom_back_pain.
  ///
  /// In it, this message translates to:
  /// **'Mal di schiena'**
  String get symptom_back_pain;

  /// No description provided for @symptom_insomnia.
  ///
  /// In it, this message translates to:
  /// **'Insonnia'**
  String get symptom_insomnia;

  /// No description provided for @symptom_anxiety.
  ///
  /// In it, this message translates to:
  /// **'Ansia'**
  String get symptom_anxiety;

  /// No description provided for @symptom_palpitations.
  ///
  /// In it, this message translates to:
  /// **'Palpitazioni'**
  String get symptom_palpitations;

  /// No description provided for @symptom_rash.
  ///
  /// In it, this message translates to:
  /// **'Eruzione cutanea'**
  String get symptom_rash;

  /// No description provided for @symptom_swelling.
  ///
  /// In it, this message translates to:
  /// **'Gonfiore'**
  String get symptom_swelling;

  /// No description provided for @symptom_diarrhea.
  ///
  /// In it, this message translates to:
  /// **'Diarrea'**
  String get symptom_diarrhea;

  /// No description provided for @symptom_constipation.
  ///
  /// In it, this message translates to:
  /// **'Stitichezza'**
  String get symptom_constipation;

  /// No description provided for @symptom_loss_of_appetite.
  ///
  /// In it, this message translates to:
  /// **'Perdita di appetito'**
  String get symptom_loss_of_appetite;

  /// No description provided for @symptom_other.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get symptom_other;

  /// No description provided for @alertsTitle.
  ///
  /// In it, this message translates to:
  /// **'Centro avvisi'**
  String get alertsTitle;

  /// No description provided for @alertsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Avvisi generati dalle regole cliniche versionate.'**
  String get alertsSubtitle;

  /// No description provided for @alertsMarkAllRead.
  ///
  /// In it, this message translates to:
  /// **'Segna tutti come letti'**
  String get alertsMarkAllRead;

  /// No description provided for @alertsEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun avviso'**
  String get alertsEmptyTitle;

  /// No description provided for @alertsEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Non ci sono avvisi da leggere.'**
  String get alertsEmptyBody;

  /// No description provided for @alertsContactDoctor.
  ///
  /// In it, this message translates to:
  /// **'Contatta il medico'**
  String get alertsContactDoctor;

  /// No description provided for @alertsLevel_lab.
  ///
  /// In it, this message translates to:
  /// **'Laboratorio'**
  String get alertsLevel_lab;

  /// No description provided for @alertsLevel_institutional.
  ///
  /// In it, this message translates to:
  /// **'Istituzionale'**
  String get alertsLevel_institutional;

  /// No description provided for @alertsLevel_doctor.
  ///
  /// In it, this message translates to:
  /// **'Medico'**
  String get alertsLevel_doctor;

  /// No description provided for @alertBiomarkerCriticalLow.
  ///
  /// In it, this message translates to:
  /// **'Il biomarcatore è molto sotto l\'intervallo di riferimento.'**
  String get alertBiomarkerCriticalLow;

  /// No description provided for @alertBiomarkerCriticalHigh.
  ///
  /// In it, this message translates to:
  /// **'Il biomarcatore è molto sopra l\'intervallo di riferimento.'**
  String get alertBiomarkerCriticalHigh;

  /// No description provided for @alertBiomarkerBelowInstitutional.
  ///
  /// In it, this message translates to:
  /// **'Il biomarcatore è sotto il riferimento istituzionale.'**
  String get alertBiomarkerBelowInstitutional;

  /// No description provided for @alertBiomarkerAboveInstitutional.
  ///
  /// In it, this message translates to:
  /// **'Il biomarcatore è sopra il riferimento istituzionale.'**
  String get alertBiomarkerAboveInstitutional;

  /// No description provided for @homeHealthStatusTitle.
  ///
  /// In it, this message translates to:
  /// **'Stato di salute'**
  String get homeHealthStatusTitle;

  /// No description provided for @homeHealthStatusPreparing.
  ///
  /// In it, this message translates to:
  /// **'In preparazione: il punteggio arriva con le regole del board'**
  String get homeHealthStatusPreparing;

  /// No description provided for @homeLatestValues.
  ///
  /// In it, this message translates to:
  /// **'Ultimi valori'**
  String get homeLatestValues;

  /// No description provided for @homeNoValues.
  ///
  /// In it, this message translates to:
  /// **'Nessun valore disponibile.'**
  String get homeNoValues;

  /// No description provided for @homeAlerts.
  ///
  /// In it, this message translates to:
  /// **'Avvisi'**
  String get homeAlerts;

  /// No description provided for @homeToReview.
  ///
  /// In it, this message translates to:
  /// **'Da verificare'**
  String get homeToReview;

  /// No description provided for @homeNothingToReview.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento da verificare.'**
  String get homeNothingToReview;

  /// No description provided for @homeLatestDocument.
  ///
  /// In it, this message translates to:
  /// **'Ultimo documento'**
  String get homeLatestDocument;

  /// No description provided for @homeNoDocuments.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento disponibile.'**
  String get homeNoDocuments;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Inizia dal tuo primo referto'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Carica un referto per raccogliere i valori e costruire il tuo storico.'**
  String get homeEmptyBody;

  /// No description provided for @homeUploadFirstReport.
  ///
  /// In it, this message translates to:
  /// **'Carica il primo referto'**
  String get homeUploadFirstReport;

  /// No description provided for @homeHealthSpace.
  ///
  /// In it, this message translates to:
  /// **'Il tuo spazio salute'**
  String get homeHealthSpace;

  /// No description provided for @homeUpload.
  ///
  /// In it, this message translates to:
  /// **'Carica'**
  String get homeUpload;

  /// No description provided for @homeUploadReport.
  ///
  /// In it, this message translates to:
  /// **'Carica referto'**
  String get homeUploadReport;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In it, this message translates to:
  /// **'Buongiorno, {name}.'**
  String homeGreetingMorning(String name);

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In it, this message translates to:
  /// **'Buon pomeriggio, {name}.'**
  String homeGreetingAfternoon(String name);

  /// No description provided for @homeGreetingEvening.
  ///
  /// In it, this message translates to:
  /// **'Buonasera, {name}.'**
  String homeGreetingEvening(String name);

  /// No description provided for @homeGreetingDesktopNoName.
  ///
  /// In it, this message translates to:
  /// **'Buongiorno.'**
  String get homeGreetingDesktopNoName;

  /// No description provided for @homeUpdatedAt.
  ///
  /// In it, this message translates to:
  /// **'Aggiornato al {date}'**
  String homeUpdatedAt(String date);

  /// No description provided for @homeYourHealth.
  ///
  /// In it, this message translates to:
  /// **'La tua salute'**
  String get homeYourHealth;

  /// No description provided for @homeYourDoctor.
  ///
  /// In it, this message translates to:
  /// **'Il tuo medico'**
  String get homeYourDoctor;

  /// No description provided for @homeOpenOverview.
  ///
  /// In it, this message translates to:
  /// **'Apri il quadro'**
  String get homeOpenOverview;

  /// No description provided for @homeLatestReportDate.
  ///
  /// In it, this message translates to:
  /// **'Ultimo referto: {date}'**
  String homeLatestReportDate(String date);

  /// No description provided for @homeReviewValues.
  ///
  /// In it, this message translates to:
  /// **'{count} valori da verificare'**
  String homeReviewValues(String count);

  /// No description provided for @homeFromReport.
  ///
  /// In it, this message translates to:
  /// **'Dal referto del {date}'**
  String homeFromReport(String date);

  /// No description provided for @homeHealthStatusPreparingShort.
  ///
  /// In it, this message translates to:
  /// **'In preparazione'**
  String get homeHealthStatusPreparingShort;

  /// No description provided for @homeRecentDocuments.
  ///
  /// In it, this message translates to:
  /// **'Documenti recenti'**
  String get homeRecentDocuments;

  /// No description provided for @homeAllDocuments.
  ///
  /// In it, this message translates to:
  /// **'Tutti i documenti'**
  String get homeAllDocuments;

  /// No description provided for @homeAllDocumentsCount.
  ///
  /// In it, this message translates to:
  /// **'Tutti i {count} documenti'**
  String homeAllDocumentsCount(String count);

  /// No description provided for @homeStatDocuments.
  ///
  /// In it, this message translates to:
  /// **'Documenti'**
  String get homeStatDocuments;

  /// No description provided for @homeStatTracked.
  ///
  /// In it, this message translates to:
  /// **'Valori seguiti'**
  String get homeStatTracked;

  /// No description provided for @homeStatReview.
  ///
  /// In it, this message translates to:
  /// **'Valori da verificare'**
  String get homeStatReview;

  /// No description provided for @homeStatAlerts.
  ///
  /// In it, this message translates to:
  /// **'Avvisi non letti'**
  String get homeStatAlerts;

  /// No description provided for @homeValuesOverTime.
  ///
  /// In it, this message translates to:
  /// **'Valori nel tempo'**
  String get homeValuesOverTime;

  /// No description provided for @homeOpenHistory.
  ///
  /// In it, this message translates to:
  /// **'Apri storico'**
  String get homeOpenHistory;

  /// No description provided for @homePrevious.
  ///
  /// In it, this message translates to:
  /// **'Precedente'**
  String get homePrevious;

  /// No description provided for @homeConfirmedValues.
  ///
  /// In it, this message translates to:
  /// **'Ultimi valori confermati'**
  String get homeConfirmedValues;

  /// No description provided for @homeConfirmed.
  ///
  /// In it, this message translates to:
  /// **'Confermato'**
  String get homeConfirmed;

  /// No description provided for @homeTasks.
  ///
  /// In it, this message translates to:
  /// **'Da fare'**
  String get homeTasks;

  /// No description provided for @homeUnreadAlerts.
  ///
  /// In it, this message translates to:
  /// **'{count} avvisi non letti'**
  String homeUnreadAlerts(String count);

  /// No description provided for @homeOpenAlertCenter.
  ///
  /// In it, this message translates to:
  /// **'Apri il centro avvisi'**
  String get homeOpenAlertCenter;

  /// No description provided for @homeTableDocument.
  ///
  /// In it, this message translates to:
  /// **'Documento'**
  String get homeTableDocument;

  /// No description provided for @homeTableDate.
  ///
  /// In it, this message translates to:
  /// **'Data'**
  String get homeTableDate;

  /// No description provided for @homeTableStatus.
  ///
  /// In it, this message translates to:
  /// **'Stato'**
  String get homeTableStatus;

  /// No description provided for @homeTableParameter.
  ///
  /// In it, this message translates to:
  /// **'Parametro'**
  String get homeTableParameter;

  /// No description provided for @homeTableVerification.
  ///
  /// In it, this message translates to:
  /// **'Verifica'**
  String get homeTableVerification;

  /// No description provided for @healthPeriod6Months.
  ///
  /// In it, this message translates to:
  /// **'6 mesi'**
  String get healthPeriod6Months;

  /// No description provided for @archiveDesktopSubtitle.
  ///
  /// In it, this message translates to:
  /// **'{count} documenti · Elenco, originale e analisi'**
  String archiveDesktopSubtitle(String count);

  /// No description provided for @archiveUploadDocument.
  ///
  /// In it, this message translates to:
  /// **'Carica documento'**
  String get archiveUploadDocument;

  /// No description provided for @archiveUploadShort.
  ///
  /// In it, this message translates to:
  /// **'Carica'**
  String get archiveUploadShort;

  /// No description provided for @archiveAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get archiveAll;

  /// No description provided for @archiveYear.
  ///
  /// In it, this message translates to:
  /// **'Anno'**
  String get archiveYear;

  /// No description provided for @archiveAllYears.
  ///
  /// In it, this message translates to:
  /// **'Tutti gli anni'**
  String get archiveAllYears;

  /// No description provided for @archiveFilters.
  ///
  /// In it, this message translates to:
  /// **'Filtri'**
  String get archiveFilters;

  /// No description provided for @archiveAllCategories.
  ///
  /// In it, this message translates to:
  /// **'Tutte le categorie'**
  String get archiveAllCategories;

  /// No description provided for @archiveExtractedData.
  ///
  /// In it, this message translates to:
  /// **'Dati estratti'**
  String get archiveExtractedData;

  /// No description provided for @archiveOriginal.
  ///
  /// In it, this message translates to:
  /// **'Originale'**
  String get archiveOriginal;

  /// No description provided for @archivePreviousPage.
  ///
  /// In it, this message translates to:
  /// **'Pagina precedente'**
  String get archivePreviousPage;

  /// No description provided for @archiveNextPage.
  ///
  /// In it, this message translates to:
  /// **'Pagina successiva'**
  String get archiveNextPage;

  /// No description provided for @archiveOpenFullscreen.
  ///
  /// In it, this message translates to:
  /// **'Apri a tutto schermo'**
  String get archiveOpenFullscreen;

  /// No description provided for @healthConfirmed.
  ///
  /// In it, this message translates to:
  /// **'Confermato'**
  String get healthConfirmed;

  /// No description provided for @healthSourceReferences.
  ///
  /// In it, this message translates to:
  /// **'Fonte e riferimenti'**
  String get healthSourceReferences;

  /// No description provided for @healthUpdatedUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Nessun aggiornamento disponibile'**
  String get healthUpdatedUnavailable;

  /// No description provided for @healthUpdatedAt.
  ///
  /// In it, this message translates to:
  /// **'Quadro aggiornato al {date}'**
  String healthUpdatedAt(String date);

  /// No description provided for @healthTabAllValues.
  ///
  /// In it, this message translates to:
  /// **'Tutti i valori'**
  String get healthTabAllValues;

  /// No description provided for @healthTabHistory.
  ///
  /// In it, this message translates to:
  /// **'Storico'**
  String get healthTabHistory;

  /// No description provided for @healthSegmentValues.
  ///
  /// In it, this message translates to:
  /// **'Valori'**
  String get healthSegmentValues;

  /// No description provided for @healthSegmentSymptoms.
  ///
  /// In it, this message translates to:
  /// **'Sintomi'**
  String get healthSegmentSymptoms;

  /// No description provided for @healthSegmentAlerts.
  ///
  /// In it, this message translates to:
  /// **'Avvisi'**
  String get healthSegmentAlerts;

  /// No description provided for @healthMeasurementHistory.
  ///
  /// In it, this message translates to:
  /// **'Storico delle rilevazioni'**
  String get healthMeasurementHistory;

  /// No description provided for @healthTableDocument.
  ///
  /// In it, this message translates to:
  /// **'Documento'**
  String get healthTableDocument;

  /// No description provided for @healthOpenReport.
  ///
  /// In it, this message translates to:
  /// **'Apri il referto'**
  String get healthOpenReport;

  /// No description provided for @healthSelectedValue.
  ///
  /// In it, this message translates to:
  /// **'Il valore selezionato'**
  String get healthSelectedValue;

  /// No description provided for @healthExtractionConfirmed.
  ///
  /// In it, this message translates to:
  /// **'Estrazione confermata'**
  String get healthExtractionConfirmed;

  /// No description provided for @healthSource.
  ///
  /// In it, this message translates to:
  /// **'Fonte'**
  String get healthSource;

  /// No description provided for @healthNotSet.
  ///
  /// In it, this message translates to:
  /// **'Non impostata'**
  String get healthNotSet;

  /// No description provided for @healthOtherConfirmed.
  ///
  /// In it, this message translates to:
  /// **'Altri valori confermati'**
  String get healthOtherConfirmed;

  /// No description provided for @healthValuesTrackTooltip.
  ///
  /// In it, this message translates to:
  /// **'Traccia questo valore'**
  String get healthValuesTrackTooltip;

  /// No description provided for @healthManualSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una rilevazione effettuata da te.'**
  String get healthManualSubtitle;

  /// No description provided for @healthManualFormTitle.
  ///
  /// In it, this message translates to:
  /// **'Dati della rilevazione'**
  String get healthManualFormTitle;

  /// No description provided for @symptomsEditable.
  ///
  /// In it, this message translates to:
  /// **'Modificabile'**
  String get symptomsEditable;

  /// No description provided for @symptomsRecorded.
  ///
  /// In it, this message translates to:
  /// **'Registrato'**
  String get symptomsRecorded;

  /// No description provided for @alertsUnread.
  ///
  /// In it, this message translates to:
  /// **'Da leggere'**
  String get alertsUnread;

  /// No description provided for @alertsRead.
  ///
  /// In it, this message translates to:
  /// **'Letto'**
  String get alertsRead;

  /// No description provided for @bodyTitle.
  ///
  /// In it, this message translates to:
  /// **'Corpo e organi'**
  String get bodyTitle;

  /// No description provided for @bodySegment.
  ///
  /// In it, this message translates to:
  /// **'Corpo'**
  String get bodySegment;

  /// No description provided for @bodyDesktopSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Quadro delle aree del corpo'**
  String get bodyDesktopSubtitle;

  /// No description provided for @bodySilhouetteSemantics.
  ///
  /// In it, this message translates to:
  /// **'Mappa delle aree del corpo'**
  String get bodySilhouetteSemantics;

  /// No description provided for @bodyState_ok.
  ///
  /// In it, this message translates to:
  /// **'Nella norma'**
  String get bodyState_ok;

  /// No description provided for @bodyState_monitor.
  ///
  /// In it, this message translates to:
  /// **'Da monitorare'**
  String get bodyState_monitor;

  /// No description provided for @bodyState_attention.
  ///
  /// In it, this message translates to:
  /// **'Attenzione'**
  String get bodyState_attention;

  /// No description provided for @bodyState_missing.
  ///
  /// In it, this message translates to:
  /// **'Dato mancante'**
  String get bodyState_missing;

  /// No description provided for @bodyConfidenceComplete.
  ///
  /// In it, this message translates to:
  /// **'Quadro completo'**
  String get bodyConfidenceComplete;

  /// No description provided for @bodyConfidencePartial.
  ///
  /// In it, this message translates to:
  /// **'Quadro parziale'**
  String get bodyConfidencePartial;

  /// No description provided for @bodyConfidenceIncomplete.
  ///
  /// In it, this message translates to:
  /// **'Dati da completare'**
  String get bodyConfidenceIncomplete;

  /// No description provided for @bodyConfidenceMissing.
  ///
  /// In it, this message translates to:
  /// **'Dati mancanti'**
  String get bodyConfidenceMissing;

  /// No description provided for @bodyAllAreas.
  ///
  /// In it, this message translates to:
  /// **'Tutte le aree'**
  String get bodyAllAreas;

  /// No description provided for @bodyEmptyMessage.
  ///
  /// In it, this message translates to:
  /// **'Carica un referto o inserisci un valore per vedere il quadro.'**
  String get bodyEmptyMessage;

  /// No description provided for @bodyUpdatedOn.
  ///
  /// In it, this message translates to:
  /// **'Aggiornato il {date}'**
  String bodyUpdatedOn(Object date);

  /// No description provided for @bodyRefresh.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get bodyRefresh;

  /// No description provided for @bodyRuleNote.
  ///
  /// In it, this message translates to:
  /// **'Il colore indica quanto i valori dell\'area si discostano dai riferimenti; non è una diagnosi. Regola v{version}.'**
  String bodyRuleNote(Object version);

  /// No description provided for @bodyNotAvailable.
  ///
  /// In it, this message translates to:
  /// **'n.d.'**
  String get bodyNotAvailable;

  /// No description provided for @bodyLoadError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a caricare il quadro delle aree.'**
  String get bodyLoadError;

  /// No description provided for @bodyValuesError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a caricare i valori di quest\'area.'**
  String get bodyValuesError;

  /// No description provided for @bodyAreaMissing.
  ///
  /// In it, this message translates to:
  /// **'Quest\'area non è disponibile.'**
  String get bodyAreaMissing;

  /// No description provided for @bodyCalculatedOn.
  ///
  /// In it, this message translates to:
  /// **'Calcolato il {date}'**
  String bodyCalculatedOn(Object date);

  /// No description provided for @bodyHistory.
  ///
  /// In it, this message translates to:
  /// **'Storico'**
  String get bodyHistory;

  /// No description provided for @bodyAreaValues.
  ///
  /// In it, this message translates to:
  /// **'Valori di quest\'area'**
  String get bodyAreaValues;

  /// No description provided for @bodyEssential.
  ///
  /// In it, this message translates to:
  /// **'Essenziale'**
  String get bodyEssential;

  /// No description provided for @bodyNoMappedValues.
  ///
  /// In it, this message translates to:
  /// **'Nessun valore associato'**
  String get bodyNoMappedValues;

  /// No description provided for @bodyNoPresentValues.
  ///
  /// In it, this message translates to:
  /// **'Nessun valore disponibile per quest\'area.'**
  String get bodyNoPresentValues;

  /// No description provided for @bodyFullHistory.
  ///
  /// In it, this message translates to:
  /// **'Storico completo'**
  String get bodyFullHistory;

  /// No description provided for @bodyHowToRead.
  ///
  /// In it, this message translates to:
  /// **'Come leggere il quadro'**
  String get bodyHowToRead;

  /// No description provided for @bodyToday.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get bodyToday;

  /// No description provided for @bodySixMonthsAgo.
  ///
  /// In it, this message translates to:
  /// **'6 mesi fa'**
  String get bodySixMonthsAgo;

  /// No description provided for @bodyTwelveMonthsAgo.
  ///
  /// In it, this message translates to:
  /// **'12 mesi fa'**
  String get bodyTwelveMonthsAgo;

  /// No description provided for @bodyTrendImproved.
  ///
  /// In it, this message translates to:
  /// **'Miglioramento'**
  String get bodyTrendImproved;

  /// No description provided for @bodyTrendWorsened.
  ///
  /// In it, this message translates to:
  /// **'Peggioramento'**
  String get bodyTrendWorsened;

  /// No description provided for @bodyTrendStable.
  ///
  /// In it, this message translates to:
  /// **'Stabile'**
  String get bodyTrendStable;

  /// No description provided for @bodyComparison.
  ///
  /// In it, this message translates to:
  /// **'Confronto nel tempo'**
  String get bodyComparison;

  /// No description provided for @bodyAttentionEpisodes.
  ///
  /// In it, this message translates to:
  /// **'Episodi di attenzione'**
  String get bodyAttentionEpisodes;

  /// No description provided for @bodyNoEpisodes.
  ///
  /// In it, this message translates to:
  /// **'Nessun episodio di attenzione.'**
  String get bodyNoEpisodes;

  /// No description provided for @bodyDurationDays.
  ///
  /// In it, this message translates to:
  /// **'{count} giorni'**
  String bodyDurationDays(Object count);

  /// No description provided for @bodyStateTimeline.
  ///
  /// In it, this message translates to:
  /// **'Linea del tempo degli stati'**
  String get bodyStateTimeline;

  /// No description provided for @bodyValuesCount.
  ///
  /// In it, this message translates to:
  /// **'{count} valori'**
  String bodyValuesCount(Object count);

  /// No description provided for @bodyBiomarkerCharts.
  ///
  /// In it, this message translates to:
  /// **'Grafico dei biomarcatori'**
  String get bodyBiomarkerCharts;

  /// No description provided for @bodyHistoryEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non ci sono ancora calcoli nello storico.'**
  String get bodyHistoryEmpty;

  /// No description provided for @bodyHistoryError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a caricare lo storico dell\'area.'**
  String get bodyHistoryError;

  /// No description provided for @bodyDeviationLabel.
  ///
  /// In it, this message translates to:
  /// **'Scostamento dai riferimenti'**
  String get bodyDeviationLabel;

  /// No description provided for @bodyLegendNormal.
  ///
  /// In it, this message translates to:
  /// **'Nella norma'**
  String get bodyLegendNormal;

  /// No description provided for @bodyLegendAttention.
  ///
  /// In it, this message translates to:
  /// **'Attenzione'**
  String get bodyLegendAttention;

  /// No description provided for @bodyExplodedView.
  ///
  /// In it, this message translates to:
  /// **'Vista esplosa'**
  String get bodyExplodedView;

  /// No description provided for @bodyGenderNotice.
  ///
  /// In it, this message translates to:
  /// **'Indica il genere nel profilo per un quadro completo'**
  String get bodyGenderNotice;

  /// No description provided for @bodyOpenProfile.
  ///
  /// In it, this message translates to:
  /// **'Apri profilo'**
  String get bodyOpenProfile;

  /// No description provided for @homeBodySummary.
  ///
  /// In it, this message translates to:
  /// **'{ok} aree nella norma · {monitor} da monitorare · {attention} in attenzione · {missing} senza dati'**
  String homeBodySummary(
      Object attention, Object missing, Object monitor, Object ok);

  /// No description provided for @commonYes.
  ///
  /// In it, this message translates to:
  /// **'Sì'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In it, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @preventionNav.
  ///
  /// In it, this message translates to:
  /// **'Prevenzione'**
  String get preventionNav;

  /// No description provided for @preventionTitle.
  ///
  /// In it, this message translates to:
  /// **'Prevenzione'**
  String get preventionTitle;

  /// No description provided for @preventionSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Controlli, scadenze e storico'**
  String get preventionSubtitle;

  /// No description provided for @preventionAddReminder.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi promemoria'**
  String get preventionAddReminder;

  /// No description provided for @preventionComingSoon.
  ///
  /// In it, this message translates to:
  /// **'In arrivo'**
  String get preventionComingSoon;

  /// No description provided for @preventionTabControls.
  ///
  /// In it, this message translates to:
  /// **'I miei controlli'**
  String get preventionTabControls;

  /// No description provided for @preventionTabRisks.
  ///
  /// In it, this message translates to:
  /// **'Rischi e questionari'**
  String get preventionTabRisks;

  /// No description provided for @preventionTabHistory.
  ///
  /// In it, this message translates to:
  /// **'Storico'**
  String get preventionTabHistory;

  /// No description provided for @preventionNextSteps.
  ///
  /// In it, this message translates to:
  /// **'Prossimi passi'**
  String get preventionNextSteps;

  /// No description provided for @preventionRegistered.
  ///
  /// In it, this message translates to:
  /// **'Controlli registrati'**
  String get preventionRegistered;

  /// No description provided for @preventionNoRegistered.
  ///
  /// In it, this message translates to:
  /// **'Nessun controllo registrato.'**
  String get preventionNoRegistered;

  /// No description provided for @preventionNoUpcoming.
  ///
  /// In it, this message translates to:
  /// **'Nessun controllo da programmare.'**
  String get preventionNoUpcoming;

  /// No description provided for @preventionStatusScheduled.
  ///
  /// In it, this message translates to:
  /// **'Programmata'**
  String get preventionStatusScheduled;

  /// No description provided for @preventionStatusPlan.
  ///
  /// In it, this message translates to:
  /// **'Da programmare'**
  String get preventionStatusPlan;

  /// No description provided for @preventionStatusAgree.
  ///
  /// In it, this message translates to:
  /// **'Da concordare'**
  String get preventionStatusAgree;

  /// No description provided for @preventionStatusComplete.
  ///
  /// In it, this message translates to:
  /// **'Da completare'**
  String get preventionStatusComplete;

  /// No description provided for @preventionPlanShort.
  ///
  /// In it, this message translates to:
  /// **'PROGRAMMA'**
  String get preventionPlanShort;

  /// No description provided for @preventionAgreeShort.
  ///
  /// In it, this message translates to:
  /// **'CONCORDA'**
  String get preventionAgreeShort;

  /// No description provided for @preventionExamDone.
  ///
  /// In it, this message translates to:
  /// **'Ho fatto l\'esame'**
  String get preventionExamDone;

  /// No description provided for @preventionIgnore.
  ///
  /// In it, this message translates to:
  /// **'Ignora'**
  String get preventionIgnore;

  /// No description provided for @preventionIgnoreTitle.
  ///
  /// In it, this message translates to:
  /// **'Ignorare questa raccomandazione?'**
  String get preventionIgnoreTitle;

  /// No description provided for @preventionIgnoreReason.
  ///
  /// In it, this message translates to:
  /// **'Motivo (facoltativo)'**
  String get preventionIgnoreReason;

  /// No description provided for @preventionUploadDocument.
  ///
  /// In it, this message translates to:
  /// **'Carica e collega il documento'**
  String get preventionUploadDocument;

  /// No description provided for @preventionDoneWithoutDocument.
  ///
  /// In it, this message translates to:
  /// **'Segna come fatto senza documento'**
  String get preventionDoneWithoutDocument;

  /// No description provided for @preventionInitialQuestionnaires.
  ///
  /// In it, this message translates to:
  /// **'Questionari iniziali'**
  String get preventionInitialQuestionnaires;

  /// No description provided for @preventionLinkExam.
  ///
  /// In it, this message translates to:
  /// **'Collega un nuovo esame'**
  String get preventionLinkExam;

  /// No description provided for @preventionDropZone.
  ///
  /// In it, this message translates to:
  /// **'Carica il documento dell\'esame per conservarlo nell\'Archivio e collegarlo al controllo.'**
  String get preventionDropZone;

  /// No description provided for @preventionProfileTitle.
  ///
  /// In it, this message translates to:
  /// **'Il profilo di prevenzione'**
  String get preventionProfileTitle;

  /// No description provided for @preventionAgeMissing.
  ///
  /// In it, this message translates to:
  /// **'Età da completare nel profilo'**
  String get preventionAgeMissing;

  /// No description provided for @preventionAgeValue.
  ///
  /// In it, this message translates to:
  /// **'{age} anni'**
  String preventionAgeValue(int age);

  /// No description provided for @preventionLifestyleComplete.
  ///
  /// In it, this message translates to:
  /// **'Stili di vita e familiarità completati'**
  String get preventionLifestyleComplete;

  /// No description provided for @preventionLifestyleMissing.
  ///
  /// In it, this message translates to:
  /// **'Stili di vita e familiarità da completare'**
  String get preventionLifestyleMissing;

  /// No description provided for @preventionCompleteQuestionnaire.
  ///
  /// In it, this message translates to:
  /// **'Completa il questionario'**
  String get preventionCompleteQuestionnaire;

  /// No description provided for @preventionRisksQuestionnaires.
  ///
  /// In it, this message translates to:
  /// **'Rischi e questionari'**
  String get preventionRisksQuestionnaires;

  /// No description provided for @preventionFamilyCardio.
  ///
  /// In it, this message translates to:
  /// **'Cuore e circolazione'**
  String get preventionFamilyCardio;

  /// No description provided for @preventionFamilyDiabetes.
  ///
  /// In it, this message translates to:
  /// **'Diabete di tipo 2'**
  String get preventionFamilyDiabetes;

  /// No description provided for @preventionFamilyKidney.
  ///
  /// In it, this message translates to:
  /// **'Reni'**
  String get preventionFamilyKidney;

  /// No description provided for @preventionFamilyFracture.
  ///
  /// In it, this message translates to:
  /// **'Ossa'**
  String get preventionFamilyFracture;

  /// No description provided for @preventionFractureRule.
  ///
  /// In it, this message translates to:
  /// **'Fattori di frattura'**
  String get preventionFractureRule;

  /// No description provided for @preventionRiskLow.
  ///
  /// In it, this message translates to:
  /// **'Basso'**
  String get preventionRiskLow;

  /// No description provided for @preventionRiskMedium.
  ///
  /// In it, this message translates to:
  /// **'Medio'**
  String get preventionRiskMedium;

  /// No description provided for @preventionRiskHigh.
  ///
  /// In it, this message translates to:
  /// **'Alto'**
  String get preventionRiskHigh;

  /// No description provided for @preventionDataIncomplete.
  ///
  /// In it, this message translates to:
  /// **'Dati da completare'**
  String get preventionDataIncomplete;

  /// No description provided for @preventionMissingCardio.
  ///
  /// In it, this message translates to:
  /// **'Servono pressione, colesterolo totale, HDL, risposta sul fumo ed età tra 40 e 69 anni.'**
  String get preventionMissingCardio;

  /// No description provided for @preventionMissingQuestionnaire.
  ///
  /// In it, this message translates to:
  /// **'Completa il questionario iniziale.'**
  String get preventionMissingQuestionnaire;

  /// No description provided for @preventionMissingKidney.
  ///
  /// In it, this message translates to:
  /// **'Serve un valore recente della creatinina.'**
  String get preventionMissingKidney;

  /// No description provided for @preventionCompleteData.
  ///
  /// In it, this message translates to:
  /// **'Completa i dati'**
  String get preventionCompleteData;

  /// No description provided for @preventionCalculatedOn.
  ///
  /// In it, this message translates to:
  /// **'Calcolato il {date}'**
  String preventionCalculatedOn(Object date);

  /// No description provided for @preventionProjection.
  ///
  /// In it, this message translates to:
  /// **'Se nulla cambia: {score}'**
  String preventionProjection(Object score);

  /// No description provided for @preventionRuleDraft.
  ///
  /// In it, this message translates to:
  /// **'Regola in validazione'**
  String get preventionRuleDraft;

  /// No description provided for @preventionWhy.
  ///
  /// In it, this message translates to:
  /// **'Perché'**
  String get preventionWhy;

  /// No description provided for @preventionOpenHistory.
  ///
  /// In it, this message translates to:
  /// **'Apri lo storico'**
  String get preventionOpenHistory;

  /// No description provided for @preventionScorePercent.
  ///
  /// In it, this message translates to:
  /// **'{score}% a 10 anni'**
  String preventionScorePercent(Object score);

  /// No description provided for @preventionScorePoints.
  ///
  /// In it, this message translates to:
  /// **'{score} punti'**
  String preventionScorePoints(Object score);

  /// No description provided for @preventionScoreEgfr.
  ///
  /// In it, this message translates to:
  /// **'{score} mL/min/1,73 m²'**
  String preventionScoreEgfr(Object score);

  /// No description provided for @preventionScoreFactors.
  ///
  /// In it, this message translates to:
  /// **'{score} fattori'**
  String preventionScoreFactors(Object score);

  /// No description provided for @preventionFactorAge.
  ///
  /// In it, this message translates to:
  /// **'Età'**
  String get preventionFactorAge;

  /// No description provided for @preventionFactorSex.
  ///
  /// In it, this message translates to:
  /// **'Sesso'**
  String get preventionFactorSex;

  /// No description provided for @preventionNotAvailable.
  ///
  /// In it, this message translates to:
  /// **'Non disponibile'**
  String get preventionNotAvailable;

  /// No description provided for @preventionFraxLink.
  ///
  /// In it, this message translates to:
  /// **'Calcola FRAX sul sito ufficiale: https://frax.shef.ac.uk/FRAX/'**
  String get preventionFraxLink;

  /// No description provided for @preventionFraxPrivacy.
  ///
  /// In it, this message translates to:
  /// **'Nessun dato viene inviato da Medical 24.'**
  String get preventionFraxPrivacy;

  /// No description provided for @preventionRiskDisclaimer.
  ///
  /// In it, this message translates to:
  /// **'Stime statistiche da algoritmi pubblici, non diagnosi: discutile con il medico.'**
  String get preventionRiskDisclaimer;

  /// No description provided for @preventionHistoryTitle.
  ///
  /// In it, this message translates to:
  /// **'Storico del rischio'**
  String get preventionHistoryTitle;

  /// No description provided for @preventionHistoryRecommendations.
  ///
  /// In it, this message translates to:
  /// **'Controlli conclusi e ignorati'**
  String get preventionHistoryRecommendations;

  /// No description provided for @preventionRiskTimeline.
  ///
  /// In it, this message translates to:
  /// **'Linea del tempo dei punteggi'**
  String get preventionRiskTimeline;

  /// No description provided for @preventionNoHistory.
  ///
  /// In it, this message translates to:
  /// **'Non c\'è ancora uno storico.'**
  String get preventionNoHistory;

  /// No description provided for @preventionReopen.
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get preventionReopen;

  /// No description provided for @preventionLoadError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a caricare la prevenzione.'**
  String get preventionLoadError;

  /// No description provided for @preventionSaveError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a salvare le risposte.'**
  String get preventionSaveError;

  /// No description provided for @preventionRecommendationFallback.
  ///
  /// In it, this message translates to:
  /// **'Controllo di prevenzione'**
  String get preventionRecommendationFallback;

  /// No description provided for @preventionQuestionnaireTitle.
  ///
  /// In it, this message translates to:
  /// **'Questionario di prevenzione'**
  String get preventionQuestionnaireTitle;

  /// No description provided for @preventionQuestionnaireIntro.
  ///
  /// In it, this message translates to:
  /// **'Le risposte servono ai calcoli di prevenzione e si possono cambiare in ogni momento.'**
  String get preventionQuestionnaireIntro;

  /// No description provided for @questionnaireStep.
  ///
  /// In it, this message translates to:
  /// **'Passo {step} di 4 · {title}'**
  String questionnaireStep(int step, String title);

  /// No description provided for @questionnaireNext.
  ///
  /// In it, this message translates to:
  /// **'Avanti'**
  String get questionnaireNext;

  /// No description provided for @questionnaireSave.
  ///
  /// In it, this message translates to:
  /// **'Salva le risposte'**
  String get questionnaireSave;

  /// No description provided for @questionnaireMissing.
  ///
  /// In it, this message translates to:
  /// **'Manca: {fields}'**
  String questionnaireMissing(String fields);

  /// No description provided for @questionnaireSaved.
  ///
  /// In it, this message translates to:
  /// **'Risposte salvate'**
  String get questionnaireSaved;

  /// No description provided for @questionnaireSavedWeightWarning.
  ///
  /// In it, this message translates to:
  /// **'Risposte salvate. Non siamo riusciti ad aggiungere il peso allo storico.'**
  String get questionnaireSavedWeightWarning;

  /// No description provided for @questionnaireLastCompleted.
  ///
  /// In it, this message translates to:
  /// **'Ultima compilazione: {date}'**
  String questionnaireLastCompleted(String date);

  /// No description provided for @questionnaireUpdate.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get questionnaireUpdate;

  /// No description provided for @questionnaireSummary.
  ///
  /// In it, this message translates to:
  /// **'Riepilogo delle risposte'**
  String get questionnaireSummary;

  /// No description provided for @questionnaireSummaryMeasures.
  ///
  /// In it, this message translates to:
  /// **'Altezza {height} cm · Peso {weight} kg · Vita {waist} cm · BMI {bmi}'**
  String questionnaireSummaryMeasures(
      String height, String weight, String waist, String bmi);

  /// No description provided for @questionGroupLifestyle.
  ///
  /// In it, this message translates to:
  /// **'Stile di vita'**
  String get questionGroupLifestyle;

  /// No description provided for @questionGroupFamily.
  ///
  /// In it, this message translates to:
  /// **'Familiarità e salute'**
  String get questionGroupFamily;

  /// No description provided for @questionGroupMeasures.
  ///
  /// In it, this message translates to:
  /// **'Misure'**
  String get questionGroupMeasures;

  /// No description provided for @questionGroupBones.
  ///
  /// In it, this message translates to:
  /// **'Ossa'**
  String get questionGroupBones;

  /// No description provided for @questionSmoker.
  ///
  /// In it, this message translates to:
  /// **'Fumi?'**
  String get questionSmoker;

  /// No description provided for @questionPhysicalActivity.
  ///
  /// In it, this message translates to:
  /// **'Fai almeno 30 minuti di attività fisica al giorno?'**
  String get questionPhysicalActivity;

  /// No description provided for @questionFruitVegetables.
  ///
  /// In it, this message translates to:
  /// **'Mangi frutta o verdura ogni giorno?'**
  String get questionFruitVegetables;

  /// No description provided for @questionAlcohol.
  ///
  /// In it, this message translates to:
  /// **'Bevi almeno 3 unità di alcol al giorno?'**
  String get questionAlcohol;

  /// No description provided for @questionAntihypertensive.
  ///
  /// In it, this message translates to:
  /// **'Assumi farmaci per la pressione?'**
  String get questionAntihypertensive;

  /// No description provided for @questionHighGlucose.
  ///
  /// In it, this message translates to:
  /// **'Hai avuto valori alti di glicemia?'**
  String get questionHighGlucose;

  /// No description provided for @questionFamilyDiabetes.
  ///
  /// In it, this message translates to:
  /// **'Familiarità per diabete'**
  String get questionFamilyDiabetes;

  /// No description provided for @questionFamilyNone.
  ///
  /// In it, this message translates to:
  /// **'Nessuna'**
  String get questionFamilyNone;

  /// No description provided for @questionFamilySecond.
  ///
  /// In it, this message translates to:
  /// **'Parenti di secondo grado'**
  String get questionFamilySecond;

  /// No description provided for @questionFamilyFirst.
  ///
  /// In it, this message translates to:
  /// **'Parenti di primo grado'**
  String get questionFamilyFirst;

  /// No description provided for @questionWaist.
  ///
  /// In it, this message translates to:
  /// **'Circonferenza vita'**
  String get questionWaist;

  /// No description provided for @questionHeight.
  ///
  /// In it, this message translates to:
  /// **'Altezza'**
  String get questionHeight;

  /// No description provided for @questionWeight.
  ///
  /// In it, this message translates to:
  /// **'Peso'**
  String get questionWeight;

  /// No description provided for @questionWeightRecorded.
  ///
  /// In it, this message translates to:
  /// **'Ultimo peso registrato il {date}; puoi modificarlo.'**
  String questionWeightRecorded(String date);

  /// No description provided for @questionBmi.
  ///
  /// In it, this message translates to:
  /// **'Indice di massa corporea'**
  String get questionBmi;

  /// No description provided for @questionBmiUnavailable.
  ///
  /// In it, this message translates to:
  /// **'BMI non disponibile: servono altezza e un peso recente.'**
  String get questionBmiUnavailable;

  /// No description provided for @questionBmiValue.
  ///
  /// In it, this message translates to:
  /// **'BMI {value}'**
  String questionBmiValue(Object value);

  /// No description provided for @questionPreviousFracture.
  ///
  /// In it, this message translates to:
  /// **'Hai avuto una frattura in precedenza?'**
  String get questionPreviousFracture;

  /// No description provided for @questionParentHipFracture.
  ///
  /// In it, this message translates to:
  /// **'Un genitore ha avuto una frattura dell\'anca?'**
  String get questionParentHipFracture;

  /// No description provided for @questionGlucocorticoids.
  ///
  /// In it, this message translates to:
  /// **'Assumi glucocorticoidi?'**
  String get questionGlucocorticoids;

  /// No description provided for @questionRheumatoid.
  ///
  /// In it, this message translates to:
  /// **'Hai indicato artrite reumatoide?'**
  String get questionRheumatoid;

  /// No description provided for @questionSecondaryOsteoporosis.
  ///
  /// In it, this message translates to:
  /// **'Hai indicato osteoporosi secondaria?'**
  String get questionSecondaryOsteoporosis;

  /// No description provided for @questionBmd.
  ///
  /// In it, this message translates to:
  /// **'Densità ossea'**
  String get questionBmd;

  /// No description provided for @homeNextControl.
  ///
  /// In it, this message translates to:
  /// **'Prossimo controllo'**
  String get homeNextControl;

  /// No description provided for @homeCompleteQuestionnaires.
  ///
  /// In it, this message translates to:
  /// **'Completa i questionari'**
  String get homeCompleteQuestionnaires;

  /// No description provided for @recommendationScreeningMammografia.
  ///
  /// In it, this message translates to:
  /// **'Mammografia'**
  String get recommendationScreeningMammografia;

  /// No description provided for @recommendationScreeningCervicePap.
  ///
  /// In it, this message translates to:
  /// **'Pap test'**
  String get recommendationScreeningCervicePap;

  /// No description provided for @recommendationScreeningCerviceHpv.
  ///
  /// In it, this message translates to:
  /// **'Test HPV'**
  String get recommendationScreeningCerviceHpv;

  /// No description provided for @recommendationScreeningColon.
  ///
  /// In it, this message translates to:
  /// **'Ricerca del sangue occulto nelle feci'**
  String get recommendationScreeningColon;

  /// No description provided for @recommendationPressione.
  ///
  /// In it, this message translates to:
  /// **'Misurazione della pressione arteriosa'**
  String get recommendationPressione;

  /// No description provided for @recommendationLipidi.
  ///
  /// In it, this message translates to:
  /// **'Profilo lipidico'**
  String get recommendationLipidi;

  /// No description provided for @recommendationGlicemia.
  ///
  /// In it, this message translates to:
  /// **'Glicemia a digiuno'**
  String get recommendationGlicemia;

  /// No description provided for @recommendationPesoBmi.
  ///
  /// In it, this message translates to:
  /// **'Peso e indice di massa corporea'**
  String get recommendationPesoBmi;

  /// No description provided for @recommendationVista.
  ///
  /// In it, this message translates to:
  /// **'Visita oculistica'**
  String get recommendationVista;

  /// No description provided for @recommendationUdito.
  ///
  /// In it, this message translates to:
  /// **'Controllo dell\'udito'**
  String get recommendationUdito;

  /// No description provided for @recommendationDentista.
  ///
  /// In it, this message translates to:
  /// **'Visita odontoiatrica'**
  String get recommendationDentista;

  /// No description provided for @recommendationDermatologo.
  ///
  /// In it, this message translates to:
  /// **'Controllo dei nei'**
  String get recommendationDermatologo;

  /// No description provided for @recommendationVaccinoInfluenza.
  ///
  /// In it, this message translates to:
  /// **'Vaccino antinfluenzale'**
  String get recommendationVaccinoInfluenza;

  /// No description provided for @recommendationVaccinoPneumococco.
  ///
  /// In it, this message translates to:
  /// **'Vaccino antipneumococcico'**
  String get recommendationVaccinoPneumococco;

  /// No description provided for @recommendationVaccinoZoster.
  ///
  /// In it, this message translates to:
  /// **'Vaccino contro l\'herpes zoster'**
  String get recommendationVaccinoZoster;

  /// No description provided for @recommendationVaccinoTetano.
  ///
  /// In it, this message translates to:
  /// **'Richiamo difterite-tetano-pertosse'**
  String get recommendationVaccinoTetano;

  /// No description provided for @recommendationPsa.
  ///
  /// In it, this message translates to:
  /// **'Valutazione del rischio prostatico con il medico'**
  String get recommendationPsa;

  /// No description provided for @recommendationDensitometria.
  ///
  /// In it, this message translates to:
  /// **'Densitometria ossea (MOC)'**
  String get recommendationDensitometria;

  /// No description provided for @recommendationAaa.
  ///
  /// In it, this message translates to:
  /// **'Ecografia dell\'aorta addominale'**
  String get recommendationAaa;

  /// No description provided for @recommendationGlicemiaFindrisc.
  ///
  /// In it, this message translates to:
  /// **'Glicemia a digiuno'**
  String get recommendationGlicemiaFindrisc;

  /// No description provided for @recommendationLipidiScore2.
  ///
  /// In it, this message translates to:
  /// **'Controllo dei lipidi'**
  String get recommendationLipidiScore2;

  /// No description provided for @recommendationVisitaCardiologicaScore2.
  ///
  /// In it, this message translates to:
  /// **'Visita cardiologica'**
  String get recommendationVisitaCardiologicaScore2;

  /// No description provided for @recommendationVisitaNefrologicaEgfr.
  ///
  /// In it, this message translates to:
  /// **'Visita nefrologica'**
  String get recommendationVisitaNefrologicaEgfr;

  /// No description provided for @recommendationCreatininaEgfr.
  ///
  /// In it, this message translates to:
  /// **'Controllo della creatinina'**
  String get recommendationCreatininaEgfr;

  /// No description provided for @recommendationDensitometriaFrattura.
  ///
  /// In it, this message translates to:
  /// **'Densitometria per rischio frattura'**
  String get recommendationDensitometriaFrattura;

  /// No description provided for @recommendationLevelImproved.
  ///
  /// In it, this message translates to:
  /// **'Livello di rischio migliorato'**
  String get recommendationLevelImproved;

  /// No description provided for @recommendationScreeningMammografiaReason.
  ///
  /// In it, this message translates to:
  /// **'Programma di screening organizzato del SSN; alcune Regioni includono 45–74 anni.'**
  String get recommendationScreeningMammografiaReason;

  /// No description provided for @recommendationScreeningCervicePapReason.
  ///
  /// In it, this message translates to:
  /// **'Programma di screening organizzato del SSN.'**
  String get recommendationScreeningCervicePapReason;

  /// No description provided for @recommendationScreeningCerviceHpvReason.
  ///
  /// In it, this message translates to:
  /// **'Programma di screening organizzato del SSN.'**
  String get recommendationScreeningCerviceHpvReason;

  /// No description provided for @recommendationScreeningColonReason.
  ///
  /// In it, this message translates to:
  /// **'Programma di screening organizzato del SSN; alcune Regioni includono fino a 74 anni.'**
  String get recommendationScreeningColonReason;

  /// No description provided for @recommendationPressioneReason.
  ///
  /// In it, this message translates to:
  /// **'Dai 40 anni il controllo può essere annuale; con valori elevati segue le indicazioni del medico.'**
  String get recommendationPressioneReason;

  /// No description provided for @recommendationLipidiReason.
  ///
  /// In it, this message translates to:
  /// **'Può essere più frequente con fattori di rischio o terapia, secondo il medico.'**
  String get recommendationLipidiReason;

  /// No description provided for @recommendationGlicemiaReason.
  ///
  /// In it, this message translates to:
  /// **'Può essere anticipata o più frequente con fattori di rischio.'**
  String get recommendationGlicemiaReason;

  /// No description provided for @recommendationPesoBmiReason.
  ///
  /// In it, this message translates to:
  /// **'Controllo periodico di peso e indice di massa corporea.'**
  String get recommendationPesoBmiReason;

  /// No description provided for @recommendationVistaReason.
  ///
  /// In it, this message translates to:
  /// **'Dai 65 anni il controllo può essere annuale.'**
  String get recommendationVistaReason;

  /// No description provided for @recommendationUditoReason.
  ///
  /// In it, this message translates to:
  /// **'Controllo periodico dell\'udito dai 65 anni.'**
  String get recommendationUditoReason;

  /// No description provided for @recommendationDentistaReason.
  ///
  /// In it, this message translates to:
  /// **'Controllo odontoiatrico periodico.'**
  String get recommendationDentistaReason;

  /// No description provided for @recommendationDermatologoReason.
  ///
  /// In it, this message translates to:
  /// **'Può essere più frequente con familiarità o molti nei.'**
  String get recommendationDermatologoReason;

  /// No description provided for @recommendationVaccinoInfluenzaReason.
  ///
  /// In it, this message translates to:
  /// **'Ogni autunno dai 60 anni e per le categorie a rischio.'**
  String get recommendationVaccinoInfluenzaReason;

  /// No description provided for @recommendationVaccinoPneumococcoReason.
  ///
  /// In it, this message translates to:
  /// **'Una volta, con schema secondo il calendario vaccinale nazionale.'**
  String get recommendationVaccinoPneumococcoReason;

  /// No description provided for @recommendationVaccinoZosterReason.
  ///
  /// In it, this message translates to:
  /// **'Secondo il calendario vaccinale nazionale.'**
  String get recommendationVaccinoZosterReason;

  /// No description provided for @recommendationVaccinoTetanoReason.
  ///
  /// In it, this message translates to:
  /// **'Richiamo ogni 10 anni.'**
  String get recommendationVaccinoTetanoReason;

  /// No description provided for @recommendationPsaReason.
  ///
  /// In it, this message translates to:
  /// **'Decisione condivisa con il medico; non è uno screening di popolazione.'**
  String get recommendationPsaReason;

  /// No description provided for @recommendationDensitometriaReason.
  ///
  /// In it, this message translates to:
  /// **'Prima in presenza di fattori di rischio; uomini dai 70 anni.'**
  String get recommendationDensitometriaReason;

  /// No description provided for @recommendationAaaReason.
  ///
  /// In it, this message translates to:
  /// **'Una volta tra 65 e 75 anni se fumatore o ex fumatore.'**
  String get recommendationAaaReason;

  /// No description provided for @recommendationGlicemiaFindriscReason.
  ///
  /// In it, this message translates to:
  /// **'Consigliata perché il punteggio FINDRISC è medio o alto'**
  String get recommendationGlicemiaFindriscReason;

  /// No description provided for @recommendationLipidiScore2Reason.
  ///
  /// In it, this message translates to:
  /// **'Consigliata perché il punteggio SCORE2 è medio o alto'**
  String get recommendationLipidiScore2Reason;

  /// No description provided for @recommendationVisitaCardiologicaScore2Reason.
  ///
  /// In it, this message translates to:
  /// **'Consigliata perché il punteggio SCORE2 indica un rischio aumentato'**
  String get recommendationVisitaCardiologicaScore2Reason;

  /// No description provided for @recommendationVisitaNefrologicaEgfrReason.
  ///
  /// In it, this message translates to:
  /// **'Consigliata perché il valore eGFR è ridotto'**
  String get recommendationVisitaNefrologicaEgfrReason;

  /// No description provided for @recommendationCreatininaEgfrReason.
  ///
  /// In it, this message translates to:
  /// **'Consigliata perché la creatinina richiede un controllo'**
  String get recommendationCreatininaEgfrReason;

  /// No description provided for @recommendationDensitometriaFratturaReason.
  ///
  /// In it, this message translates to:
  /// **'Consigliata perché il rischio di frattura è medio o alto'**
  String get recommendationDensitometriaFratturaReason;

  /// No description provided for @explanationTitle.
  ///
  /// In it, this message translates to:
  /// **'Spiegazione'**
  String get explanationTitle;

  /// No description provided for @explanationSimple.
  ///
  /// In it, this message translates to:
  /// **'Semplice'**
  String get explanationSimple;

  /// No description provided for @explanationClinical.
  ///
  /// In it, this message translates to:
  /// **'Clinico'**
  String get explanationClinical;

  /// No description provided for @explanationMore.
  ///
  /// In it, this message translates to:
  /// **'Altre azioni'**
  String get explanationMore;

  /// No description provided for @explanationExplainValue.
  ///
  /// In it, this message translates to:
  /// **'Spiegami questo valore'**
  String get explanationExplainValue;

  /// No description provided for @explanationExplainOrgan.
  ///
  /// In it, this message translates to:
  /// **'Spiegami questo organo'**
  String get explanationExplainOrgan;

  /// No description provided for @explanationExplainRisk.
  ///
  /// In it, this message translates to:
  /// **'Spiegami questo rischio'**
  String get explanationExplainRisk;

  /// No description provided for @explanationExplainDocument.
  ///
  /// In it, this message translates to:
  /// **'Spiegami questo referto'**
  String get explanationExplainDocument;

  /// No description provided for @explanationReportCta.
  ///
  /// In it, this message translates to:
  /// **'Spiegami questo referto'**
  String get explanationReportCta;

  /// No description provided for @explanationReportCtaReread.
  ///
  /// In it, this message translates to:
  /// **'Rileggi la spiegazione'**
  String get explanationReportCtaReread;

  /// No description provided for @explanationReportCtaDisabled.
  ///
  /// In it, this message translates to:
  /// **'Conferma almeno un valore'**
  String get explanationReportCtaDisabled;

  /// No description provided for @explanationUsageNote.
  ///
  /// In it, this message translates to:
  /// **'Conta tra le {count} spiegazioni disponibili oggi'**
  String explanationUsageNote(int count);

  /// No description provided for @explanationWriting.
  ///
  /// In it, this message translates to:
  /// **'Sto scrivendo la spiegazione…'**
  String get explanationWriting;

  /// No description provided for @explanationGeneratedMeta.
  ///
  /// In it, this message translates to:
  /// **'Testo generato dall\'IA · {model} · {date}'**
  String explanationGeneratedMeta(String model, String date);

  /// No description provided for @explanationUpdatedAt.
  ///
  /// In it, this message translates to:
  /// **'Aggiornata al {date}'**
  String explanationUpdatedAt(String date);

  /// No description provided for @explanationRequiredClosing.
  ///
  /// In it, this message translates to:
  /// **'Le informazioni non sostituiscono il parere del medico.'**
  String get explanationRequiredClosing;

  /// No description provided for @explanationUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Per questo dato non riusciamo a dare una spiegazione affidabile'**
  String get explanationUnavailable;

  /// No description provided for @explanationUnavailableAdvice.
  ///
  /// In it, this message translates to:
  /// **'Parlane con il medico.'**
  String get explanationUnavailableAdvice;

  /// No description provided for @explanationLimitReached.
  ///
  /// In it, this message translates to:
  /// **'Hai raggiunto le 30 spiegazioni di oggi'**
  String get explanationLimitReached;

  /// No description provided for @explanationLimitTomorrow.
  ///
  /// In it, this message translates to:
  /// **'Potrai chiedere nuove spiegazioni domani.'**
  String get explanationLimitTomorrow;

  /// No description provided for @explanationError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a creare la spiegazione'**
  String get explanationError;

  /// No description provided for @explanationErrorAdvice.
  ///
  /// In it, this message translates to:
  /// **'Controlla la connessione e riprova.'**
  String get explanationErrorAdvice;

  /// No description provided for @explanationConfirmValues.
  ///
  /// In it, this message translates to:
  /// **'Conferma i valori per avere la spiegazione.'**
  String get explanationConfirmValues;

  /// No description provided for @explanationRegenerate.
  ///
  /// In it, this message translates to:
  /// **'Rigenera'**
  String get explanationRegenerate;

  /// No description provided for @explanationRegenerateTitle.
  ///
  /// In it, this message translates to:
  /// **'Rigenerare la spiegazione?'**
  String get explanationRegenerateTitle;

  /// No description provided for @explanationRegenerateConfirm.
  ///
  /// In it, this message translates to:
  /// **'La rigenerazione conta nel limite giornaliero e sostituisce la versione mostrata.'**
  String get explanationRegenerateConfirm;

  /// No description provided for @aiTaskPaused.
  ///
  /// In it, this message translates to:
  /// **'Il servizio IA è temporaneamente in pausa.'**
  String get aiTaskPaused;

  /// No description provided for @maintenanceMessage.
  ///
  /// In it, this message translates to:
  /// **'Medical 24 è in manutenzione. Riprova tra poco.'**
  String get maintenanceMessage;

  /// No description provided for @adminGovernment.
  ///
  /// In it, this message translates to:
  /// **'Governo'**
  String get adminGovernment;

  /// No description provided for @adminOverview.
  ///
  /// In it, this message translates to:
  /// **'Panoramica'**
  String get adminOverview;

  /// No description provided for @adminAiTasks.
  ///
  /// In it, this message translates to:
  /// **'Compiti AI'**
  String get adminAiTasks;

  /// No description provided for @adminSettings.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get adminSettings;

  /// No description provided for @adminPrompts.
  ///
  /// In it, this message translates to:
  /// **'Prompt'**
  String get adminPrompts;

  /// No description provided for @adminUsage.
  ///
  /// In it, this message translates to:
  /// **'Consumi'**
  String get adminUsage;

  /// No description provided for @adminEvents.
  ///
  /// In it, this message translates to:
  /// **'Eventi'**
  String get adminEvents;

  /// No description provided for @adminAudit.
  ///
  /// In it, this message translates to:
  /// **'Audit'**
  String get adminAudit;

  /// No description provided for @adminRules.
  ///
  /// In it, this message translates to:
  /// **'Regole'**
  String get adminRules;

  /// No description provided for @adminSoon.
  ///
  /// In it, this message translates to:
  /// **'Presto'**
  String get adminSoon;

  /// No description provided for @adminDesktopOnly.
  ///
  /// In it, this message translates to:
  /// **'Il pannello di governo è disponibile su desktop'**
  String get adminDesktopOnly;

  /// No description provided for @adminDesktopOnlyBody.
  ///
  /// In it, this message translates to:
  /// **'Apri Medical 24 su uno schermo largo almeno 1200 pt.'**
  String get adminDesktopOnlyBody;

  /// No description provided for @adminForbiddenTitle.
  ///
  /// In it, this message translates to:
  /// **'403 · Accesso non consentito'**
  String get adminForbiddenTitle;

  /// No description provided for @adminForbiddenBody.
  ///
  /// In it, this message translates to:
  /// **'Questa area è riservata agli amministratori.'**
  String get adminForbiddenBody;

  /// No description provided for @adminAccessError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a verificare i permessi.'**
  String get adminAccessError;

  /// No description provided for @adminBackHome.
  ///
  /// In it, this message translates to:
  /// **'Torna alla home'**
  String get adminBackHome;

  /// No description provided for @adminBackToApp.
  ///
  /// In it, this message translates to:
  /// **'Torna all\'app'**
  String get adminBackToApp;

  /// No description provided for @adminRefresh.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get adminRefresh;

  /// No description provided for @adminUsersTotal.
  ///
  /// In it, this message translates to:
  /// **'Utenti totali'**
  String get adminUsersTotal;

  /// No description provided for @adminUsersActive7d.
  ///
  /// In it, this message translates to:
  /// **'Attivi 7 giorni'**
  String get adminUsersActive7d;

  /// No description provided for @adminUsersActive30d.
  ///
  /// In it, this message translates to:
  /// **'Attivi 30 giorni'**
  String get adminUsersActive30d;

  /// No description provided for @adminDocuments.
  ///
  /// In it, this message translates to:
  /// **'Documenti'**
  String get adminDocuments;

  /// No description provided for @adminExtractionsOk.
  ///
  /// In it, this message translates to:
  /// **'Estrazioni riuscite · 7 gg'**
  String get adminExtractionsOk;

  /// No description provided for @adminExtractionsFailed.
  ///
  /// In it, this message translates to:
  /// **'Estrazioni fallite · 7 gg'**
  String get adminExtractionsFailed;

  /// No description provided for @adminExtractionsReview.
  ///
  /// In it, this message translates to:
  /// **'Da verificare · 7 gg'**
  String get adminExtractionsReview;

  /// No description provided for @adminCostToday.
  ///
  /// In it, this message translates to:
  /// **'Costo oggi per compito'**
  String get adminCostToday;

  /// No description provided for @adminCostMonth.
  ///
  /// In it, this message translates to:
  /// **'Costo mese per compito'**
  String get adminCostMonth;

  /// No description provided for @adminErrors24h.
  ///
  /// In it, this message translates to:
  /// **'Errori 24 ore per codice'**
  String get adminErrors24h;

  /// No description provided for @adminTaskStatus.
  ///
  /// In it, this message translates to:
  /// **'Stato dei compiti'**
  String get adminTaskStatus;

  /// No description provided for @adminLastHealth.
  ///
  /// In it, this message translates to:
  /// **'Ultimo health'**
  String get adminLastHealth;

  /// No description provided for @adminActive.
  ///
  /// In it, this message translates to:
  /// **'Attivo'**
  String get adminActive;

  /// No description provided for @adminDisabled.
  ///
  /// In it, this message translates to:
  /// **'Disabilitato'**
  String get adminDisabled;

  /// No description provided for @adminPaused.
  ///
  /// In it, this message translates to:
  /// **'In pausa'**
  String get adminPaused;

  /// No description provided for @adminPausedUntil.
  ///
  /// In it, this message translates to:
  /// **'In pausa fino a {date}'**
  String adminPausedUntil(String date);

  /// No description provided for @adminAiTasksModels.
  ///
  /// In it, this message translates to:
  /// **'Compiti AI e modelli'**
  String get adminAiTasksModels;

  /// No description provided for @adminTask.
  ///
  /// In it, this message translates to:
  /// **'Compito'**
  String get adminTask;

  /// No description provided for @adminModel.
  ///
  /// In it, this message translates to:
  /// **'Modello'**
  String get adminModel;

  /// No description provided for @adminFallback.
  ///
  /// In it, this message translates to:
  /// **'Fallback'**
  String get adminFallback;

  /// No description provided for @adminPrompt.
  ///
  /// In it, this message translates to:
  /// **'Prompt attivo'**
  String get adminPrompt;

  /// No description provided for @adminBudgetProgress.
  ///
  /// In it, this message translates to:
  /// **'Budget / speso oggi'**
  String get adminBudgetProgress;

  /// No description provided for @adminStatus.
  ///
  /// In it, this message translates to:
  /// **'Stato'**
  String get adminStatus;

  /// No description provided for @adminEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get adminEdit;

  /// No description provided for @adminModels.
  ///
  /// In it, this message translates to:
  /// **'Modelli'**
  String get adminModels;

  /// No description provided for @adminNewModel.
  ///
  /// In it, this message translates to:
  /// **'Nuovo modello'**
  String get adminNewModel;

  /// No description provided for @adminEditModel.
  ///
  /// In it, this message translates to:
  /// **'Modifica modello'**
  String get adminEditModel;

  /// No description provided for @adminId.
  ///
  /// In it, this message translates to:
  /// **'ID'**
  String get adminId;

  /// No description provided for @adminProvider.
  ///
  /// In it, this message translates to:
  /// **'Provider'**
  String get adminProvider;

  /// No description provided for @adminName.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get adminName;

  /// No description provided for @adminPriceInput.
  ///
  /// In it, this message translates to:
  /// **'Input \$/MTok'**
  String get adminPriceInput;

  /// No description provided for @adminPriceOutput.
  ///
  /// In it, this message translates to:
  /// **'Output \$/MTok'**
  String get adminPriceOutput;

  /// No description provided for @adminPriceCache.
  ///
  /// In it, this message translates to:
  /// **'Cache letta \$/MTok'**
  String get adminPriceCache;

  /// No description provided for @adminPriceInputMicro.
  ///
  /// In it, this message translates to:
  /// **'Prezzo input in micro-USD/MTok'**
  String get adminPriceInputMicro;

  /// No description provided for @adminPriceOutputMicro.
  ///
  /// In it, this message translates to:
  /// **'Prezzo output in micro-USD/MTok'**
  String get adminPriceOutputMicro;

  /// No description provided for @adminPriceCacheMicro.
  ///
  /// In it, this message translates to:
  /// **'Prezzo cache letta in micro-USD/MTok'**
  String get adminPriceCacheMicro;

  /// No description provided for @adminContextWindow.
  ///
  /// In it, this message translates to:
  /// **'Finestra di contesto'**
  String get adminContextWindow;

  /// No description provided for @adminFallbackEnabled.
  ///
  /// In it, this message translates to:
  /// **'Fallback abilitato'**
  String get adminFallbackEnabled;

  /// No description provided for @adminMaxOutputTokens.
  ///
  /// In it, this message translates to:
  /// **'Token massimi in uscita'**
  String get adminMaxOutputTokens;

  /// No description provided for @adminEnabled.
  ///
  /// In it, this message translates to:
  /// **'Abilitato'**
  String get adminEnabled;

  /// No description provided for @adminDailyBudgetUsd.
  ///
  /// In it, this message translates to:
  /// **'Budget giornaliero in dollari'**
  String get adminDailyBudgetUsd;

  /// No description provided for @adminBudgetAction.
  ///
  /// In it, this message translates to:
  /// **'Azione sul budget'**
  String get adminBudgetAction;

  /// No description provided for @adminBudgetAlert.
  ///
  /// In it, this message translates to:
  /// **'Avvisa'**
  String get adminBudgetAlert;

  /// No description provided for @adminBudgetPause.
  ///
  /// In it, this message translates to:
  /// **'Metti in pausa'**
  String get adminBudgetPause;

  /// No description provided for @adminUserDailyLimit.
  ///
  /// In it, this message translates to:
  /// **'Limite giornaliero per utente'**
  String get adminUserDailyLimit;

  /// No description provided for @adminSecondApproval.
  ///
  /// In it, this message translates to:
  /// **'Seconda approvazione richiesta'**
  String get adminSecondApproval;

  /// No description provided for @adminRequestPreset.
  ///
  /// In it, this message translates to:
  /// **'Preimpostazione'**
  String get adminRequestPreset;

  /// No description provided for @adminEffort.
  ///
  /// In it, this message translates to:
  /// **'Senza ragionamento, sforzo {effort}'**
  String adminEffort(String effort);

  /// No description provided for @adminAdaptiveThinking.
  ///
  /// In it, this message translates to:
  /// **'Ragionamento adattivo'**
  String get adminAdaptiveThinking;

  /// No description provided for @adminRequestOptions.
  ///
  /// In it, this message translates to:
  /// **'Opzioni richiesta (JSON)'**
  String get adminRequestOptions;

  /// No description provided for @adminPositiveNumberError.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un numero maggiore di zero.'**
  String get adminPositiveNumberError;

  /// No description provided for @adminJsonObjectError.
  ///
  /// In it, this message translates to:
  /// **'Il JSON deve essere un oggetto.'**
  String get adminJsonObjectError;

  /// No description provided for @adminJsonInvalid.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un JSON valido.'**
  String get adminJsonInvalid;

  /// No description provided for @adminResume.
  ///
  /// In it, this message translates to:
  /// **'Riprendi'**
  String get adminResume;

  /// No description provided for @adminPauseTomorrow.
  ///
  /// In it, this message translates to:
  /// **'Metti in pausa fino a domani'**
  String get adminPauseTomorrow;

  /// No description provided for @adminModelInUse.
  ///
  /// In it, this message translates to:
  /// **'Il modello è in uso: cambia prima il modello del compito.'**
  String get adminModelInUse;

  /// No description provided for @adminKey.
  ///
  /// In it, this message translates to:
  /// **'Chiave'**
  String get adminKey;

  /// No description provided for @adminValue.
  ///
  /// In it, this message translates to:
  /// **'Valore'**
  String get adminValue;

  /// No description provided for @adminPublic.
  ///
  /// In it, this message translates to:
  /// **'Pubblica'**
  String get adminPublic;

  /// No description provided for @adminDescription.
  ///
  /// In it, this message translates to:
  /// **'Descrizione'**
  String get adminDescription;

  /// No description provided for @adminVersion.
  ///
  /// In it, this message translates to:
  /// **'Versione'**
  String get adminVersion;

  /// No description provided for @adminUpdatedAt.
  ///
  /// In it, this message translates to:
  /// **'Aggiornata il'**
  String get adminUpdatedAt;

  /// No description provided for @adminHistory.
  ///
  /// In it, this message translates to:
  /// **'Storico'**
  String get adminHistory;

  /// No description provided for @adminValueJson.
  ///
  /// In it, this message translates to:
  /// **'Valore JSON'**
  String get adminValueJson;

  /// No description provided for @adminMaintenance.
  ///
  /// In it, this message translates to:
  /// **'Modalità manutenzione'**
  String get adminMaintenance;

  /// No description provided for @adminMaintenanceBody.
  ///
  /// In it, this message translates to:
  /// **'Sospende le funzioni operative della piattaforma.'**
  String get adminMaintenanceBody;

  /// No description provided for @adminMaintenanceConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Cambiare la modalità manutenzione?'**
  String get adminMaintenanceConfirmTitle;

  /// No description provided for @adminMaintenanceConfirmBody.
  ///
  /// In it, this message translates to:
  /// **'La modifica ha effetto immediato per tutti gli utenti.'**
  String get adminMaintenanceConfirmBody;

  /// No description provided for @adminCompare.
  ///
  /// In it, this message translates to:
  /// **'Confronta'**
  String get adminCompare;

  /// No description provided for @adminRestore.
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get adminRestore;

  /// No description provided for @adminApprove.
  ///
  /// In it, this message translates to:
  /// **'Approva'**
  String get adminApprove;

  /// No description provided for @adminRunTest.
  ///
  /// In it, this message translates to:
  /// **'Esegui test'**
  String get adminRunTest;

  /// No description provided for @adminActivate.
  ///
  /// In it, this message translates to:
  /// **'Attiva'**
  String get adminActivate;

  /// No description provided for @adminFilterPassed.
  ///
  /// In it, this message translates to:
  /// **'Filtro superato'**
  String get adminFilterPassed;

  /// No description provided for @adminClosingPresent.
  ///
  /// In it, this message translates to:
  /// **'Chiusura presente'**
  String get adminClosingPresent;

  /// No description provided for @adminPrevious.
  ///
  /// In it, this message translates to:
  /// **'Precedente'**
  String get adminPrevious;

  /// No description provided for @adminNext.
  ///
  /// In it, this message translates to:
  /// **'Successiva'**
  String get adminNext;

  /// No description provided for @adminNewVersion.
  ///
  /// In it, this message translates to:
  /// **'Nuova versione'**
  String get adminNewVersion;

  /// No description provided for @adminCreatedBy.
  ///
  /// In it, this message translates to:
  /// **'Creato da'**
  String get adminCreatedBy;

  /// No description provided for @adminApprovedBy.
  ///
  /// In it, this message translates to:
  /// **'Approvato da'**
  String get adminApprovedBy;

  /// No description provided for @adminActivatedAt.
  ///
  /// In it, this message translates to:
  /// **'Attivato il'**
  String get adminActivatedAt;

  /// No description provided for @adminLastTest.
  ///
  /// In it, this message translates to:
  /// **'Ultimo test'**
  String get adminLastTest;

  /// No description provided for @adminPassed.
  ///
  /// In it, this message translates to:
  /// **'Superato'**
  String get adminPassed;

  /// No description provided for @adminFailed.
  ///
  /// In it, this message translates to:
  /// **'Fallito'**
  String get adminFailed;

  /// No description provided for @adminDraft.
  ///
  /// In it, this message translates to:
  /// **'Bozza'**
  String get adminDraft;

  /// No description provided for @adminRetired.
  ///
  /// In it, this message translates to:
  /// **'Ritirato'**
  String get adminRetired;

  /// No description provided for @adminTestResults.
  ///
  /// In it, this message translates to:
  /// **'Risultati del test'**
  String get adminTestResults;

  /// No description provided for @adminSecondApproverRequired.
  ///
  /// In it, this message translates to:
  /// **'Serve l\'approvazione di un secondo admin'**
  String get adminSecondApproverRequired;

  /// No description provided for @adminApprovalRequired.
  ///
  /// In it, this message translates to:
  /// **'Il prompt deve essere approvato prima dell\'attivazione.'**
  String get adminApprovalRequired;

  /// No description provided for @adminPassingTestRequired.
  ///
  /// In it, this message translates to:
  /// **'Serve un test superato prima dell\'attivazione.'**
  String get adminPassingTestRequired;

  /// No description provided for @adminRestoreConfirm.
  ///
  /// In it, this message translates to:
  /// **'Ripristinare la versione precedente per questo compito?'**
  String get adminRestoreConfirm;

  /// No description provided for @adminSaved.
  ///
  /// In it, this message translates to:
  /// **'Modifica salvata'**
  String get adminSaved;

  /// No description provided for @adminSystemPrompt.
  ///
  /// In it, this message translates to:
  /// **'System prompt'**
  String get adminSystemPrompt;

  /// No description provided for @adminUserTemplate.
  ///
  /// In it, this message translates to:
  /// **'Template utente'**
  String get adminUserTemplate;

  /// No description provided for @adminToolSchema.
  ///
  /// In it, this message translates to:
  /// **'Schema dello strumento (JSON)'**
  String get adminToolSchema;

  /// No description provided for @adminNotes.
  ///
  /// In it, this message translates to:
  /// **'Note'**
  String get adminNotes;

  /// No description provided for @adminAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get adminAll;

  /// No description provided for @adminRecentCalls.
  ///
  /// In it, this message translates to:
  /// **'Chiamate recenti'**
  String get adminRecentCalls;

  /// No description provided for @adminDay.
  ///
  /// In it, this message translates to:
  /// **'Giorno'**
  String get adminDay;

  /// No description provided for @adminCalls.
  ///
  /// In it, this message translates to:
  /// **'Chiamate'**
  String get adminCalls;

  /// No description provided for @adminOk.
  ///
  /// In it, this message translates to:
  /// **'OK'**
  String get adminOk;

  /// No description provided for @adminErrors.
  ///
  /// In it, this message translates to:
  /// **'Errori'**
  String get adminErrors;

  /// No description provided for @adminCache.
  ///
  /// In it, this message translates to:
  /// **'Cache'**
  String get adminCache;

  /// No description provided for @adminTokensIn.
  ///
  /// In it, this message translates to:
  /// **'Token in'**
  String get adminTokensIn;

  /// No description provided for @adminTokensCache.
  ///
  /// In it, this message translates to:
  /// **'Token cache'**
  String get adminTokensCache;

  /// No description provided for @adminTokensOut.
  ///
  /// In it, this message translates to:
  /// **'Token out'**
  String get adminTokensOut;

  /// No description provided for @adminCostUsd.
  ///
  /// In it, this message translates to:
  /// **'Costo in dollari'**
  String get adminCostUsd;

  /// No description provided for @adminLatencyAvg.
  ///
  /// In it, this message translates to:
  /// **'Latenza media'**
  String get adminLatencyAvg;

  /// No description provided for @adminLatencyP95.
  ///
  /// In it, this message translates to:
  /// **'Latenza p95'**
  String get adminLatencyP95;

  /// No description provided for @adminType.
  ///
  /// In it, this message translates to:
  /// **'Tipo'**
  String get adminType;

  /// No description provided for @adminAction.
  ///
  /// In it, this message translates to:
  /// **'Azione'**
  String get adminAction;

  /// No description provided for @adminActorUuid.
  ///
  /// In it, this message translates to:
  /// **'Attore (UUID)'**
  String get adminActorUuid;

  /// No description provided for @adminDetails.
  ///
  /// In it, this message translates to:
  /// **'Dettagli'**
  String get adminDetails;

  /// No description provided for @adminDefinition.
  ///
  /// In it, this message translates to:
  /// **'Definizione'**
  String get adminDefinition;

  /// No description provided for @adminRuleStatusConfirm.
  ///
  /// In it, this message translates to:
  /// **'Confermare il cambio di stato della regola?'**
  String get adminRuleStatusConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
