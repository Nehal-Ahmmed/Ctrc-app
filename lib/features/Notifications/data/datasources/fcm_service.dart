import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/root_navigator_key.dart';
import '../../../../core/storage/local_store.dart';
import '../../../../firebase_options.dart';
import '../../domain/services/geo_topic.dart';

/// The channel every CTRC push lands on.
///
/// The same id is repeated in AndroidManifest.xml under
/// `com.google.firebase.messaging.default_notification_channel_id`. Pushes that
/// arrive while the app is backgrounded or dead are drawn by the Firebase SDK
/// rather than by us, and without that meta-data Android files them on a silent
/// fallback channel where they never pop up. Keep the two in sync.
const kFcmChannelId = 'ctrc_alerts';

const _channel = AndroidNotificationChannel(
  kFcmChannelId,
  'CTRC Alerts',
  description: 'Incident reports and status updates near you.',
  importance: Importance.high,
);

/// Handles a push that arrives while the app is backgrounded or not running.
///
/// Android spins this up in a fresh isolate, so nothing the UI isolate set up
/// exists here and Firebase has to be initialised again from scratch. It has to
/// stay a top-level function carrying `@pragma('vm:entry-point')` — without the
/// annotation the release compiler tree-shakes it away and background pushes
/// silently stop being handled.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] background: ${message.messageId} ${message.data}');
}

/// Owns the device's Firebase Cloud Messaging registration and everything that
/// has to happen when a push shows up.
///
/// Deliberately separate from [NotificationController], which builds its inbox
/// locally from the nearby-reports feed. This class only deals with messages
/// that came off the wire.
class FcmService {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// The device's registration token — what the backend, or the Firebase
  /// console's "send test message" box, addresses a push to.
  final ValueNotifier<String?> token = ValueNotifier<String?>(null);

  /// Ids only have to be unique among notifications currently on screen, so a
  /// counter is enough and beats hashing a message id that may be null.
  int _nextId = 0;

  bool _isStarted = false;

  /// Wires up permissions, the channel and the message listeners.
  ///
  /// Safe to call more than once; only the first call does anything. Callers
  /// launch this without awaiting it, so it swallows its own failures rather
  /// than surfacing an uncaught future error as a toast: a device with no Play
  /// Services still has a perfectly usable app, minus push.
  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;

    try {
      await _start();
    } catch (error, stack) {
      debugPrint('[FCM] setup failed: $error\n$stack');
    }
  }

  Future<void> _start() async {
    await _setUpLocalNotifications();

    final messaging = FirebaseMessaging.instance;

    // On Android 13+ this is what raises the POST_NOTIFICATIONS prompt. On
    // older versions the permission is granted at install time and this
    // resolves immediately.
    final settings = await messaging.requestPermission();
    debugPrint('[FCM] permission: ${settings.authorizationStatus}');

    await _loadToken(messaging);

    // Tokens rotate on reinstall, restore and app-data clear, so the fresh one
    // has to replace whatever the backend has on file.
    messaging.onTokenRefresh.listen((value) {
      token.value = value;
      _logToken(value);
    });

    // App open and on screen: Android hands the payload straight to us instead
    // of drawing anything, so the banner is ours to put up.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // Tapped while the app was sitting in the background.
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);

    // Tapped while the app was not running at all — the push that started the
    // process is waiting here, and only ever gets handed over once.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      // The router is still on the splash screen at this point and would
      // overwrite an immediate push, so wait for it to settle first.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openFromMessage(initial),
      );
    }
  }

  Future<void> _setUpLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _openReport(_reportIdFrom(response.payload)),
    );

    // Creating a channel that already exists is a no-op, so this can run on
    // every launch. Note Android ignores importance changes to a channel that
    // already exists — bump the id if the settings above ever change.
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  void _showForeground(RemoteMessage message) {
    debugPrint('[FCM] foreground: ${message.messageId} ${message.data}');

    final notification = message.notification;

    // Data-only pushes carry no text to show; they are for the app to act on.
    if (notification == null) return;

    _local.show(
      id: _nextId++,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['reportId']?.toString(),
    );
  }

  void _openFromMessage(RemoteMessage message) {
    debugPrint('[FCM] opened: ${message.messageId} ${message.data}');
    _openReport(_reportIdFrom(message.data['reportId']?.toString()));
  }

  /// Sends the user to the report a push was about.
  ///
  /// Anything without a usable `reportId` in its data payload — a plain test
  /// message from the Firebase console, for instance — just opens the app,
  /// which is the right outcome rather than an error.
  void _openReport(int? reportId) {
    if (reportId == null) return;

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    context.push('/report/$reportId');
  }

  int? _reportIdFrom(String? raw) {
    final id = int.tryParse(raw ?? '');
    return (id != null && id > 0) ? id : null;
  }

  /// Points this device at the part of the map it wants to hear about.
  ///
  /// Subscribing to a topic per map cell is what keeps the server side of this
  /// feature almost free: nobody stores a device token, and nothing has to work
  /// out who is standing where. The backend publishes a new report to the one
  /// cell it landed in and Firebase fans it out to whoever is listening.
  ///
  /// Called on every feed load, which is also every time the position or the
  /// radius preference moves. Returns immediately when the set has not changed,
  /// so that stays cheap.
  Future<void> syncTopics({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required bool enabled,
  }) async {
    final wanted = enabled
        ? GeoTopic.covering(latitude, longitude, radiusKm)
        : <String>{};

    final current =
        (LocalStore.instance.getStringList(StorageKeys.fcmTopics) ?? const [])
            .toSet();

    if (wanted.length == current.length && wanted.containsAll(current)) return;

    final messaging = FirebaseMessaging.instance;

    try {
      for (final topic in current.difference(wanted)) {
        await messaging.unsubscribeFromTopic(topic);
      }
      for (final topic in wanted.difference(current)) {
        await messaging.subscribeToTopic(topic);
      }
      // Written only after every call succeeded, so a half-finished sync is
      // simply retried on the next feed load rather than being remembered as
      // done.
      await LocalStore.instance
          .setStringList(StorageKeys.fcmTopics, wanted.toList());
      debugPrint('[FCM] listening to ${wanted.length} area(s)');
    } catch (error) {
      debugPrint('[FCM] could not update areas: $error');
    }
  }

  Future<void> _loadToken(FirebaseMessaging messaging) async {
    try {
      final value = await messaging.getToken();
      token.value = value;
      if (value != null) _logToken(value);
    } catch (error) {
      // Missing Play Services, no network, throttled registration — none of
      // which is a reason to stop the rest of the app from starting.
      debugPrint('[FCM] token request failed: $error');
    }
  }

  void _logToken(String value) {
    debugPrint('===================== FCM TOKEN =====================');
    debugPrint(value);
    debugPrint('=====================================================');
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService());
