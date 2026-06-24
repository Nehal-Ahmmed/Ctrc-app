import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/Auth/presentation/pages/sign_in_page.dart';
import '../../features/Auth/presentation/pages/sign_up_page.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/sign-in',
    routes: [
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
        path: '/home',
        name: 'home',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home - Authenticated'))),
      ),
    ],
  );
}
