import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'geo_bounds.dart';

/// The area the map is currently reporting on. Drives both the blue radius
/// drawn around the pointer and the alerts that get fetched.
enum MapScope {
  radius2km,
  radius5km,
  radius10km,
  city,
  division;

  /// Fixed radius in meters, or `null` for the administrative scopes whose
  /// extent has to be resolved by reverse geocoding the anchor point.
  double? get fixedRadiusMeters => switch (this) {
        MapScope.radius2km => 2000,
        MapScope.radius5km => 5000,
        MapScope.radius10km => 10000,
        MapScope.city => null,
        MapScope.division => null,
      };

  /// Used when the administrative lookup fails (offline, unknown place, ...).
  double get fallbackRadiusMeters => switch (this) {
        MapScope.radius2km => 2000,
        MapScope.radius5km => 5000,
        MapScope.radius10km => 10000,
        MapScope.city => 25000,
        MapScope.division => 110000,
      };

  bool get isAdministrative =>
      this == MapScope.city || this == MapScope.division;

  /// Nominatim reverse-geocoding zoom that returns the matching admin level.
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

/// A [MapScope] resolved against a concrete anchor point.
class ResolvedArea {
  final MapScope scope;

  /// Where the blue circle is drawn from. For radius scopes this is the anchor
  /// (pointer) itself; for admin scopes it is the centre of the matched area.
  final LatLng center;
  final double radiusMeters;

  /// Only set for administrative scopes — reports outside the box are dropped
  /// so "within the city" really means within the city.
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

  /// Server-side query radius in kilometres, measured from [center].
  double get radiusKm => radiusMeters / 1000.0;

  bool includes(LatLng point) {
    if (bounds != null) return bounds!.contains(point);
    return true;
  }

  String get description => name == null ? scope.label : '${scope.chipLabel} · $name';
}
