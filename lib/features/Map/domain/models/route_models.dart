import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../Report/domain/models/report_model.dart';
import '../utils/geo_utils.dart';

/// How badly a stretch of road is affected, mirroring the Google Maps
/// blue / amber / red convention.
enum CongestionLevel {
  clear,
  slow,
  blocked;

  Color get color => switch (this) {
        CongestionLevel.clear => const Color(0xFF1A73E8),
        CongestionLevel.slow => const Color(0xFFF9AB00),
        CongestionLevel.blocked => const Color(0xFFD93025),
      };

  String get label => switch (this) {
        CongestionLevel.clear => 'Clear',
        CongestionLevel.slow => 'Slow / congested',
        CongestionLevel.blocked => 'Blocked',
      };

  IconData get icon => switch (this) {
        CongestionLevel.clear => Icons.check_circle_outline,
        CongestionLevel.slow => Icons.warning_amber_rounded,
        CongestionLevel.blocked => Icons.block,
      };

  int get rank => index;
}

/// One driving option returned by the router.
class RoutePlan {
  final List<LatLng> points;
  final double distanceMeters;
  final Duration duration;

  const RoutePlan({
    required this.points,
    required this.distanceMeters,
    required this.duration,
  });

  String get distanceLabel => GeoUtils.formatDistance(distanceMeters);
  String get durationLabel => GeoUtils.formatDuration(duration);
}

/// A stretch of the chosen route, coloured by its [level].
class RouteSegment {
  final List<LatLng> points;
  final CongestionLevel level;

  const RouteSegment({required this.points, required this.level});
}

/// An incident that sits inside the route corridor.
class RouteHazard {
  final ReportModel report;

  /// Perpendicular distance from the route centre line.
  final double offsetMeters;

  /// How far along the route the incident sits, used purely for ordering.
  final double alongMeters;
  final CongestionLevel level;

  const RouteHazard({
    required this.report,
    required this.offsetMeters,
    required this.alongMeters,
    required this.level,
  });

  LatLng get point =>
      LatLng(report.location!.latitude, report.location!.longitude);

  String get offsetLabel => '${GeoUtils.formatDistance(offsetMeters)} off route';
}

/// Everything the map needs to draw a trip: the coloured route, the incidents
/// beside it, and the discarded alternatives.
class RouteAnalysis {
  final RoutePlan plan;
  final List<RouteSegment> segments;
  final List<RouteHazard> hazards;
  final List<RoutePlan> alternatives;
  final String fromLabel;
  final String toLabel;

  /// Set when the corridor scan had to stop early on a very long trip.
  final bool corridorScanTruncated;

  const RouteAnalysis({
    required this.plan,
    required this.segments,
    required this.hazards,
    required this.alternatives,
    required this.fromLabel,
    required this.toLabel,
    this.corridorScanTruncated = false,
  });

  CongestionLevel get worstLevel => hazards.isEmpty
      ? CongestionLevel.clear
      : hazards
          .map((h) => h.level)
          .reduce((a, b) => a.rank >= b.rank ? a : b);

  int get blockedCount =>
      hazards.where((h) => h.level == CongestionLevel.blocked).length;

  int get slowCount =>
      hazards.where((h) => h.level == CongestionLevel.slow).length;
}
