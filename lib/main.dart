import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/errors/app_error.dart';
import 'core/router/app_router.dart';
import 'core/storage/local_store.dart';
import 'core/widgets/app_toast.dart';
import 'core/widgets/error_screen.dart';
import 'features/Notifications/data/datasources/fcm_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();

  // Before anything reads it. One disk pass here is what lets the session, the
  // theme and the last feed be read synchronously for the rest of the run, so
  // the first frame is already the right one rather than a default that
  // corrects itself a moment later.
  await LocalStore.instance.init();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Registered before the app runs: Android can hand over a background push
  // while the engine is still starting, and there is nowhere to put one that
  // arrives before a handler exists.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: CTRCApp()));
}

/// Catches whatever escapes a `try`/`catch` and shows it as a toast instead of
/// a red screen or a wall of console-style text.
void _installErrorHandlers() {
  // Widget build / layout / paint failures.
  final flutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    flutterOnError?.call(details); // Keep the console log for debugging.
    _reportQuietly(details.exception);
  };

  // Errors from futures and isolates that nothing awaited.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    _reportQuietly(error);
    return true; // Handled — do not take the app down with it.
  };

  // A widget that fails to build otherwise leaves Flutter's error box sitting
  // in the layout. Put something calm in that slot instead.
  ErrorWidget.builder = (details) => ErrorScreen(
        message: AppError.from(details.exception).message,
        detail: kDebugMode ? details.exceptionAsString() : null,
      );
}

/// Shows an uncaught error once, on the next frame.
///
/// A failure during build cannot insert an overlay entry synchronously, and the
/// same exception often fires every frame while a broken widget is on screen —
/// AppToast de-duplicates, so at most one card appears.
void _reportQuietly(Object error) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AppToast.error(null, error);
  });
}

class CTRCApp extends ConsumerStatefulWidget {
  const CTRCApp({super.key});

  @override
  ConsumerState<CTRCApp> createState() => _CTRCAppState();
}

class _CTRCAppState extends ConsumerState<CTRCApp> {
  @override
  void initState() {
    super.initState();

    // Not awaited on purpose — the permission prompt and token registration
    // both go over the network, and neither should hold up the first frame.
    // FcmService swallows its own failures so nothing lands in the global
    // handler above.
    ref.read(fcmServiceProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CTRC',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
