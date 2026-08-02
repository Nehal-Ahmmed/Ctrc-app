import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../Auth/presentation/providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Started, not awaited. The hosted backend sleeps when idle and can take
    // most of a minute to answer the first call — the app used to sit on this
    // screen for all of it. It no longer has to: the session, the theme and the
    // last feed all come off the device, so there is a usable app to show while
    // the server wakes up in the background.
    unawaited(_wakeBackend());

    // Long enough to read the logo, short enough not to be a wait.
    await Future<void>.delayed(const Duration(milliseconds: 700));

    // Auth state does not gate this: both guests and signed-in users land on
    // the same feed.
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _wakeBackend() async {
    final dataSource = ref.read(authRemoteDataSourceProvider);
    if (!await dataSource.checkHealth()) return;

    // No context: by the time this answers, this page is usually gone, so the
    // toast goes to the root overlay instead.
    AppToast.success(
      null,
      'Connected 🚀',
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.traffic, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'CTRC System',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
