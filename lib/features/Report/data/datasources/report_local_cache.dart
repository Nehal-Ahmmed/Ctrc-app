import 'package:latlong2/latlong.dart';

import '../../../../core/storage/local_store.dart';
import '../../domain/models/report_model.dart';

/// A list of reports as it was last seen, with when and where it was captured.
class CachedReports {
  const CachedReports({
    required this.reports,
    required this.savedAt,
    this.origin,
  });

  final List<ReportModel> reports;
  final DateTime savedAt;

  /// Where the viewer was standing when this list was fetched. Only the feed
  /// records one — "my reports" and saved posts do not depend on a position.
  final LatLng? origin;

  Duration get age => DateTime.now().difference(savedAt);

  bool isOlderThan(Duration ttl) => age > ttl;
}

/// Keeps the last list each report screen showed, so those screens open with
/// something on them instead of an empty state.
///
/// The feed already waits on two slow things before it can paint — a GPS fix,
/// then a backend on a free tier that sleeps when idle. Neither of those has to
/// happen for the app to show what it showed last time, and once the fresh list
/// lands it simply replaces what is on screen.
///
/// Everything written here is filed under the account that fetched it, because
/// each card carries that person's saved flag and vote. Sign-out deletes the
/// whole scope in one go, so no part of it can surface under the next session.
class ReportLocalCache {
  ReportLocalCache({LocalStore? store}) : _store = store ?? LocalStore.instance;

  final LocalStore _store;

  /// Nearby incidents, as shown on the home feed.
  static const feedBucket = 'reports.feed';

  /// Reports the signed-in user filed.
  static const mineBucket = 'reports.mine';

  /// Reports the signed-in user bookmarked.
  static const savedBucket = 'reports.saved';

  /// Enough to fill a few screens of scrolling. The whole point is to have
  /// something to show at once, not to mirror the backend onto the device.
  static const maxReports = 40;

  /// Past this the list is shown but treated as history, not as current road
  /// conditions.
  static const staleAfter = Duration(hours: 6);

  CachedReports? read(String bucket, {String? userId}) {
    final stamped = _store.getStamped(StorageKeys.scoped(bucket, userId));
    final data = stamped?.value;
    if (stamped == null || data is! Map) return null;

    final rawReports = data['reports'];
    if (rawReports is! List) return null;

    final reports = rawReports
        .whereType<Map>()
        .map((json) => ReportModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    if (reports.isEmpty) return null;

    return CachedReports(
      reports: reports,
      savedAt: stamped.savedAt,
      origin: _decodePoint(data['origin']),
    );
  }

  Future<void> write(
    String bucket,
    List<ReportModel> reports, {
    String? userId,
    LatLng? origin,
  }) {
    final trimmed = reports.length > maxReports
        ? reports.sublist(0, maxReports)
        : reports;

    // A guest's copy must not carry saves or votes; only an account has those,
    // and they would otherwise be rendered under nobody's session.
    final forStorage = userId == null
        ? trimmed.map((report) => report.withoutViewerState())
        : trimmed;

    return _store.setStamped(StorageKeys.scoped(bucket, userId), {
      'reports': forStorage.map((report) => report.toJson()).toList(),
      if (origin != null) 'origin': {'lat': origin.latitude, 'lng': origin.longitude},
    });
  }

  static LatLng? _decodePoint(dynamic raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'];
    final lng = raw['lng'];
    if (lat is! num || lng is! num) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }
}
