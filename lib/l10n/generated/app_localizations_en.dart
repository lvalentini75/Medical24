// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get healthExportCsv => 'Export CSV';

  @override
  String get healthExportError => 'Unable to export values.';

  @override
  String get appTitle => 'Medical 24';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonErrorTitle => 'Something went wrong';

  @override
  String get commonEmptyTitle => 'Nothing here yet';

  @override
  String get commonRequired => 'Required field';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonAdd => 'Add';

  @override
  String get addUploadReport => 'Upload a report';

  @override
  String get addManualValue => 'Enter a value';

  @override
  String get breadcrumbLabel => 'Breadcrumb';

  @override
  String get disclaimerClinical =>
      'Values are read from the report and compared with reference ranges: this is not a diagnosis; talk to your doctor.';

  @override
  String get authWelcomeTitle => 'Your health, in order';

  @override
  String get authWelcomeSubtitle =>
      'Collect your health documents, understand your values and share them with your doctor.';

  @override
  String get authWelcomeSignIn => 'Sign in';

  @override
  String get authWelcomeSignUp => 'Create an account';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authSignUpTitle => 'Create an account';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => 'At least 8 characters';

  @override
  String get authEmailInvalid => 'Enter a valid email address';

  @override
  String get authPasswordShort => 'Password must be at least 8 characters';

  @override
  String get authSignInAction => 'Sign in';

  @override
  String get authSignUpAction => 'Create account';

  @override
  String get authForgotPassword => 'Forgot your password?';

  @override
  String get authNoAccount => 'No account yet?';

  @override
  String get authHasAccount => 'Already have an account?';

  @override
  String get authOrDivider => 'or';

  @override
  String get authAppleAction => 'Continue with Apple';

  @override
  String get authGoogleAction => 'Continue with Google';

  @override
  String get authOtpAction => 'Sign in with an email code';

  @override
  String get authOtpTitle => 'Enter the code';

  @override
  String authOtpSubtitle(String email) {
    return 'We sent a 6-digit code to $email. It is valid for 10 minutes.';
  }

  @override
  String get authOtpLabel => '6-digit code';

  @override
  String get authOtpVerify => 'Verify';

  @override
  String get authOtpResend => 'Send again';

  @override
  String get authOtpSent => 'Code sent';

  @override
  String get authResetTitle => 'Reset your password';

  @override
  String get authResetSubtitle =>
      'We email you a code so you can set a new password.';

  @override
  String get authResetAction => 'Send the code';

  @override
  String get authNewPasswordLabel => 'New password';

  @override
  String get authResetDone => 'Password updated';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authPrivacyNote =>
      'Health data is handled as a special category (GDPR art. 9) and stays in Europe.';

  @override
  String get authDevShortcutsTitle => 'Quick access (development)';

  @override
  String get authDevShortcutAdmin => 'Administrator';

  @override
  String get authDevShortcutAlice => 'Alice';

  @override
  String get authDevShortcutBob => 'Bob';

  @override
  String get onboardingConsentTitle => 'Your consents';

  @override
  String get onboardingConsentSubtitle =>
      'Separate, and revocable at any time from settings.';

  @override
  String get onboardingConsentHealth => 'Processing of health data';

  @override
  String get onboardingConsentHealthBody =>
      'Explicit consent (GDPR art. 9.2.a) to process health data to deliver the service. Without it the app cannot work.';

  @override
  String get onboardingConsentAi => 'AI processing of documents';

  @override
  String get onboardingConsentAiBody =>
      'Documents are read by an AI model to extract values. Without it the archive works, the analysis does not.';

  @override
  String get onboardingConsentMarketing => 'Updates and marketing';

  @override
  String get onboardingConsentMarketingBody =>
      'Product news and prevention content. Optional, never bundled.';

  @override
  String get onboardingConsentRequired => 'Required';

  @override
  String get onboardingConsentMissing =>
      'Consent to health data processing is required to continue.';

  @override
  String get onboardingBasicsTitle => 'Basic details';

  @override
  String get onboardingBasicsSubtitle =>
      'Needed to use the right reference ranges for age and gender.';

  @override
  String get onboardingNameLabel => 'Full name';

  @override
  String get onboardingBirthDateLabel => 'Date of birth';

  @override
  String get onboardingBirthDatePick => 'Pick a date';

  @override
  String get onboardingGenderLabel => 'Gender';

  @override
  String get onboardingGenderFemale => 'Female';

  @override
  String get onboardingGenderMale => 'Male';

  @override
  String get onboardingGenderOther => 'Other';

  @override
  String get onboardingGenderUndisclosed => 'Prefer not to say';

  @override
  String get onboardingLanguageLabel => 'Language';

  @override
  String get onboardingUnitsLabel => 'Units';

  @override
  String get onboardingCountryLabel => 'Country';

  @override
  String get onboardingReadyTitle => 'Profile ready';

  @override
  String get onboardingReadySubtitle =>
      'From here you can upload your first document and see your health status.';

  @override
  String get onboardingReadyAction => 'Enter Medical 24';

  @override
  String onboardingStepLabel(String current, String total) {
    return 'Step $current of $total';
  }

  @override
  String get navHome => 'Home';

  @override
  String get navHealth => 'Health';

  @override
  String get navArchive => 'Archive';

  @override
  String get navTreatments => 'Treatments';

  @override
  String get navDoctor => 'Doctor';

  @override
  String get navMyDoctor => 'My doctor';

  @override
  String get navSettings => 'Settings';

  @override
  String get navOverview => 'Overview';

  @override
  String get navMyHealth => 'My health';

  @override
  String get navHealthSpace => 'My health space';

  @override
  String get navHelp => 'Help';

  @override
  String get navProfile => 'Profile';

  @override
  String get disclaimerPhone => 'Information to discuss with your doctor.';

  @override
  String get disclaimerDesktop =>
      'This information does not replace medical advice.';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get homeGreetingNoName => 'Hello';

  @override
  String get homeSubtitle => 'Here is where your health stands.';

  @override
  String get homeProfileCardTitle => 'Your profile';

  @override
  String homeProfileCompletion(String percent) {
    return 'Profile $percent% complete';
  }

  @override
  String get homeNextStepTitle => 'Next step';

  @override
  String get homeNextStepBody =>
      'The document archive arrives with the next release.';

  @override
  String get healthTitle => 'Health';

  @override
  String get healthEmptyBody =>
      'Health status, measurements and value history arrive with the next module.';

  @override
  String get healthValuesTitle => 'My values';

  @override
  String get healthValuesSearch => 'Search a biomarker';

  @override
  String get healthValuesFavorites => 'Favorites';

  @override
  String get healthValuesEssentials => 'Essential';

  @override
  String get healthValuesAll => 'All';

  @override
  String get healthValuesOnlyWithValues => 'Only with values';

  @override
  String get healthValuesError => 'We could not load your values.';

  @override
  String get healthValuesEmptyTitle => 'No values to show';

  @override
  String get healthValuesEmptyBody =>
      'Values come from reports you upload, or you can enter them manually.';

  @override
  String get healthValuesUploadReport => 'Upload a report';

  @override
  String get healthValuesManual => 'Enter manually';

  @override
  String get healthValuesNoValue => 'No value';

  @override
  String healthValuesCount(String count) {
    return '$count values';
  }

  @override
  String get healthValuesTrack => '+ Track';

  @override
  String get healthValuesTracked => 'Tracked';

  @override
  String get healthValuesFavorite => 'Add to favorites';

  @override
  String get healthValuesUnfavorite => 'Remove from favorites';

  @override
  String get healthSelectValueTitle => 'Choose a biomarker';

  @override
  String get healthSelectValueBody =>
      'Select a value from the list to see its complete history.';

  @override
  String get healthPeriodAll => 'All';

  @override
  String get healthPeriodYear => '12 months';

  @override
  String get healthPeriod90 => '90 days';

  @override
  String get healthPeriod30 => '30 days';

  @override
  String get healthCompareWith => 'Compare with…';

  @override
  String get healthCompareRemove => 'Remove comparison';

  @override
  String get healthChartNormalized => 'Series normalized to 0–100';

  @override
  String get healthChartSemantics => 'Value history chart';

  @override
  String get healthHistoryNoPoints => 'No values in the selected period.';

  @override
  String get healthStatsMinimum => 'Minimum';

  @override
  String get healthStatsMaximum => 'Maximum';

  @override
  String get healthStatsAverage => 'Average';

  @override
  String get healthStatsLatest => 'Latest';

  @override
  String get healthStatsChange => 'Change';

  @override
  String get healthStatsCount => 'Values';

  @override
  String get healthEpisodesTitle => 'Out-of-range episodes';

  @override
  String get healthEpisodesEmpty => 'No out-of-range episodes.';

  @override
  String get healthEpisodeOngoing => 'ongoing';

  @override
  String healthEpisodeCount(String count) {
    return '$count values';
  }

  @override
  String get healthTableTitle => 'All values';

  @override
  String get healthTableDate => 'Date';

  @override
  String get healthTableValue => 'Value and unit';

  @override
  String get healthTableStatus => 'Status';

  @override
  String get healthTableOrigin => 'Origin';

  @override
  String get healthOrigin_document => 'Report';

  @override
  String get healthOrigin_manual => 'Manual';

  @override
  String get healthOrigin_device => 'Device';

  @override
  String get healthManualTitle => 'Enter a value';

  @override
  String get healthManualParameter => 'Measurement';

  @override
  String get healthManualPressure => 'Blood pressure';

  @override
  String get healthManualValue => 'Value';

  @override
  String get healthManualSystolic => 'Systolic pressure';

  @override
  String get healthManualDiastolic => 'Diastolic pressure';

  @override
  String get healthManualUnit => 'Unit';

  @override
  String get healthManualNumberRequired => 'Enter a valid number.';

  @override
  String healthManualPlausibleRange(String min, String max, String unit) {
    return 'Enter a plausible value between $min and $max $unit.';
  }

  @override
  String get healthManualSaved => 'Value saved.';

  @override
  String get healthManualError_manual_value_not_plausible =>
      'The value is outside the plausible range.';

  @override
  String get healthManualError_manual_unit_not_supported =>
      'This unit is not supported for the measurement.';

  @override
  String get healthManualError_manual_code_not_allowed =>
      'This measurement cannot be entered manually.';

  @override
  String get healthManualError_not_allowed =>
      'You do not have permission to enter this value.';

  @override
  String get healthManualError_unknown =>
      'We could not save the value. Try again.';

  @override
  String get archiveTitle => 'Archive';

  @override
  String get archiveEmptyBody =>
      'Your health documents will live here, with categories and search.';

  @override
  String get treatmentsTitle => 'Treatments';

  @override
  String get treatmentsEmptyBody =>
      'The treatment database arrives with its own module.';

  @override
  String get doctorTitle => 'Doctor';

  @override
  String get doctorEmptyBody =>
      'Dossier, questions to your doctor and secure sharing come later.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsProfileSection => 'Profile';

  @override
  String get settingsPreferencesSection => 'Preferences';

  @override
  String get settingsSecuritySection => 'Security';

  @override
  String get settingsPrivacySection => 'Privacy';

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsEditProfile => 'Edit profile';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsUnits => 'Units';

  @override
  String get settingsBiometricLock => 'Biometric lock';

  @override
  String get settingsBiometricLockBody =>
      'Ask for Face ID, fingerprint or PIN when the app opens.';

  @override
  String get settingsBiometricUnavailable =>
      'This device does not support biometric lock.';

  @override
  String get settingsPinFallback => 'Fallback PIN';

  @override
  String get settingsPinSet => 'Set the PIN';

  @override
  String get settingsPinLabel => '6-digit PIN';

  @override
  String get settingsPinSaved => 'PIN saved';

  @override
  String get settingsExportData => 'Export my data';

  @override
  String get settingsExportBody =>
      'Get your profile, consents and access log in a readable format.';

  @override
  String get settingsExportDone => 'Export ready';

  @override
  String get settingsConsents => 'Consent log';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteBody =>
      'Access closes immediately and data is permanently removed within 30 days.';

  @override
  String get settingsDeleteConfirmTitle => 'Delete your account?';

  @override
  String get settingsDeleteConfirmBody =>
      'Access closes right away. Data is permanently removed within 30 days. This cannot be undone.';

  @override
  String get settingsDeleteConfirmAction => 'Delete permanently';

  @override
  String get settingsAppVersion => 'App version';

  @override
  String get consentsLogTitle => 'Consent log';

  @override
  String get consentsLogEmpty => 'No consent recorded yet.';

  @override
  String get consentGranted => 'Granted';

  @override
  String get consentRevoked => 'Revoked';

  @override
  String get lockTitle => 'Medical 24 is locked';

  @override
  String get lockSubtitle => 'Unlock to see your data.';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get lockUsePin => 'Use the PIN';

  @override
  String get lockPinWrong => 'Wrong PIN';

  @override
  String get archiveSearchHint => 'Search documents';

  @override
  String get archiveClearSearch => 'Clear search';

  @override
  String get archiveSortLabel => 'Sort by';

  @override
  String get archiveSort_dateDesc => 'Date, newest first';

  @override
  String get archiveSort_dateAsc => 'Date, oldest first';

  @override
  String get archiveSort_category => 'Category';

  @override
  String get archiveSort_doctor => 'Doctor';

  @override
  String get archiveSort_facility => 'Facility';

  @override
  String get archiveCategories => 'Categories';

  @override
  String get archiveResetFilters => 'Reset filters';

  @override
  String get archiveCategory_exams => 'Tests';

  @override
  String get archiveCategory_reports => 'Reports';

  @override
  String get archiveCategory_prescriptions => 'Prescriptions';

  @override
  String get archiveCategory_radiology => 'Radiology';

  @override
  String get archiveCategory_vaccinations => 'Vaccinations';

  @override
  String get archiveCategory_invoices => 'Invoices';

  @override
  String get archiveCategory_consents => 'Consents';

  @override
  String get archiveCategory_cards => 'Cards';

  @override
  String get archiveCategory_other => 'Other';

  @override
  String get archiveStatus_uploading => 'Uploaded';

  @override
  String get archiveStatus_uploaded => 'Uploaded';

  @override
  String get archiveStatus_processing => 'Analyzing';

  @override
  String get archiveStatus_analyzed => 'Analyzed';

  @override
  String get archiveStatus_needs_review => 'Needs review';

  @override
  String get archiveStatus_failed => 'Error';

  @override
  String get archiveGroupYear => 'Year';

  @override
  String get archiveGroupEpisode => 'Episode';

  @override
  String get archiveGroupMonth => 'Month';

  @override
  String get archiveDateUnknown => 'Date unavailable';

  @override
  String get archiveNoEpisode => 'No episode';

  @override
  String archiveOpenDocument(String title) {
    return 'Open $title';
  }

  @override
  String get archiveAddAction => 'Add document';

  @override
  String get archiveAddTitle => 'Add document';

  @override
  String get archiveEmptySuggestion => 'Photograph your latest report.';

  @override
  String get archiveNoResults => 'No documents match these filters.';

  @override
  String get archiveSelectDocument => 'Select a document to see its details.';

  @override
  String archiveDocumentCount(String count) {
    return '$count documents';
  }

  @override
  String get archiveDocumentDetail => 'Document';

  @override
  String get archiveDocumentMissing => 'This document is no longer available.';

  @override
  String get archiveEditMetadata => 'Edit details';

  @override
  String get archiveShareDocument => 'Share original';

  @override
  String get archiveDownloadReady => 'Original saved securely.';

  @override
  String get archiveDeleteTitle => 'Delete document?';

  @override
  String get archiveDeleteBody =>
      'The document will be removed from your archive.';

  @override
  String get archiveDeleteAction => 'Delete';

  @override
  String get archiveDocumentDate => 'Document date';

  @override
  String get archiveDoctor => 'Doctor';

  @override
  String get archiveFacility => 'Facility';

  @override
  String get archiveEpisode => 'Episode';

  @override
  String get archiveTags => 'Tags';

  @override
  String get archiveTagsHint => 'Tags, separated by commas';

  @override
  String get archiveNotes => 'Notes';

  @override
  String get archiveTitleField => 'Title';

  @override
  String get archiveCategoryField => 'Category';

  @override
  String archivePageLabel(String current, String total) {
    return 'Page $current of $total';
  }

  @override
  String get archiveSourceCamera => 'Camera';

  @override
  String get archiveSourceGallery => 'Gallery';

  @override
  String get archiveSourceFile => 'File or PDF';

  @override
  String get archiveSourceShare => 'Share sheet';

  @override
  String get archiveChooseSource => 'Choose where to add the document from.';

  @override
  String get archivePagesPreview => 'Page preview';

  @override
  String get archiveRotatePage => 'Rotate page';

  @override
  String get archiveDeletePage => 'Delete page';

  @override
  String get archiveUploadAction => 'Upload';

  @override
  String archiveUploadProgress(String current, String total) {
    return '$current of $total pages completed';
  }

  @override
  String get archiveDuplicateTitle => 'This may already be in your archive';

  @override
  String get archiveDuplicateBody => 'You can open the original or keep both.';

  @override
  String get archiveOpenOriginal => 'Open original';

  @override
  String get archiveKeepBoth => 'Keep both';

  @override
  String get archiveDefaultFileName => 'document';

  @override
  String archiveUsageCounter(String used, String max) {
    return '$used of $max documents';
  }

  @override
  String get archiveUsageLoading => 'Counting documents…';

  @override
  String get archiveLimitReachedTitle => 'You have reached your plan limit';

  @override
  String archiveLimitReachedBody(String max) {
    return 'Your plan includes $max documents. Delete one or change plan from Settings.';
  }

  @override
  String get archiveOpenSettings => 'Go to Settings';

  @override
  String get archiveDuplicateBadge => 'Possible duplicate';

  @override
  String get archiveDuplicateDismiss => 'Keep both';

  @override
  String get archiveCropPage => 'Crop page';

  @override
  String get archiveCropConfirm => 'Apply crop';

  @override
  String get archiveReorderHint => 'Drag the pages to change their order.';

  @override
  String get archiveMultiPageTitle => 'Document pages';

  @override
  String archivePagesCount(String count) {
    return '$count pages';
  }

  @override
  String get archiveDropHere => 'Drop PDFs or images here';

  @override
  String get archiveDropActive => 'Release to add';

  @override
  String get archiveShareReady => 'Original ready to share.';

  @override
  String get archiveSharePdfNote => 'Photos become a single PDF.';

  @override
  String get analysisTitle => 'Report analysis';

  @override
  String get analysisViewAction => 'View analysis';

  @override
  String get analysisStartAction => 'Analyse the document';

  @override
  String get analysisUpdateAction => 'Update';

  @override
  String get analysisRetryAction => 'Try reading again';

  @override
  String get analysisStatus_queued => 'Queued';

  @override
  String get analysisStatus_classifying => 'Recognising the document';

  @override
  String get analysisStatus_extracting => 'Reading the values';

  @override
  String get analysisStatus_normalizing => 'Converting the units';

  @override
  String get analysisStatus_done => 'Reading completed';

  @override
  String get analysisStatus_needs_review => 'Values to check';

  @override
  String get analysisStatus_failed => 'Reading failed';

  @override
  String get analysisStatusSkipped => 'Document not processed';

  @override
  String get analysisStatusNoValues => 'No values recognised';

  @override
  String get analysisSkippedNotLabBody =>
      'This does not appear to be a laboratory report: there are no values to extract';

  @override
  String get analysisReadAnywayAction => 'Read anyway';

  @override
  String get analysisNoValuesBody => 'No values were recognised on these pages';

  @override
  String get analysisNoValuesAdvice =>
      'Try again with sharp, straight photos that show all the text.';

  @override
  String get analysisEmptyTitle => 'No value read';

  @override
  String get analysisEmptyBody =>
      'This document contains no recognisable laboratory values.';

  @override
  String get analysisNotStartedTitle => 'Document not analysed yet';

  @override
  String get analysisNotStartedBody =>
      'Start the reading to turn the report into values.';

  @override
  String analysisValuesCount(String count) {
    return '$count values';
  }

  @override
  String analysisValuesSaved(String saved) {
    return '$saved values saved';
  }

  @override
  String analysisToReviewCount(String count) {
    return '$count to check';
  }

  @override
  String get analysisReviewTitle => 'Values to check';

  @override
  String get analysisReviewBody =>
      'Please check these values: the reading was not confident enough.';

  @override
  String get analysisConfirmAction => 'Confirm the value';

  @override
  String get analysisCorrectAction => 'Correct';

  @override
  String get analysisCorrectTitle => 'Correct the value';

  @override
  String get analysisValueField => 'Value';

  @override
  String get analysisUnitField => 'Unit';

  @override
  String get analysisDateField => 'Collection date';

  @override
  String analysisReadAs(String value) {
    return 'Read as $value';
  }

  @override
  String analysisConfidence(String percent) {
    return 'Reading confidence $percent%';
  }

  @override
  String get analysisLabRange => 'Laboratory range';

  @override
  String get analysisBoardRange => 'Institutional reference';

  @override
  String get analysisDoctorRange => 'Doctor threshold';

  @override
  String get analysisRangeMissing => 'Not available';

  @override
  String get analysisFlag_below => 'Below the range';

  @override
  String get analysisFlag_within => 'Within the range';

  @override
  String get analysisFlag_above => 'Above the range';

  @override
  String get analysisFlag_critical_low => 'Far below the range';

  @override
  String get analysisFlag_critical_high => 'Far above the range';

  @override
  String get analysisFlag_unknown => 'To be assessed';

  @override
  String get analysisCatalogDraftNotice =>
      'Commonly used ranges, not validated by the scientific board yet.';

  @override
  String get analysisLabName => 'Laboratory';

  @override
  String analysisUsageCounter(String used, String max) {
    return '$used of $max readings this month';
  }

  @override
  String get analysisLimitReachedTitle =>
      'You reached this month\'s reading limit';

  @override
  String analysisLimitReachedBody(String max) {
    return 'Your plan includes $max readings per month. Try again next month or change plan from Settings.';
  }

  @override
  String get analysisFailedTitle => 'We could not read the document';

  @override
  String get analysisFailedBody =>
      'Check that the pages are readable and try again.';

  @override
  String get analysisFailureApi =>
      'The reading service is temporarily unavailable. Please try again shortly.';

  @override
  String get analysisFailureStorage =>
      'We could not open the saved document. Check the file and try again.';

  @override
  String get analysisFailurePdfParse =>
      'We could not read this PDF. Upload it again or use clear photos of the pages.';

  @override
  String get analysisFailureNetwork =>
      'The connection to the reading service was interrupted. Please try again shortly.';

  @override
  String get analysisFailureInvalidOutput =>
      'The reading did not produce usable values. Try again with clearer pages.';

  @override
  String get analysisFailureMissingApiKey =>
      'The reading service is not configured. Contact support.';

  @override
  String get analysisHistoryTitle => 'Value history';

  @override
  String get analysisHistoryEmpty => 'There is no history for this value yet.';

  @override
  String get analysisCatalogTitle => 'Biomarkers';

  @override
  String get analysisCatalogSearch => 'Search a biomarker';

  @override
  String get analysisCatalogEmpty => 'No biomarker matches your search.';

  @override
  String get archiveFilterNeedsReview => 'Needs review';

  @override
  String analysisReviewBadge(String count) {
    return 'Needs review: $count';
  }

  @override
  String get analysisReadingProgress => 'Reading progress';

  @override
  String get analysisUsuallyUnderMinute => 'Usually less than a minute.';

  @override
  String analysisCompletedAt(String date) {
    return 'Analysed on $date';
  }

  @override
  String get analysisVerifyAction => 'Review';

  @override
  String get analysisUnknownTitle => 'Not yet in the catalog';

  @override
  String get analysisValueColumn => 'Value';

  @override
  String analysisOriginalUnit(String unit) {
    return 'On the report: $unit';
  }

  @override
  String get analysisReviewComplete => 'All values have been reviewed.';

  @override
  String get analysisOutcomeColumn => 'Outcome';

  @override
  String get analysisActionsColumn => 'Actions';

  @override
  String get analysisApproveAction => 'Approve';

  @override
  String get analysisReviewConfirmed => 'Confirmed';

  @override
  String get analysisReviewNeeded => 'Needs review';

  @override
  String get analysisReviewPending => 'Pending';

  @override
  String get analysisReviewDiscarded => 'Discarded';

  @override
  String get analysisConfirmedByEngine => 'by the engine';

  @override
  String get analysisConfirmedByYou => 'by you';

  @override
  String get analysisShowDiscarded => 'Show discarded';

  @override
  String get analysisDiscardConfirmTitle => 'Discard this value?';

  @override
  String get analysisDiscardConfirmBody =>
      'It will not be used for organs, risks, or explanations.';

  @override
  String analysisConfirmAll(String count) {
    return 'Confirm all pending values ($count)';
  }

  @override
  String analysisConfirmAllProgress(String current, String total) {
    return '$current of $total values processed';
  }

  @override
  String analysisConfirmAllResult(String confirmed, String errors) {
    return '$confirmed confirmed, $errors errors';
  }

  @override
  String analysisReviewSummary(String confirmed, String pending) {
    return '$confirmed values confirmed · $pending to review';
  }

  @override
  String analysisVerifyValuesAction(String count) {
    return 'Review values ($count)';
  }

  @override
  String get analysisFlagShort_below => 'Below';

  @override
  String get analysisFlagShort_within => 'Within range';

  @override
  String get analysisFlagShort_above => 'Above';

  @override
  String get analysisFlagShort_critical_low => 'Far below';

  @override
  String get analysisFlagShort_critical_high => 'Far above';

  @override
  String get analysisFlagShort_unknown => 'To assess';

  @override
  String get analysisDiscardAction => 'Discard';

  @override
  String get analysisDiscardUnavailable =>
      'Discard is not supported by the repository yet.';

  @override
  String get analysisSourceUnavailable =>
      'Page and crop are unavailable for this value.';

  @override
  String get analysisKeyboardHelp => 'Keyboard: Enter confirms, C corrects.';

  @override
  String get addSymptom => 'Log a symptom';

  @override
  String get symptomsTitle => 'Symptom diary';

  @override
  String get symptomsSubtitle => 'Record how you feel over time.';

  @override
  String get symptomsNew => 'Log a symptom';

  @override
  String get symptomsEdit => 'Symptom details';

  @override
  String get symptomsEmptyTitle => 'No symptoms logged';

  @override
  String get symptomsEmptyBody =>
      'You can record a symptom, its severity and when it started.';

  @override
  String get symptomsType => 'Symptom';

  @override
  String get symptomsFreeText => 'Describe the symptom';

  @override
  String get symptomsSeverity => 'Severity';

  @override
  String get symptomsNotes => 'Notes';

  @override
  String get symptomsReadOnly =>
      'After 24 hours this entry can no longer be edited or deleted.';

  @override
  String get symptomsDelete => 'Delete';

  @override
  String get symptomsDeleteTitle => 'Delete this symptom?';

  @override
  String get symptomsDeleteBody => 'The entry will be removed from the diary.';

  @override
  String get symptomsLoadError => 'We could not load this symptom.';

  @override
  String get symptomsSaveError => 'We could not save this symptom.';

  @override
  String get symptomsMissing => 'This entry is no longer available.';

  @override
  String get symptom_headache => 'Headache';

  @override
  String get symptom_nausea => 'Nausea';

  @override
  String get symptom_fatigue => 'Fatigue';

  @override
  String get symptom_dizziness => 'Dizziness';

  @override
  String get symptom_chest_pain => 'Chest pain';

  @override
  String get symptom_shortness_of_breath => 'Shortness of breath';

  @override
  String get symptom_fever => 'Fever';

  @override
  String get symptom_cough => 'Cough';

  @override
  String get symptom_abdominal_pain => 'Abdominal pain';

  @override
  String get symptom_joint_pain => 'Joint pain';

  @override
  String get symptom_back_pain => 'Back pain';

  @override
  String get symptom_insomnia => 'Insomnia';

  @override
  String get symptom_anxiety => 'Anxiety';

  @override
  String get symptom_palpitations => 'Palpitations';

  @override
  String get symptom_rash => 'Rash';

  @override
  String get symptom_swelling => 'Swelling';

  @override
  String get symptom_diarrhea => 'Diarrhea';

  @override
  String get symptom_constipation => 'Constipation';

  @override
  String get symptom_loss_of_appetite => 'Loss of appetite';

  @override
  String get symptom_other => 'Other';

  @override
  String get alertsTitle => 'Alert center';

  @override
  String get alertsSubtitle => 'Alerts generated by versioned clinical rules.';

  @override
  String get alertsMarkAllRead => 'Mark all as read';

  @override
  String get alertsEmptyTitle => 'No alerts';

  @override
  String get alertsEmptyBody => 'There are no alerts to read.';

  @override
  String get alertsContactDoctor => 'Contact your doctor';

  @override
  String get alertsLevel_lab => 'Laboratory';

  @override
  String get alertsLevel_institutional => 'Institutional';

  @override
  String get alertsLevel_doctor => 'Doctor';

  @override
  String get alertBiomarkerCriticalLow =>
      'The biomarker is far below the reference range.';

  @override
  String get alertBiomarkerCriticalHigh =>
      'The biomarker is far above the reference range.';

  @override
  String get alertBiomarkerBelowInstitutional =>
      'The biomarker is below the institutional reference.';

  @override
  String get alertBiomarkerAboveInstitutional =>
      'The biomarker is above the institutional reference.';

  @override
  String get homeHealthStatusTitle => 'Health status';

  @override
  String get homeHealthStatusPreparing =>
      'In preparation: the score is coming with the board rules';

  @override
  String get homeLatestValues => 'Latest values';

  @override
  String get homeNoValues => 'No values available.';

  @override
  String get homeAlerts => 'Alerts';

  @override
  String get homeToReview => 'To review';

  @override
  String get homeNothingToReview => 'No documents to review.';

  @override
  String get homeLatestDocument => 'Latest document';

  @override
  String get homeNoDocuments => 'No documents available.';

  @override
  String get homeEmptyTitle => 'Start with your first report';

  @override
  String get homeEmptyBody =>
      'Upload a report to collect values and build your history.';

  @override
  String get homeUploadFirstReport => 'Upload your first report';

  @override
  String get homeHealthSpace => 'Your health space';

  @override
  String get homeUpload => 'Upload';

  @override
  String get homeUploadReport => 'Upload report';

  @override
  String homeGreetingMorning(String name) {
    return 'Good morning, $name.';
  }

  @override
  String homeGreetingAfternoon(String name) {
    return 'Good afternoon, $name.';
  }

  @override
  String homeGreetingEvening(String name) {
    return 'Good evening, $name.';
  }

  @override
  String get homeGreetingDesktopNoName => 'Good morning.';

  @override
  String homeUpdatedAt(String date) {
    return 'Updated $date';
  }

  @override
  String get homeYourHealth => 'Your health';

  @override
  String get homeYourDoctor => 'Your doctor';

  @override
  String get homeOpenOverview => 'Open overview';

  @override
  String homeLatestReportDate(String date) {
    return 'Latest report: $date';
  }

  @override
  String homeReviewValues(String count) {
    return '$count values to review';
  }

  @override
  String homeFromReport(String date) {
    return 'From the report dated $date';
  }

  @override
  String get homeHealthStatusPreparingShort => 'In preparation';

  @override
  String get homeRecentDocuments => 'Recent documents';

  @override
  String get homeAllDocuments => 'All documents';

  @override
  String homeAllDocumentsCount(String count) {
    return 'All $count documents';
  }

  @override
  String get homeStatDocuments => 'Documents';

  @override
  String get homeStatTracked => 'Tracked values';

  @override
  String get homeStatReview => 'Values to review';

  @override
  String get homeStatAlerts => 'Unread alerts';

  @override
  String get homeValuesOverTime => 'Values over time';

  @override
  String get homeOpenHistory => 'Open history';

  @override
  String get homePrevious => 'Previous';

  @override
  String get homeConfirmedValues => 'Latest confirmed values';

  @override
  String get homeConfirmed => 'Confirmed';

  @override
  String get homeTasks => 'To do';

  @override
  String homeUnreadAlerts(String count) {
    return '$count unread alerts';
  }

  @override
  String get homeOpenAlertCenter => 'Open alert center';

  @override
  String get homeTableDocument => 'Document';

  @override
  String get homeTableDate => 'Date';

  @override
  String get homeTableStatus => 'Status';

  @override
  String get homeTableParameter => 'Measurement';

  @override
  String get homeTableVerification => 'Review';

  @override
  String get healthPeriod6Months => '6 months';

  @override
  String archiveDesktopSubtitle(String count) {
    return '$count documents · List, original and analysis';
  }

  @override
  String get archiveUploadDocument => 'Upload document';

  @override
  String get archiveUploadShort => 'Upload';

  @override
  String get archiveAll => 'All';

  @override
  String get archiveYear => 'Year';

  @override
  String get archiveAllYears => 'All years';

  @override
  String get archiveFilters => 'Filters';

  @override
  String get archiveAllCategories => 'All categories';

  @override
  String get archiveExtractedData => 'Extracted data';

  @override
  String get archiveOriginal => 'Original';

  @override
  String get archivePreviousPage => 'Previous page';

  @override
  String get archiveNextPage => 'Next page';

  @override
  String get archiveOpenFullscreen => 'Open full screen';

  @override
  String get healthConfirmed => 'Confirmed';

  @override
  String get healthSourceReferences => 'Source and references';

  @override
  String get healthUpdatedUnavailable => 'No update available';

  @override
  String healthUpdatedAt(String date) {
    return 'Overview updated $date';
  }

  @override
  String get healthTabAllValues => 'All values';

  @override
  String get healthTabHistory => 'History';

  @override
  String get healthSegmentValues => 'Values';

  @override
  String get healthSegmentSymptoms => 'Symptoms';

  @override
  String get healthSegmentAlerts => 'Alerts';

  @override
  String get healthMeasurementHistory => 'Measurement history';

  @override
  String get healthTableDocument => 'Document';

  @override
  String get healthOpenReport => 'Open report';

  @override
  String get healthSelectedValue => 'Selected value';

  @override
  String get healthExtractionConfirmed => 'Extraction confirmed';

  @override
  String get healthSource => 'Source';

  @override
  String get healthNotSet => 'Not set';

  @override
  String get healthOtherConfirmed => 'Other confirmed values';

  @override
  String get healthValuesTrackTooltip => 'Track this value';

  @override
  String get healthManualSubtitle => 'Add a measurement you took yourself.';

  @override
  String get healthManualFormTitle => 'Measurement details';

  @override
  String get symptomsEditable => 'Editable';

  @override
  String get symptomsRecorded => 'Recorded';

  @override
  String get alertsUnread => 'Unread';

  @override
  String get alertsRead => 'Read';

  @override
  String get bodyTitle => 'Body and organs';

  @override
  String get bodySegment => 'Body';

  @override
  String get bodyDesktopSubtitle => 'Overview of body areas';

  @override
  String get bodySilhouetteSemantics => 'Map of body areas';

  @override
  String get bodyState_ok => 'Within range';

  @override
  String get bodyState_monitor => 'Keep an eye on';

  @override
  String get bodyState_attention => 'Attention';

  @override
  String get bodyState_missing => 'Missing data';

  @override
  String get bodyConfidenceComplete => 'Complete picture';

  @override
  String get bodyConfidencePartial => 'Partial picture';

  @override
  String get bodyConfidenceIncomplete => 'More data needed';

  @override
  String get bodyConfidenceMissing => 'Missing data';

  @override
  String get bodyAllAreas => 'All areas';

  @override
  String get bodyEmptyMessage =>
      'Upload a report or enter a value to see the overview.';

  @override
  String bodyUpdatedOn(Object date) {
    return 'Updated $date';
  }

  @override
  String get bodyRefresh => 'Refresh';

  @override
  String bodyRuleNote(Object version) {
    return 'The colour shows how far the area\'s values differ from the references; it is not a diagnosis. Rule v$version.';
  }

  @override
  String get bodyNotAvailable => 'n/a';

  @override
  String get bodyLoadError => 'We could not load the body overview.';

  @override
  String get bodyValuesError => 'We could not load the values for this area.';

  @override
  String get bodyAreaMissing => 'This area is unavailable.';

  @override
  String bodyCalculatedOn(Object date) {
    return 'Calculated $date';
  }

  @override
  String get bodyHistory => 'History';

  @override
  String get bodyAreaValues => 'Values in this area';

  @override
  String get bodyEssential => 'Essential';

  @override
  String get bodyNoMappedValues => 'No associated values';

  @override
  String get bodyNoPresentValues => 'No values available for this area.';

  @override
  String get bodyFullHistory => 'Full history';

  @override
  String get bodyHowToRead => 'How to read the overview';

  @override
  String get bodyToday => 'Today';

  @override
  String get bodySixMonthsAgo => '6 months ago';

  @override
  String get bodyTwelveMonthsAgo => '12 months ago';

  @override
  String get bodyTrendImproved => 'Improved';

  @override
  String get bodyTrendWorsened => 'Worsened';

  @override
  String get bodyTrendStable => 'Stable';

  @override
  String get bodyComparison => 'Comparison over time';

  @override
  String get bodyAttentionEpisodes => 'Attention episodes';

  @override
  String get bodyNoEpisodes => 'No attention episodes.';

  @override
  String bodyDurationDays(Object count) {
    return '$count days';
  }

  @override
  String get bodyStateTimeline => 'State timeline';

  @override
  String bodyValuesCount(Object count) {
    return '$count values';
  }

  @override
  String get bodyBiomarkerCharts => 'Biomarker chart';

  @override
  String get bodyHistoryEmpty =>
      'There are no calculations in the history yet.';

  @override
  String get bodyHistoryError => 'We could not load the area history.';

  @override
  String get bodyDeviationLabel => 'Deviation from references';

  @override
  String get bodyLegendNormal => 'Within range';

  @override
  String get bodyLegendAttention => 'Attention';

  @override
  String get bodyExplodedView => 'Exploded view';

  @override
  String get bodyGenderNotice =>
      'Add your gender to your profile for a complete overview';

  @override
  String get bodyOpenProfile => 'Open profile';

  @override
  String homeBodySummary(
      Object attention, Object missing, Object monitor, Object ok) {
    return '$ok areas within range · $monitor to monitor · $attention needing attention · $missing without data';
  }

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get preventionNav => 'Prevention';

  @override
  String get preventionTitle => 'Prevention';

  @override
  String get preventionSubtitle => 'Checks, due dates and history';

  @override
  String get preventionAddReminder => 'Add reminder';

  @override
  String get preventionComingSoon => 'Coming soon';

  @override
  String get preventionTabControls => 'My checks';

  @override
  String get preventionTabRisks => 'Risks and questionnaires';

  @override
  String get preventionTabHistory => 'History';

  @override
  String get preventionNextSteps => 'Next steps';

  @override
  String get preventionRegistered => 'Recorded checks';

  @override
  String get preventionNoRegistered => 'No recorded checks.';

  @override
  String get preventionNoUpcoming => 'No checks to schedule.';

  @override
  String get preventionStatusScheduled => 'Scheduled';

  @override
  String get preventionStatusPlan => 'To schedule';

  @override
  String get preventionStatusAgree => 'To agree';

  @override
  String get preventionStatusComplete => 'To complete';

  @override
  String get preventionPlanShort => 'SCHEDULE';

  @override
  String get preventionAgreeShort => 'AGREE';

  @override
  String get preventionExamDone => 'I completed the test';

  @override
  String get preventionIgnore => 'Dismiss';

  @override
  String get preventionIgnoreTitle => 'Dismiss this recommendation?';

  @override
  String get preventionIgnoreReason => 'Reason (optional)';

  @override
  String get preventionUploadDocument => 'Upload and link document';

  @override
  String get preventionDoneWithoutDocument => 'Mark done without a document';

  @override
  String get preventionInitialQuestionnaires => 'Initial questionnaires';

  @override
  String get preventionLinkExam => 'Link a new test';

  @override
  String get preventionDropZone =>
      'Upload the test document to keep it in the Archive and link it to this check.';

  @override
  String get preventionProfileTitle => 'Prevention profile';

  @override
  String get preventionAgeMissing => 'Add your age in your profile';

  @override
  String preventionAgeValue(int age) {
    return '$age years';
  }

  @override
  String get preventionLifestyleComplete =>
      'Lifestyle and family history completed';

  @override
  String get preventionLifestyleMissing =>
      'Lifestyle and family history to complete';

  @override
  String get preventionCompleteQuestionnaire => 'Complete questionnaire';

  @override
  String get preventionRisksQuestionnaires => 'Risks and questionnaires';

  @override
  String get preventionFamilyCardio => 'Heart and circulation';

  @override
  String get preventionFamilyDiabetes => 'Type 2 diabetes';

  @override
  String get preventionFamilyKidney => 'Kidneys';

  @override
  String get preventionFamilyFracture => 'Bones';

  @override
  String get preventionFractureRule => 'Fracture factors';

  @override
  String get preventionRiskLow => 'Low';

  @override
  String get preventionRiskMedium => 'Medium';

  @override
  String get preventionRiskHigh => 'High';

  @override
  String get preventionDataIncomplete => 'Data to complete';

  @override
  String get preventionMissingCardio =>
      'Blood pressure, total cholesterol, HDL, smoking response and age 40–69 are required.';

  @override
  String get preventionMissingQuestionnaire =>
      'Complete the initial questionnaire.';

  @override
  String get preventionMissingKidney =>
      'A recent creatinine value is required.';

  @override
  String get preventionCompleteData => 'Complete data';

  @override
  String preventionCalculatedOn(Object date) {
    return 'Calculated $date';
  }

  @override
  String preventionProjection(Object score) {
    return 'If nothing changes: $score';
  }

  @override
  String get preventionRuleDraft => 'Rule under validation';

  @override
  String get preventionWhy => 'Why';

  @override
  String get preventionOpenHistory => 'Open history';

  @override
  String preventionScorePercent(Object score) {
    return '$score% over 10 years';
  }

  @override
  String preventionScorePoints(Object score) {
    return '$score points';
  }

  @override
  String preventionScoreEgfr(Object score) {
    return '$score mL/min/1.73 m²';
  }

  @override
  String preventionScoreFactors(Object score) {
    return '$score factors';
  }

  @override
  String get preventionFactorAge => 'Age';

  @override
  String get preventionFactorSex => 'Sex';

  @override
  String get preventionNotAvailable => 'Not available';

  @override
  String get preventionFraxLink =>
      'Calculate FRAX on the official website: https://frax.shef.ac.uk/FRAX/';

  @override
  String get preventionFraxPrivacy => 'Medical 24 does not send any data.';

  @override
  String get preventionRiskDisclaimer =>
      'Statistical estimates from public algorithms, not diagnoses: discuss them with your doctor.';

  @override
  String get preventionHistoryTitle => 'Risk history';

  @override
  String get preventionHistoryRecommendations =>
      'Completed and dismissed checks';

  @override
  String get preventionRiskTimeline => 'Score timeline';

  @override
  String get preventionNoHistory => 'There is no history yet.';

  @override
  String get preventionReopen => 'Reopen';

  @override
  String get preventionLoadError => 'We could not load prevention.';

  @override
  String get preventionSaveError => 'We could not save your answers.';

  @override
  String get preventionRecommendationFallback => 'Prevention check';

  @override
  String get preventionQuestionnaireTitle => 'Prevention questionnaire';

  @override
  String get preventionQuestionnaireIntro =>
      'Your answers are used for prevention calculations and can be changed at any time.';

  @override
  String questionnaireStep(int step, String title) {
    return 'Step $step of 4 · $title';
  }

  @override
  String get questionnaireNext => 'Next';

  @override
  String get questionnaireSave => 'Save answers';

  @override
  String questionnaireMissing(String fields) {
    return 'Missing: $fields';
  }

  @override
  String get questionnaireSaved => 'Answers saved';

  @override
  String get questionnaireSavedWeightWarning =>
      'Answers saved. We could not add your weight to its history.';

  @override
  String questionnaireLastCompleted(String date) {
    return 'Last completed: $date';
  }

  @override
  String get questionnaireUpdate => 'Update';

  @override
  String get questionnaireSummary => 'Answer summary';

  @override
  String questionnaireSummaryMeasures(
      String height, String weight, String waist, String bmi) {
    return 'Height $height cm · Weight $weight kg · Waist $waist cm · BMI $bmi';
  }

  @override
  String get questionGroupLifestyle => 'Lifestyle';

  @override
  String get questionGroupFamily => 'Family and health history';

  @override
  String get questionGroupMeasures => 'Measurements';

  @override
  String get questionGroupBones => 'Bones';

  @override
  String get questionSmoker => 'Do you smoke?';

  @override
  String get questionPhysicalActivity =>
      'Do you exercise for at least 30 minutes daily?';

  @override
  String get questionFruitVegetables => 'Do you eat fruit or vegetables daily?';

  @override
  String get questionAlcohol =>
      'Do you drink at least 3 units of alcohol daily?';

  @override
  String get questionAntihypertensive =>
      'Do you take blood pressure medication?';

  @override
  String get questionHighGlucose => 'Have you had high blood glucose?';

  @override
  String get questionFamilyDiabetes => 'Family history of diabetes';

  @override
  String get questionFamilyNone => 'None';

  @override
  String get questionFamilySecond => 'Second-degree relative';

  @override
  String get questionFamilyFirst => 'First-degree relative';

  @override
  String get questionWaist => 'Waist circumference';

  @override
  String get questionHeight => 'Height';

  @override
  String get questionWeight => 'Weight';

  @override
  String questionWeightRecorded(String date) {
    return 'Latest weight recorded on $date; you can edit it.';
  }

  @override
  String get questionBmi => 'Body mass index';

  @override
  String get questionBmiUnavailable =>
      'BMI unavailable: height and a recent weight are required.';

  @override
  String questionBmiValue(Object value) {
    return 'BMI $value';
  }

  @override
  String get questionPreviousFracture => 'Have you had a previous fracture?';

  @override
  String get questionParentHipFracture => 'Has a parent had a hip fracture?';

  @override
  String get questionGlucocorticoids => 'Do you take glucocorticoids?';

  @override
  String get questionRheumatoid => 'Have you reported rheumatoid arthritis?';

  @override
  String get questionSecondaryOsteoporosis =>
      'Have you reported secondary osteoporosis?';

  @override
  String get questionBmd => 'Bone mineral density';

  @override
  String get homeNextControl => 'Next check';

  @override
  String get homeCompleteQuestionnaires => 'Complete questionnaires';

  @override
  String get recommendationScreeningMammografia => 'Mammogram';

  @override
  String get recommendationScreeningCervicePap => 'Pap test';

  @override
  String get recommendationScreeningCerviceHpv => 'HPV test';

  @override
  String get recommendationScreeningColon => 'Faecal occult blood test';

  @override
  String get recommendationPressione => 'Blood pressure measurement';

  @override
  String get recommendationLipidi => 'Lipid profile';

  @override
  String get recommendationGlicemia => 'Fasting blood glucose';

  @override
  String get recommendationPesoBmi => 'Weight and body mass index';

  @override
  String get recommendationVista => 'Eye examination';

  @override
  String get recommendationUdito => 'Hearing check';

  @override
  String get recommendationDentista => 'Dental check-up';

  @override
  String get recommendationDermatologo => 'Mole check';

  @override
  String get recommendationVaccinoInfluenza => 'Flu vaccination';

  @override
  String get recommendationVaccinoPneumococco => 'Pneumococcal vaccination';

  @override
  String get recommendationVaccinoZoster => 'Shingles vaccination';

  @override
  String get recommendationVaccinoTetano =>
      'Diphtheria, tetanus and pertussis booster';

  @override
  String get recommendationPsa => 'Discuss prostate risk with your doctor';

  @override
  String get recommendationDensitometria => 'Bone density scan (DEXA)';

  @override
  String get recommendationAaa => 'Abdominal aortic ultrasound';

  @override
  String get recommendationGlicemiaFindrisc => 'Fasting blood glucose';

  @override
  String get recommendationLipidiScore2 => 'Lipid check';

  @override
  String get recommendationVisitaCardiologicaScore2 => 'Cardiology visit';

  @override
  String get recommendationVisitaNefrologicaEgfr => 'Nephrology visit';

  @override
  String get recommendationCreatininaEgfr => 'Creatinine check';

  @override
  String get recommendationDensitometriaFrattura =>
      'Bone density scan for fracture risk';

  @override
  String get recommendationLevelImproved => 'Risk level improved';

  @override
  String get recommendationScreeningMammografiaReason =>
      'Organised national screening programme; some regions include ages 45–74.';

  @override
  String get recommendationScreeningCervicePapReason =>
      'Organised national screening programme.';

  @override
  String get recommendationScreeningCerviceHpvReason =>
      'Organised national screening programme.';

  @override
  String get recommendationScreeningColonReason =>
      'Organised national screening programme; some regions include up to age 74.';

  @override
  String get recommendationPressioneReason =>
      'From age 40 this may be yearly; follow your doctor\'s advice when values are elevated.';

  @override
  String get recommendationLipidiReason =>
      'It may be more frequent with risk factors or treatment, as advised by your doctor.';

  @override
  String get recommendationGlicemiaReason =>
      'It may be earlier or more frequent when risk factors are present.';

  @override
  String get recommendationPesoBmiReason =>
      'Periodic weight and body mass index check.';

  @override
  String get recommendationVistaReason => 'From age 65 this may be yearly.';

  @override
  String get recommendationUditoReason => 'Periodic hearing check from age 65.';

  @override
  String get recommendationDentistaReason => 'Periodic dental check-up.';

  @override
  String get recommendationDermatologoReason =>
      'It may be more frequent with family history or many moles.';

  @override
  String get recommendationVaccinoInfluenzaReason =>
      'Every autumn from age 60 and for at-risk groups.';

  @override
  String get recommendationVaccinoPneumococcoReason =>
      'Once, following the national vaccination schedule.';

  @override
  String get recommendationVaccinoZosterReason =>
      'According to the national vaccination schedule.';

  @override
  String get recommendationVaccinoTetanoReason => 'Booster every 10 years.';

  @override
  String get recommendationPsaReason =>
      'A shared decision with your doctor; this is not population screening.';

  @override
  String get recommendationDensitometriaReason =>
      'Earlier with risk factors; men from age 70.';

  @override
  String get recommendationAaaReason =>
      'Once from age 65 to 75 for current or former smokers.';

  @override
  String get recommendationGlicemiaFindriscReason =>
      'Recommended because the FINDRISC score is medium or high.';

  @override
  String get recommendationLipidiScore2Reason =>
      'Recommended because the SCORE2 score is medium or high.';

  @override
  String get recommendationVisitaCardiologicaScore2Reason =>
      'Recommended because the SCORE2 score indicates increased risk.';

  @override
  String get recommendationVisitaNefrologicaEgfrReason =>
      'Recommended because the eGFR value is reduced.';

  @override
  String get recommendationCreatininaEgfrReason =>
      'Recommended because creatinine needs monitoring.';

  @override
  String get recommendationDensitometriaFratturaReason =>
      'Recommended because fracture risk is medium or high.';

  @override
  String get explanationTitle => 'Explanation';

  @override
  String get explanationSimple => 'Simple';

  @override
  String get explanationClinical => 'Clinical';

  @override
  String get explanationMore => 'More actions';

  @override
  String get explanationExplainValue => 'Explain this value';

  @override
  String get explanationExplainOrgan => 'Explain this organ';

  @override
  String get explanationExplainRisk => 'Explain this risk';

  @override
  String get explanationExplainDocument => 'Explain this report';

  @override
  String get explanationReportCta => 'Explain this report';

  @override
  String get explanationReportCtaReread => 'Read the explanation again';

  @override
  String get explanationReportCtaDisabled => 'Confirm at least one value';

  @override
  String explanationUsageNote(int count) {
    return 'Counts toward the $count explanations available today';
  }

  @override
  String get explanationWriting => 'I am writing the explanation…';

  @override
  String explanationGeneratedMeta(String model, String date) {
    return 'AI-generated text · $model · $date';
  }

  @override
  String explanationUpdatedAt(String date) {
    return 'Updated $date';
  }

  @override
  String get explanationRequiredClosing =>
      'This information does not replace your doctor\'s advice.';

  @override
  String get explanationUnavailable =>
      'We cannot provide a reliable explanation for this data';

  @override
  String get explanationUnavailableAdvice => 'Discuss it with your doctor.';

  @override
  String get explanationLimitReached =>
      'You have reached today\'s limit of 30 explanations';

  @override
  String get explanationLimitTomorrow =>
      'You can request new explanations tomorrow.';

  @override
  String get explanationError => 'We could not create the explanation';

  @override
  String get explanationErrorAdvice => 'Check your connection and try again.';

  @override
  String get explanationConfirmValues =>
      'Confirm the values to get an explanation.';

  @override
  String get explanationRegenerate => 'Regenerate';

  @override
  String get explanationRegenerateTitle => 'Regenerate the explanation?';

  @override
  String get explanationRegenerateConfirm =>
      'Regenerating counts toward the daily limit and replaces the version shown.';

  @override
  String get aiTaskPaused => 'The AI service is temporarily paused.';

  @override
  String get maintenanceMessage =>
      'Medical 24 is under maintenance. Please try again shortly.';

  @override
  String get adminGovernment => 'Government';

  @override
  String get adminOverview => 'Overview';

  @override
  String get adminAiTasks => 'AI tasks';

  @override
  String get adminSettings => 'Settings';

  @override
  String get adminPrompts => 'Prompts';

  @override
  String get adminUsage => 'Usage';

  @override
  String get adminEvents => 'Events';

  @override
  String get adminAudit => 'Audit';

  @override
  String get adminRules => 'Rules';

  @override
  String get adminSoon => 'Soon';

  @override
  String get adminDesktopOnly => 'The government panel is available on desktop';

  @override
  String get adminDesktopOnlyBody =>
      'Open Medical 24 on a screen at least 1200 pt wide.';

  @override
  String get adminForbiddenTitle => '403 · Access denied';

  @override
  String get adminForbiddenBody => 'This area is reserved for administrators.';

  @override
  String get adminAccessError => 'We could not verify your permissions.';

  @override
  String get adminBackHome => 'Back to home';

  @override
  String get adminBackToApp => 'Back to the app';

  @override
  String get adminRefresh => 'Refresh';

  @override
  String get adminUsersTotal => 'Total users';

  @override
  String get adminUsersActive7d => 'Active in 7 days';

  @override
  String get adminUsersActive30d => 'Active in 30 days';

  @override
  String get adminDocuments => 'Documents';

  @override
  String get adminExtractionsOk => 'Successful extractions · 7 days';

  @override
  String get adminExtractionsFailed => 'Failed extractions · 7 days';

  @override
  String get adminExtractionsReview => 'To review · 7 days';

  @override
  String get adminCostToday => 'Today\'s cost by task';

  @override
  String get adminCostMonth => 'Monthly cost by task';

  @override
  String get adminErrors24h => '24-hour errors by code';

  @override
  String get adminTaskStatus => 'Task status';

  @override
  String get adminLastHealth => 'Latest health';

  @override
  String get adminActive => 'Active';

  @override
  String get adminDisabled => 'Disabled';

  @override
  String get adminPaused => 'Paused';

  @override
  String adminPausedUntil(String date) {
    return 'Paused until $date';
  }

  @override
  String get adminAiTasksModels => 'AI tasks and models';

  @override
  String get adminTask => 'Task';

  @override
  String get adminModel => 'Model';

  @override
  String get adminFallback => 'Fallback';

  @override
  String get adminPrompt => 'Active prompt';

  @override
  String get adminBudgetProgress => 'Budget / spent today';

  @override
  String get adminStatus => 'Status';

  @override
  String get adminEdit => 'Edit';

  @override
  String get adminModels => 'Models';

  @override
  String get adminNewModel => 'New model';

  @override
  String get adminEditModel => 'Edit model';

  @override
  String get adminId => 'ID';

  @override
  String get adminProvider => 'Provider';

  @override
  String get adminName => 'Name';

  @override
  String get adminPriceInput => 'Input \$/MTok';

  @override
  String get adminPriceOutput => 'Output \$/MTok';

  @override
  String get adminPriceCache => 'Read cache \$/MTok';

  @override
  String get adminPriceInputMicro => 'Input price in micro-USD/MTok';

  @override
  String get adminPriceOutputMicro => 'Output price in micro-USD/MTok';

  @override
  String get adminPriceCacheMicro => 'Read cache price in micro-USD/MTok';

  @override
  String get adminContextWindow => 'Context window';

  @override
  String get adminFallbackEnabled => 'Fallback enabled';

  @override
  String get adminMaxOutputTokens => 'Maximum output tokens';

  @override
  String get adminEnabled => 'Enabled';

  @override
  String get adminDailyBudgetUsd => 'Daily budget in dollars';

  @override
  String get adminBudgetAction => 'Budget action';

  @override
  String get adminBudgetAlert => 'Alert';

  @override
  String get adminBudgetPause => 'Pause';

  @override
  String get adminUserDailyLimit => 'Daily limit per user';

  @override
  String get adminSecondApproval => 'Second approval required';

  @override
  String get adminRequestPreset => 'Preset';

  @override
  String adminEffort(String effort) {
    return 'No reasoning, $effort effort';
  }

  @override
  String get adminAdaptiveThinking => 'Adaptive reasoning';

  @override
  String get adminRequestOptions => 'Request options (JSON)';

  @override
  String get adminPositiveNumberError => 'Enter a number greater than zero.';

  @override
  String get adminJsonObjectError => 'JSON must be an object.';

  @override
  String get adminJsonInvalid => 'Enter valid JSON.';

  @override
  String get adminResume => 'Resume';

  @override
  String get adminPauseTomorrow => 'Pause until tomorrow';

  @override
  String get adminModelInUse =>
      'The model is in use: change the task model first.';

  @override
  String get adminKey => 'Key';

  @override
  String get adminValue => 'Value';

  @override
  String get adminPublic => 'Public';

  @override
  String get adminDescription => 'Description';

  @override
  String get adminVersion => 'Version';

  @override
  String get adminUpdatedAt => 'Updated';

  @override
  String get adminHistory => 'History';

  @override
  String get adminValueJson => 'JSON value';

  @override
  String get adminMaintenance => 'Maintenance mode';

  @override
  String get adminMaintenanceBody =>
      'Pauses the platform\'s operational functions.';

  @override
  String get adminMaintenanceConfirmTitle => 'Change maintenance mode?';

  @override
  String get adminMaintenanceConfirmBody =>
      'The change takes effect immediately for all users.';

  @override
  String get adminCompare => 'Compare';

  @override
  String get adminRestore => 'Restore';

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminRunTest => 'Run test';

  @override
  String get adminActivate => 'Activate';

  @override
  String get adminFilterPassed => 'Filter passed';

  @override
  String get adminClosingPresent => 'Closing present';

  @override
  String get adminPrevious => 'Previous';

  @override
  String get adminNext => 'Next';

  @override
  String get adminNewVersion => 'New version';

  @override
  String get adminCreatedBy => 'Created by';

  @override
  String get adminApprovedBy => 'Approved by';

  @override
  String get adminActivatedAt => 'Activated';

  @override
  String get adminLastTest => 'Latest test';

  @override
  String get adminPassed => 'Passed';

  @override
  String get adminFailed => 'Failed';

  @override
  String get adminDraft => 'Draft';

  @override
  String get adminRetired => 'Retired';

  @override
  String get adminTestResults => 'Test results';

  @override
  String get adminSecondApproverRequired =>
      'A second administrator\'s approval is required';

  @override
  String get adminApprovalRequired =>
      'The prompt must be approved before activation.';

  @override
  String get adminPassingTestRequired =>
      'A passing test is required before activation.';

  @override
  String get adminRestoreConfirm =>
      'Restore the previous version for this task?';

  @override
  String get adminSaved => 'Changes saved';

  @override
  String get adminSystemPrompt => 'System prompt';

  @override
  String get adminUserTemplate => 'User template';

  @override
  String get adminToolSchema => 'Tool schema (JSON)';

  @override
  String get adminNotes => 'Notes';

  @override
  String get adminAll => 'All';

  @override
  String get adminRecentCalls => 'Recent calls';

  @override
  String get adminDay => 'Day';

  @override
  String get adminCalls => 'Calls';

  @override
  String get adminOk => 'OK';

  @override
  String get adminErrors => 'Errors';

  @override
  String get adminCache => 'Cache';

  @override
  String get adminTokensIn => 'Input tokens';

  @override
  String get adminTokensCache => 'Cache tokens';

  @override
  String get adminTokensOut => 'Output tokens';

  @override
  String get adminCostUsd => 'Cost in dollars';

  @override
  String get adminLatencyAvg => 'Average latency';

  @override
  String get adminLatencyP95 => 'p95 latency';

  @override
  String get adminType => 'Type';

  @override
  String get adminAction => 'Action';

  @override
  String get adminActorUuid => 'Actor (UUID)';

  @override
  String get adminDetails => 'Details';

  @override
  String get adminDefinition => 'Definition';

  @override
  String get adminRuleStatusConfirm => 'Confirm the rule status change?';
}
