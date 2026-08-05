import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageKeys {
  StorageKeys._();

  static const authToken = 'auth_token';
  static const authUser = 'auth_user';

  static const themeMode = 'theme_mode';
  static const reportRadius = 'report_radius';
  static const languageCode = 'language_code';
  static const nearbyAlerts = 'nearby_alerts_enabled';
  static const feedCategory = 'feed_category';
  static const feedFilter = 'feed_filter';

  static const lastKnownLocation = 'last_known_location';
  static const notificationItems = 'notifications_items';
  static const notificationSeenIds = 'notifications_seen_report_ids';

  static const fcmTopics = 'fcm_topics';

  static String userScope(String userId) => 'u:$userId:';

  static const guestScope = 'guest:';

  static String scoped(String name, String? userId) =>
      '${userId == null ? guestScope : userScope(userId)}$name';
}

class Stamped<T> {
  const Stamped(this.value, this.savedAt);

  final T value;
  final DateTime savedAt;

  Duration get age => DateTime.now().difference(savedAt);

  bool isOlderThan(Duration ttl) => age > ttl;
}

class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  SharedPreferences? _prefs;
  final Map<String, Object> _memory = {};
  bool _isReady = false;

  Future<void> init() async {
    if (_isReady) return;
    _isReady = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      for (final key in prefs.getKeys()) {
        final value = prefs.get(key);
        if (value != null) _memory[key] = value;
      }
    } catch (error) {
      
      debugPrint('LocalStore: running from memory only ($error)');
    }
  }

  String? getString(String key) => _memory[key] is String ? _memory[key] as String : null;

  int? getInt(String key) => _memory[key] is int ? _memory[key] as int : null;

  double? getDouble(String key) =>
      _memory[key] is double ? _memory[key] as double : null;

  bool? getBool(String key) => _memory[key] is bool ? _memory[key] as bool : null;

  List<String>? getStringList(String key) {
    final value = _memory[key];
    return value is List<String> ? List<String>.of(value) : null;
  }

  dynamic getJson(String key) {
    final raw = getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (error) {
      debugPrint('LocalStore: dropping unreadable cache at $key ($error)');
      remove(key);
      return null;
    }
  }

  Stamped<dynamic>? getStamped(String key) {
    final decoded = getJson(key);
    if (decoded is! Map) return null;

    final savedAt = DateTime.tryParse('${decoded['savedAt']}');
    if (savedAt == null) return null;

    return Stamped<dynamic>(decoded['data'], savedAt);
  }

  Future<void> setString(String key, String value) {
    _memory[key] = value;
    return _guard(() => _prefs?.setString(key, value));
  }

  Future<void> setInt(String key, int value) {
    _memory[key] = value;
    return _guard(() => _prefs?.setInt(key, value));
  }

  Future<void> setDouble(String key, double value) {
    _memory[key] = value;
    return _guard(() => _prefs?.setDouble(key, value));
  }

  Future<void> setBool(String key, bool value) {
    _memory[key] = value;
    return _guard(() => _prefs?.setBool(key, value));
  }

  Future<void> setStringList(String key, List<String> value) {
    _memory[key] = List<String>.of(value);
    return _guard(() => _prefs?.setStringList(key, value));
  }

  Future<void> setJson(String key, Object? value) {
    try {
      return setString(key, jsonEncode(value));
    } catch (error) {
      debugPrint('LocalStore: could not encode $key ($error)');
      return Future.value();
    }
  }

  Future<void> setStamped(String key, Object? value) => setJson(key, {
        'savedAt': DateTime.now().toIso8601String(),
        'data': value,
      });

  Future<void> remove(String key) {
    _memory.remove(key);
    return _guard(() => _prefs?.remove(key));
  }

  Future<void> removeScope(String prefix) async {
    final doomed = _memory.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in doomed) {
      await remove(key);
    }
  }

  Future<void> clearUserScope(String userId) =>
      removeScope(StorageKeys.userScope(userId));

  Future<void> _guard(Future<void>? Function() write) async {
    try {
      await write();
    } catch (error) {
      debugPrint('LocalStore: write failed ($error)');
    }
  }

  @visibleForTesting
  void resetForTest() {
    _memory.clear();
    _prefs = null;
    _isReady = false;
  }
}
