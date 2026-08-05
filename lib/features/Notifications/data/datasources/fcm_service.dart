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

const kFcmChannelId = 'ctrc_alerts';

const _channel = AndroidNotificationChannel(
  kFcmChannelId,
  'CTRC Alerts',
  description: 'Incident reports and status updates near you.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] background: ${message.messageId} ${message.data}');
}

class FcmService {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  final ValueNotifier<String?> token = ValueNotifier<String?>(null);

  int _nextId = 0;

  bool _isStarted = false;

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

    final settings = await messaging.requestPermission();
    debugPrint('[FCM] permission: ${settings.authorizationStatus}');

    await _loadToken(messaging);

    messaging.onTokenRefresh.listen((value) {
      token.value = value;
      _logToken(value);
    });

    FirebaseMessaging.onMessage.listen(_showForeground);

    FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      
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

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  void _showForeground(RemoteMessage message) {
    debugPrint('[FCM] foreground: ${message.messageId} ${message.data}');

    final notification = message.notification;

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
