import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../Map/domain/services/incident_severity.dart';
import '../../../Map/domain/utils/geo_utils.dart';
import '../../../Report/domain/models/report_model.dart';
import '../../domain/models/app_notification.dart';

class NotificationState {
  final List<AppNotification> items;

  /// False until the stored history has been read back off disk.
  final bool isLoaded;

  const NotificationState({this.items = const [], this.isLoaded = false});

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationState copyWith({List<AppNotification>? items, bool? isLoaded}) {
    return NotificationState(
      items: items ?? this.items,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

/// Turns the nearby-incident feed into an alert inbox.
///
/// Pages that already fetch nearby reports hand them to [ingest]; anything the
/// user has not been told about yet becomes a notification. Nothing extra is
/// fetched, so this costs no additional network traffic.
class NotificationController extends StateNotifier<NotificationState> {
  static const _itemsKey = 'notifications_items';
  static const _seenKey = 'notifications_seen_report_ids';
  static const _maxItems = 60;

  /// Report ids the user has already been shown. Kept separate from [items] so
  /// clearing the list does not resurrect every old incident.
  final Set<int> _seen = <int>{};

  /// Nothing has been ingested yet on this install — seed silently instead of
  /// dumping every existing incident into the inbox at once.
  bool _isFirstIngest = true;

  NotificationController() : super(const NotificationState()) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();

    final seen = prefs.getStringList(_seenKey) ?? const [];
    _seen.addAll(seen.map(int.tryParse).whereType<int>());
    _isFirstIngest = _seen.isEmpty;

    final raw = prefs.getString(_itemsKey);
    final items = <AppNotification>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map) {
              items.add(
                AppNotification.fromJson(Map<String, dynamic>.from(entry)),
              );
            }
          }
        }
      } catch (_) {
        // Corrupt cache is not worth crashing over; start from empty.
      }
    }

    state = NotificationState(items: items, isLoaded: true);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _itemsKey,
      jsonEncode(state.items.map((n) => n.toJson()).toList()),
    );
    // Bound the seen set so it cannot grow without limit on a busy map.
    final seen = _seen.toList();
    final trimmed = seen.length > 500 ? seen.sublist(seen.length - 500) : seen;
    await prefs.setStringList(
      _seenKey,
      trimmed.map((id) => id.toString()).toList(),
    );
  }

  /// Records any previously unseen incidents from [reports].
  ///
  /// [enabled] mirrors the "Nearby Incident Alerts" preference — when off the
  /// reports are still marked as seen so turning it back on does not replay
  /// everything that happened in the meantime.
  Future<void> ingest(
    List<ReportModel> reports, {
    LatLng? viewerLocation,
    int? viewerUserId,
    bool enabled = true,
  }) async {
    if (!state.isLoaded || reports.isEmpty) return;

    final fresh = <AppNotification>[];
    var changed = false;

    for (final report in reports) {
      if (_seen.contains(report.reportId)) continue;
      _seen.add(report.reportId);
      changed = true;

      // Your own reports, and anything already expired, are not news.
      if (report.userId == viewerUserId) continue;
      if (!IncidentSeverity.isActive(report)) continue;
      if (_isFirstIngest || !enabled) continue;

      final location = report.location;
      final distance = (viewerLocation != null && location != null)
          ? GeoUtils.metersBetween(
              viewerLocation,
              LatLng(location.latitude, location.longitude),
            )
          : null;

      fresh.add(
        AppNotification(
          reportId: report.reportId,
          title: report.title,
          category: report.category,
          description: report.description,
          distanceMeters: distance,
          receivedAt: DateTime.now(),
        ),
      );
    }

    if (!changed) return;
    _isFirstIngest = false;

    if (fresh.isNotEmpty) {
      fresh.sort((a, b) => (a.distanceMeters ?? double.infinity)
          .compareTo(b.distanceMeters ?? double.infinity));
      final merged = [...fresh, ...state.items];
      state = state.copyWith(
        items: merged.length > _maxItems
            ? merged.sublist(0, _maxItems)
            : merged,
      );
    }

    await _persist();
  }

  Future<void> markAllRead() async {
    if (state.unreadCount == 0) return;
    state = state.copyWith(
      items: state.items.map((n) => n.copyWith(isRead: true)).toList(),
    );
    await _persist();
  }

  Future<void> markRead(int reportId) async {
    state = state.copyWith(
      items: state.items
          .map((n) => n.reportId == reportId ? n.copyWith(isRead: true) : n)
          .toList(),
    );
    await _persist();
  }

  Future<void> remove(int reportId) async {
    state = state.copyWith(
      items: state.items.where((n) => n.reportId != reportId).toList(),
    );
    await _persist();
  }

  Future<void> clearAll() async {
    state = state.copyWith(items: const []);
    await _persist();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationController, NotificationState>(
  (ref) => NotificationController(),
);

/// Convenience selector for the app-bar badge.
final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).unreadCount,
);
