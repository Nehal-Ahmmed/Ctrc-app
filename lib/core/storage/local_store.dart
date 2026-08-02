import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every key this app writes to the device, gathered in one place.
///
/// Scattered string literals are how stored data quietly collides, or gets
/// orphaned when a key is renamed on one side only.
class StorageKeys {
  StorageKeys._();

  // --- session ---------------------------------------------------------------

  /// Deliberately the same string the app used before this store existed, so
  /// anyone already signed in stays signed in across the upgrade.
  static const authToken = 'auth_token';
  static const authUser = 'auth_user';

  // --- preferences -----------------------------------------------------------
  static const themeMode = 'theme_mode';
  static const reportRadius = 'report_radius';
  static const languageCode = 'language_code';
  static const nearbyAlerts = 'nearby_alerts_enabled';
  static const feedCategory = 'feed_category';
  static const feedFilter = 'feed_filter';

  // --- device-level caches ---------------------------------------------------
  static const lastKnownLocation = 'last_known_location';
  static const notificationItems = 'notifications_items';
  static const notificationSeenIds = 'notifications_seen_report_ids';

  /// Map cells this device is currently subscribed to for push alerts, so the
  /// ones it has moved away from can be unsubscribed rather than piling up.
  static const fcmTopics = 'fcm_topics';

  /// Prefix for anything that belongs to one account. Everything under it is
  /// deleted the moment that account signs out, which is what keeps one
  /// person's saved posts and votes from surfacing under the next person's
  /// session — or under no session at all.
  static String userScope(String userId) => 'u:$userId:';

  /// The same shelf for someone browsing without an account. Nothing private
  /// lands here, so it survives sign-out.
  static const guestScope = 'guest:';

  /// Where a cache for [userId] lives, or the guest shelf when null.
  static String scoped(String name, String? userId) =>
      '${userId == null ? guestScope : userScope(userId)}$name';
}

/// A value read back off the device, together with when it was written.
class Stamped<T> {
  const Stamped(this.value, this.savedAt);

  final T value;
  final DateTime savedAt;

  Duration get age => DateTime.now().difference(savedAt);

  bool isOlderThan(Duration ttl) => age > ttl;
}

/// The one gateway to everything the app keeps on this device.
///
/// Two things make this more than a thin wrapper over [SharedPreferences]:
///
/// * **Reads are synchronous.** [init] pulls the whole store into memory once
///   during startup, so a widget can read the theme, the cached session or the
///   last feed while it is building its first frame. Nothing has to render a
///   spinner, or a signed-out state, while waiting on a disk read.
/// * **It never fails loudly.** If the platform channel is unavailable — a unit
///   test, an unsupported platform — the store keeps working from memory alone.
///   Losing a cache between launches is a mild inconvenience; a crash on
///   startup is not.
class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  SharedPreferences? _prefs;
  final Map<String, Object> _memory = {};
  bool _isReady = false;

  /// Loads the device's copy into memory. Call once, before `runApp`.
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
      // Nothing stored will outlive this launch, but everything still works.
      debugPrint('LocalStore: running from memory only ($error)');
    }
  }

  // --- reads -----------------------------------------------------------------

  String? getString(String key) => _memory[key] is String ? _memory[key] as String : null;

  int? getInt(String key) => _memory[key] is int ? _memory[key] as int : null;

  double? getDouble(String key) =>
      _memory[key] is double ? _memory[key] as double : null;

  bool? getBool(String key) => _memory[key] is bool ? _memory[key] as bool : null;

  List<String>? getStringList(String key) {
    final value = _memory[key];
    return value is List<String> ? List<String>.of(value) : null;
  }

  /// Decodes a value written by [setJson]. Returns null — rather than throwing —
  /// when the stored text is no longer readable, which is what happens after a
  /// model's shape changes under an existing install.
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

  /// Reads a value written by [setStamped], along with the time it was saved.
  Stamped<dynamic>? getStamped(String key) {
    final decoded = getJson(key);
    if (decoded is! Map) return null;

    final savedAt = DateTime.tryParse('${decoded['savedAt']}');
    if (savedAt == null) return null;

    return Stamped<dynamic>(decoded['data'], savedAt);
  }

  // --- writes ----------------------------------------------------------------
  //
  // Memory is updated first so a read immediately after a write is correct,
  // and the disk write is awaited separately by callers that care.

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

  /// Stores anything `jsonEncode` accepts.
  Future<void> setJson(String key, Object? value) {
    try {
      return setString(key, jsonEncode(value));
    } catch (error) {
      debugPrint('LocalStore: could not encode $key ($error)');
      return Future.value();
    }
  }

  /// Stores [value] with the current time beside it, for caches that need to
  /// know how old what they are holding is.
  Future<void> setStamped(String key, Object? value) => setJson(key, {
        'savedAt': DateTime.now().toIso8601String(),
        'data': value,
      });

  // --- deletes ---------------------------------------------------------------

  Future<void> remove(String key) {
    _memory.remove(key);
    return _guard(() => _prefs?.remove(key));
  }

  /// Deletes every key starting with [prefix].
  Future<void> removeScope(String prefix) async {
    final doomed = _memory.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in doomed) {
      await remove(key);
    }
  }

  /// Erases everything belonging to one account.
  ///
  /// Called on sign-out. Preferences that describe the device rather than the
  /// person — theme, language, radius — are not in this scope and stay put.
  Future<void> clearUserScope(String userId) =>
      removeScope(StorageKeys.userScope(userId));

  Future<void> _guard(Future<void>? Function() write) async {
    try {
      await write();
    } catch (error) {
      debugPrint('LocalStore: write failed ($error)');
    }
  }

  /// Test seam: drops everything held in memory.
  @visibleForTesting
  void resetForTest() {
    _memory.clear();
    _prefs = null;
    _isReady = false;
  }
}
