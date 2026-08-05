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

  await LocalStore.instance.init();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: CTRCApp()));
}

void _installErrorHandlers() {
  
  final flutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    flutterOnError?.call(details); 
    _reportQuietly(details.exception);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    _reportQuietly(error);
    return true; 
  };

  ErrorWidget.builder = (details) => ErrorScreen(
        message: AppError.from(details.exception).message,
        detail: kDebugMode ? details.exceptionAsString() : null,
      );
}

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
