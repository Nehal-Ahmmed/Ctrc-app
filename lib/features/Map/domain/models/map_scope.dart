import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'geo_bounds.dart';

enum MapScope {
  radius2km,
  radius5km,
  radius10km,
  city,
  division;

  double? get fixedRadiusMeters => switch (this) {
        MapScope.radius2km => 2000,
        MapScope.radius5km => 5000,
        MapScope.radius10km => 10000,
        MapScope.city => null,
        MapScope.division => null,
      };

  double get fallbackRadiusMeters => switch (this) {
        MapScope.radius2km => 2000,
        MapScope.radius5km => 5000,
        MapScope.radius10km => 10000,
        MapScope.city => 25000,
        MapScope.division => 110000,
      };

  bool get isAdministrative =>
      this == MapScope.city || this == MapScope.division;

  int get reverseZoom => this == MapScope.city ? 10 : 5;

  String get label => switch (this) {
        MapScope.radius2km => 'Within 2 km radius',
        MapScope.radius5km => 'Within 5 km radius',
        MapScope.radius10km => 'Within 10 km radius',
        MapScope.city => 'Within the city',
        MapScope.division => 'Within the division',
      };

  String get chipLabel => switch (this) {
        MapScope.radius2km => '2 km',
        MapScope.radius5km => '5 km',
        MapScope.radius10km => '10 km',
        MapScope.city => 'City',
        MapScope.division => 'Division',
      };

  IconData get icon => switch (this) {
        MapScope.radius2km => Icons.adjust,
        MapScope.radius5km => Icons.trip_origin,
        MapScope.radius10km => Icons.radar,
        MapScope.city => Icons.location_city,
        MapScope.division => Icons.public,
      };
}

class ResolvedArea {
  final MapScope scope;

  final LatLng center;
  final double radiusMeters;

  final GeoBounds? bounds;
  final String? name;

  const ResolvedArea({
    required this.scope,
    required this.center,
    required this.radiusMeters,
    this.bounds,
    this.name,
  });

  factory ResolvedArea.fallback(MapScope scope, LatLng anchor) => ResolvedArea(
        scope: scope,
        center: anchor,
        radiusMeters: scope.fallbackRadiusMeters,
        name: null,
      );

  double get radiusKm => radiusMeters / 1000.0;

  bool includes(LatLng point) {
    if (bounds != null) return bounds!.contains(point);
    return true;
  }

  String get description => name == null ? scope.label : '${scope.chipLabel} · $name';
}
