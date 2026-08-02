import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../features/Auth/presentation/pages/forgot_password_page.dart';
import '../../features/Auth/presentation/pages/sign_in_page.dart';
import '../../features/Auth/presentation/pages/sign_up_page.dart';
import '../../features/Home/presentation/pages/home_page.dart';
import '../../features/Map/presentation/pages/map_page.dart';
import '../../features/Notifications/presentation/pages/notifications_page.dart';
import '../../features/Profile/presentation/pages/change_password_page.dart';
import '../../features/Profile/presentation/pages/edit_profile_page.dart';
import '../../features/Profile/presentation/pages/help_center_page.dart';
import '../../features/Profile/presentation/pages/privacy_policy_page.dart';
import '../../features/Profile/presentation/pages/profile_page.dart';
import '../../features/Profile/presentation/pages/settings_page.dart';
import '../../features/Report/domain/models/report_model.dart';
import '../../features/Report/presentation/pages/my_reports_page.dart';
import '../../features/Report/presentation/pages/report_details_page.dart';
import '../../features/Report/presentation/pages/saved_posts_page.dart';
import '../../features/Splash/presentation/pages/splash_page.dart';
import '../../features/Auth/presentation/providers/auth_provider.dart';
import '../widgets/main_scaffold.dart';
import 'root_navigator_key.dart';

/// Pages that only mean anything with an account behind them. A guest who
/// lands on one — by deep link, or by signing out while it is open — is sent
/// back to the feed rather than left staring at a locked page.
const _authOnlyRoutes = {
  '/my-reports',
  '/saved-posts',
  '/edit-profile',
  '/change-password',
};

/// Pages that exist only to get an account, so there is nothing for a
/// signed-in user to do on them.
const _guestOnlyRoutes = {'/sign-in', '/sign-up', '/forgot-password'};

/// Re-runs the router's redirect whenever the session changes, so signing out
/// tears down every account-only page still sitting on the stack.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    _subscription = ref.listen<bool>(
      isAuthenticatedProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<bool> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshListenable(ref);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authProvider).status;

      // Nothing is decided until the stored token has been checked; bouncing
      // now would log out anyone who deep-links straight into the app.
      if (status == AuthStatus.uninitialized || status == AuthStatus.loading) {
        return null;
      }

      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final location = state.matchedLocation;

      if (!isAuthenticated && _authOnlyRoutes.contains(location)) {
        return '/home';
      }
      if (isAuthenticated && _guestOnlyRoutes.contains(location)) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'signIn',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/sign-up',
        name: 'signUp',
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey, // Covers bottom nav
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: '/change-password',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/help',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HelpCenterPage(),
      ),
      GoRoute(
        path: '/privacy',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PrivacyPolicyPage(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/my-reports',
        parentNavigatorKey: rootNavigatorKey, 
        builder: (context, state) => const MyReportsPage(),
      ),
      GoRoute(
        path: '/saved-posts',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SavedPostsPage(),
      ),
      GoRoute(
        path: '/report/:id',
        name: 'reportDetails',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

          // Callers may pass the already-loaded report (and the viewer's
          // position) so the page can paint before the network call returns.
          final extra = state.extra;
          ReportModel? report;
          LatLng? viewerLocation;
          if (extra is Map) {
            report = extra['report'] as ReportModel?;
            viewerLocation = extra['viewerLocation'] as LatLng?;
          } else if (extra is ReportModel) {
            report = extra;
          }

          return ReportDetailsPage(
            reportId: id,
            initialReport: report,
            viewerLocation: viewerLocation,
          );
        },
      ),
    ],
  );

  // The router unhooks itself from the listenable first, so the listenable is
  // still alive when it does.
  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);

  return router;
});
