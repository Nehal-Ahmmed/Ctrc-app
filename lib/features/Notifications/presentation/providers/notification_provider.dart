import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/storage/local_store.dart';
import '../../../Map/domain/services/incident_severity.dart';
import '../../../Map/domain/utils/geo_utils.dart';
import '../../../Report/domain/models/report_model.dart';
import '../../domain/models/app_notification.dart';

class NotificationState {
  final List<AppNotification> items;

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

class NotificationController extends StateNotifier<NotificationState> {
  static const _maxItems = 60;

  final LocalStore _store;

  final Set<int> _seen = <int>{};

  bool _isFirstIngest = true;

  NotificationController({LocalStore? store})
      : _store = store ?? LocalStore.instance,
        super(const NotificationState()) {
    _restore();
  }

  void _restore() {
    final seen = _store.getStringList(StorageKeys.notificationSeenIds) ?? const [];
    _seen.addAll(seen.map(int.tryParse).whereType<int>());
    _isFirstIngest = _seen.isEmpty;

    final decoded = _store.getJson(StorageKeys.notificationItems);
    final items = <AppNotification>[];
    if (decoded is List) {
      for (final entry in decoded) {
        if (entry is Map) {
          items.add(AppNotification.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }

    state = NotificationState(items: items, isLoaded: true);
  }

  Future<void> _persist() async {
    await _store.setJson(
      StorageKeys.notificationItems,
      state.items.map((n) => n.toJson()).toList(),
    );
    
    final seen = _seen.toList();
    final trimmed = seen.length > 500 ? seen.sublist(seen.length - 500) : seen;
    await _store.setStringList(
      StorageKeys.notificationSeenIds,
      trimmed.map((id) => id.toString()).toList(),
    );
  }

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

final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).unreadCount,
);
