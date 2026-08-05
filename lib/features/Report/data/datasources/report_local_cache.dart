import 'package:latlong2/latlong.dart';

import '../../../../core/storage/local_store.dart';
import '../../domain/models/report_model.dart';

class CachedReports {
  const CachedReports({
    required this.reports,
    required this.savedAt,
    this.origin,
  });

  final List<ReportModel> reports;
  final DateTime savedAt;

  final LatLng? origin;

  Duration get age => DateTime.now().difference(savedAt);

  bool isOlderThan(Duration ttl) => age > ttl;
}

class ReportLocalCache {
  ReportLocalCache({LocalStore? store}) : _store = store ?? LocalStore.instance;

  final LocalStore _store;

  static const feedBucket = 'reports.feed';

  static const mineBucket = 'reports.mine';

  static const savedBucket = 'reports.saved';

  static const maxReports = 40;

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

    final forStorage = userId == null
        ? trimmed.map((report) => report.withoutViewerState())
        : trimmed;

    return _store.setStamped(StorageKeys.scoped(bucket, userId), {
      'reports': forStorage.map((report) => report.toJson()).toList(),
      if (origin != null) 'origin': {'lat': origin.latitude, 'lng': origin.longitude},
    });
  }

  void evictReport(int reportId, {String? userId}) {
    for (final bucket in [feedBucket, mineBucket, savedBucket]) {
      final cached = read(bucket, userId: userId);
      if (cached != null) {
        final reports = cached.reports.where((r) => r.reportId != reportId).toList();
        if (reports.length != cached.reports.length) {
          write(bucket, reports, userId: userId, origin: cached.origin);
        }
      }
    }
  }

  static LatLng? _decodePoint(dynamic raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'];
    final lng = raw['lng'];
    if (lat is! num || lng is! num) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }
}
