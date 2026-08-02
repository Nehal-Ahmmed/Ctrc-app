import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../Report/data/datasources/report_remote_datasource.dart';
import '../../../Report/domain/models/report_model.dart';
import '../../data/datasources/route_corridor_datasource.dart';
import '../models/route_models.dart';
import '../utils/geo_utils.dart';
import 'incident_severity.dart';

/// Scans the corridor either side of a route for reported incidents and turns
/// the result into coloured road segments.
class RouteHazardAnalyzer {
  final ReportRemoteDataSource _reports;
  final RouteCorridorDataSource _corridor;

  /// How far either side of the centre line counts as "beside the road".
  final double corridorMeters;

  /// Radius used for each server probe in the fallback path.
  final double probeRadiusKm;

  /// Hard cap on probes so a Chittagong → Dhaka trip cannot fire 100 requests.
  final int maxProbes;

  /// Id of the signed-in user, so saved/vote state comes back with the reports.
  final int? viewerUserId;

  RouteHazardAnalyzer({
    required ReportRemoteDataSource reports,
    RouteCorridorDataSource? corridor,
    this.corridorMeters = 2000,
    this.probeRadiusKm = 12,
    this.maxProbes = 24,
    this.viewerUserId,
  })  : _reports = reports,
        _corridor = corridor ?? RouteCorridorDataSource();

  Future<RouteAnalysis> analyze({
    required RoutePlan plan,
    required List<RoutePlan> alternatives,
    required String fromLabel,
    required String toLabel,
  }) async {
    final scan = await _fetchCorridorReports(plan.points);

    final hazards = <RouteHazard>[];
    for (final report in scan.reports) {
      final location = report.location;
      if (location == null) continue;

      final projection = GeoUtils.projectOnPolyline(
        LatLng(location.latitude, location.longitude),
        plan.points,
      );
      if (projection.offsetMeters > corridorMeters) continue;

      hazards.add(RouteHazard(
        report: report,
        offsetMeters: projection.offsetMeters,
        alongMeters: projection.alongMeters,
        level: IncidentSeverity.of(report),
      ));
    }

    hazards.sort((a, b) => a.alongMeters.compareTo(b.alongMeters));

    return RouteAnalysis(
      plan: plan,
      segments: buildSegments(plan.points, hazards),
      hazards: hazards,
      alternatives: alternatives,
      fromLabel: fromLabel,
      toLabel: toLabel,
      corridorScanTruncated: scan.truncated,
    );
  }

  /// Splits the route into chunks and colours each one by the worst incident
  /// that sits within [corridorMeters] of it.
  List<RouteSegment> buildSegments(
    List<LatLng> points,
    List<RouteHazard> hazards,
  ) {
    if (points.length < 2) return const [];

    final totalLength = GeoUtils.polylineLength(points);
    // Aim for ~60 chunks, but never finer than 150 m or coarser than 5 km.
    final chunkLength = (totalLength / 60).clamp(150.0, 5000.0);
    final chunks = GeoUtils.chunk(points, chunkLength);

    return chunks.map((chunk) {
      var level = CongestionLevel.clear;
      for (final hazard in hazards) {
        if (hazard.level.rank <= level.rank) continue;
        final distance = GeoUtils.distanceToPolyline(hazard.point, chunk);
        if (distance <= corridorMeters) level = hazard.level;
      }
      return RouteSegment(points: chunk, level: level);
    }).toList();
  }

  /// Preferred path: one backend call that does the corridor filter server
  /// side. Falls back to probing `/nearby` when the deployed backend does not
  /// have the endpoint yet.
  Future<({List<ReportModel> reports, bool truncated})> _fetchCorridorReports(
    List<LatLng> points,
  ) async {
    try {
      final hits = await _corridor.getReportsAlongRoute(
        path: _thinForUpload(points),
        corridorKm: corridorMeters / 1000.0,
        userId: viewerUserId,
      );

      return (
        reports: hits
            .map((hit) => hit.report)
            .where(IncidentSeverity.isActive)
            .toList(),
        truncated: false,
      );
    } on CorridorEndpointUnavailable {
      return _scanCorridorByProbing(points);
    } catch (_) {
      // Any other transport failure: still try the older, chattier path rather
      // than showing the user an empty corridor.
      return _scanCorridorByProbing(points);
    }
  }

  /// OSRM returns thousands of points for a long route; the corridor filter
  /// does not need that resolution and the request body would be huge.
  List<LatLng> _thinForUpload(List<LatLng> points) {
    if (points.length <= 2) return points;
    final thinned = GeoUtils.sampleEvery(points, 250);
    return thinned.length < 2 ? points : thinned;
  }

  /// Legacy path. Probe circles overlap enough that the full ±[corridorMeters]
  /// corridor is covered between consecutive samples.
  Future<({List<ReportModel> reports, bool truncated})> _scanCorridorByProbing(
    List<LatLng> points,
  ) async {
    if (points.isEmpty) {
      return (reports: <ReportModel>[], truncated: false);
    }

    final probeRadiusM = probeRadiusKm * 1000;
    // Half-chord of the probe circle at the corridor edge.
    final coverage = math.sqrt(
      math.max(0, probeRadiusM * probeRadiusM - corridorMeters * corridorMeters),
    );
    final spacing = math.max(1000.0, coverage * 1.6);

    var samples = GeoUtils.sampleEvery(points, spacing);
    var truncated = false;

    if (samples.length > maxProbes) {
      final step = (samples.length / maxProbes).ceil();
      final reduced = <LatLng>[
        for (var i = 0; i < samples.length; i += step) samples[i],
      ];
      if (reduced.last != samples.last) reduced.add(samples.last);
      samples = reduced;
      // Probe circles no longer overlap, so a few incidents may be missed.
      truncated = true;
    }

    final byId = <int, ReportModel>{};

    // Sequential on purpose: the public backend (and Nominatim before it) do
    // not appreciate a burst of parallel requests.
    for (final sample in samples) {
      try {
        final found = await _reports.getNearbyReports(
          lat: sample.latitude,
          lng: sample.longitude,
          radius: probeRadiusKm,
          userId: viewerUserId,
        );
        for (final report in found) {
          if (report.location == null) continue;
          if (!IncidentSeverity.isActive(report)) continue;
          byId[report.reportId] = report;
        }
      } catch (_) {
        truncated = true;
      }
    }

    return (reports: byId.values.toList(), truncated: truncated);
  }
}
