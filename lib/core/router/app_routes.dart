/// Route paths. Web URLs have no "#" (path URL strategy) and deep links
/// resolve to the same routes on iOS and Android.
class AppRoutes {
  const AppRoutes._();

  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String otp = '/otp';
  static const String resetPassword = '/reset-password';

  static const String onboarding = '/onboarding';

  static const String home = '/';
  static const String health = '/health';
  static const String healthValues = '/health/values';
  static String healthValue(String code) => '/health/values/${Uri.encodeComponent(code)}';
  static const String healthValueNew = '/health/values/new';
  static String healthValueNewFor(String code) => '$healthValueNew?code=${Uri.encodeQueryComponent(code)}';
  static const String symptoms = '/health/symptoms';
  static const String symptomNew = '/health/symptoms/new';
  static String symptom(String id) => '/health/symptoms/${Uri.encodeComponent(id)}';
  static const String alerts = '/health/alerts';
  static const String prevention = '/health/prevention';
  static const String preventionQuestionnaire = '/health/prevention/questionnaire';
  static String bodyOrgan(String organ) => '/health/body/${Uri.encodeComponent(organ)}';
  static String bodyOrganHistory(String organ) => '${bodyOrgan(organ)}/history';
  static const String archive = '/archive';
  static String archiveDocument(String id) => '/archive/document/$id';
  static String analysis(String id) => '/archive/document/$id/analysis';
  static String analysisReview(String id) => '/archive/document/$id/analysis/review';
  static const String treatments = '/treatments';
  static const String doctor = '/doctor';

  static const String settings = '/settings';
  static const String settingsProfile = '/settings/profile';
  static const String settingsConsents = '/settings/consents';
  static const String devKit = '/dev/kit';

  static const List<String> publicRoutes = <String>[
    welcome,
    signIn,
    signUp,
    otp,
    resetPassword,
  ];
}
