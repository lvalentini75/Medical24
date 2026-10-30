import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medical24/features/auth/screens/otp_screen.dart';
import 'package:medical24/features/auth/screens/reset_password_screen.dart';
import 'package:medical24/features/auth/screens/sign_in_screen.dart';
import 'package:medical24/features/auth/screens/welcome_screen.dart';
import 'package:medical24/features/archive/screens/archive_screen.dart';
import 'package:medical24/features/analysis/screens/document_analysis_screen.dart';
import 'package:medical24/features/health/screens/manual_value_screen.dart';
import 'package:medical24/features/home/screens/home_screen.dart';
import 'package:medical24/features/home/screens/placeholder_sections.dart';
import 'package:medical24/features/health/screens/health_values_screen.dart';
import 'package:medical24/features/health/screens/alerts_screen.dart';
import 'package:medical24/features/health/screens/symptom_form_screen.dart';
import 'package:medical24/features/health/screens/symptoms_screen.dart';
import 'package:medical24/features/health/body/screens/body_detail_screen.dart';
import 'package:medical24/features/health/body/screens/body_history_screen.dart';
import 'package:medical24/features/health/body/screens/body_screen.dart';
import 'package:medical24/features/health/prevention/screens/prevention_questionnaire_screen.dart';
import 'package:medical24/features/health/prevention/screens/prevention_screen.dart';
import 'package:medical24/features/home/providers/home_providers.dart';
import 'package:medical24/core/ui/kit_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/settings/screens/consents_log_screen.dart';
import '../../features/settings/screens/edit_profile_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../models/user_profile.dart';
import '../providers/app_providers.dart';
import '../widgets/app_shell.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Rebuilds the router when the session or the profile changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen<Session?>(sessionProvider, (_, __) => notifyListeners());
    ref.listen<AsyncValue<UserProfile?>>(
        myProfileProvider, (_, __) => notifyListeners());
  }

  final Ref ref;
}

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final _RouterRefresh refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final bool signedIn = ref.read(sessionProvider) != null;
      final String location = state.matchedLocation;
      final bool isPublic = AppRoutes.publicRoutes.contains(location);

      if (kDebugMode && location == AppRoutes.devKit) return null;

      if (!signedIn) return isPublic ? null : AppRoutes.welcome;

      final AsyncValue<UserProfile?> profile = ref.read(myProfileProvider);
      final UserProfile? data =
          profile.hasValue ? profile.requireValue : null;
      final bool onboarded = data?.isOnboarded ?? false;

      if (profile.isLoading && data == null) return null;

      if (!onboarded && location != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }
      if (onboarded && (isPublic || location == AppRoutes.onboarding)) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: <RouteBase>[
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.devKit,
          name: 'devKit',
          builder: (BuildContext context, GoRouterState state) => const M24KitScreen(),
        ),
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        builder: (BuildContext context, GoRouterState state) =>
            const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: 'signIn',
        builder: (BuildContext context, GoRouterState state) =>
            const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: 'signUp',
        builder: (BuildContext context, GoRouterState state) =>
            const SignInScreen(isSignUp: true),
      ),
      GoRoute(
        path: AppRoutes.otp,
        name: 'otp',
        builder: (BuildContext context, GoRouterState state) => OtpScreen(
          email: state.uri.queryParameters['email'] ?? '',
          isRecovery: state.uri.queryParameters['recovery'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: 'resetPassword',
        builder: (BuildContext context, GoRouterState state) =>
            const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'profile',
            name: 'settingsProfile',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (BuildContext context, GoRouterState state) =>
                const EditProfileScreen(),
          ),
          GoRoute(
            path: 'consents',
            name: 'settingsConsents',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (BuildContext context, GoRouterState state) =>
                const ConsentsLogScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state,
            StatefulNavigationShell navigationShell) {
          return AppShell(
            navigationShell: navigationShell,
            currentIndex: navigationShell.currentIndex,
            onDestinationSelected: (int index) {
              if (index == 0) ref.invalidate(homeSnapshotProvider);
              navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
            },
          );
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              builder: (BuildContext context, GoRouterState state) =>
                  const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.health,
              name: 'health',
              builder: (BuildContext context, GoRouterState state) =>
                  const BodyScreen(),
              routes: <RouteBase>[
                GoRoute(path: 'body/:organ', name: 'bodyOrgan', builder: (BuildContext context, GoRouterState state) => BodyDetailScreen(organId: state.pathParameters['organ']!), routes: <RouteBase>[
                  GoRoute(path: 'history', name: 'bodyOrganHistory', builder: (BuildContext context, GoRouterState state) => BodyHistoryScreen(organId: state.pathParameters['organ']!)),
                ]),
                GoRoute(path: 'values', name: 'healthValues', builder: (BuildContext context, GoRouterState state) => const HealthValuesScreen()),
                GoRoute(
                  path: 'values/new',
                  name: 'healthValueNew',
                  builder: (BuildContext context, GoRouterState state) => ManualValueScreen(initialCode: state.uri.queryParameters['code']),
                ),
                GoRoute(
                  path: 'values/:code',
                  name: 'healthValue',
                  builder: (BuildContext context, GoRouterState state) => HealthValuesScreen(code: state.pathParameters['code']!),
                ),
                GoRoute(path: 'symptoms', name: 'symptoms', builder: (BuildContext context, GoRouterState state) => const SymptomsScreen(), routes: <RouteBase>[
                  GoRoute(path: 'new', name: 'symptomNew', builder: (BuildContext context, GoRouterState state) => const SymptomFormScreen()),
                  GoRoute(path: ':id', name: 'symptomEdit', builder: (BuildContext context, GoRouterState state) => SymptomFormScreen(id: state.pathParameters['id']!)),
                ]),
                GoRoute(path: 'alerts', name: 'alerts', builder: (BuildContext context, GoRouterState state) => const AlertsScreen()),
                GoRoute(path: 'prevention', name: 'prevention', builder: (BuildContext context, GoRouterState state) => const PreventionScreen(), routes: <RouteBase>[
                  GoRoute(path: 'questionnaire', name: 'preventionQuestionnaire', builder: (BuildContext context, GoRouterState state) => const PreventionQuestionnaireScreen()),
                ]),
              ],
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.archive,
              name: 'archive',
              builder: (BuildContext context, GoRouterState state) =>
                  const ArchiveScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'document/:documentId',
                  name: 'archiveDocument',
                  builder: (BuildContext context, GoRouterState state) => ArchiveDocumentScreen(documentId: state.pathParameters['documentId']!),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'analysis',
                      name: 'documentAnalysis',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (BuildContext context, GoRouterState state) => DocumentAnalysisScreen(documentId: state.pathParameters['documentId']!),
                      routes: <RouteBase>[
                        GoRoute(
                          path: 'review',
                          name: 'documentAnalysisReview',
                          parentNavigatorKey: _rootNavigatorKey,
                          builder: (BuildContext context, GoRouterState state) => DocumentAnalysisScreen(documentId: state.pathParameters['documentId']!, reviewOnly: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.treatments,
              name: 'treatments',
              builder: (BuildContext context, GoRouterState state) =>
                  const TreatmentsSectionScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.doctor,
              name: 'doctor',
              builder: (BuildContext context, GoRouterState state) =>
                  const DoctorSectionScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
