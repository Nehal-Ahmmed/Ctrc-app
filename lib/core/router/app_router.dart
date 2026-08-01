import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../features/Auth/presentation/pages/sign_in_page.dart';
import '../../features/Auth/presentation/pages/sign_up_page.dart';
import '../../features/Home/presentation/pages/home_page.dart';
import '../../features/Map/presentation/pages/map_page.dart';
import '../../features/Profile/presentation/pages/profile_page.dart';
import '../../features/Profile/presentation/pages/settings_page.dart';
import '../../features/Report/domain/models/report_model.dart';
import '../../features/Report/presentation/pages/my_reports_page.dart';
import '../../features/Report/presentation/pages/report_details_page.dart';
import '../../features/Report/presentation/pages/saved_posts_page.dart';
import '../../features/Splash/presentation/pages/splash_page.dart';
import '../widgets/main_scaffold.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
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
        parentNavigatorKey: _rootNavigatorKey, // Covers bottom nav
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/my-reports',
        parentNavigatorKey: _rootNavigatorKey, 
        builder: (context, state) => const MyReportsPage(),
      ),
      GoRoute(
        path: '/saved-posts',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SavedPostsPage(),
      ),
      GoRoute(
        path: '/report/:id',
        name: 'reportDetails',
        parentNavigatorKey: _rootNavigatorKey,
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
}
